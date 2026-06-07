import Foundation
import CloudKit
import Combine

/// Owns the `CKSyncEngine` that mirrors HaloWalk's local stores
/// (FamilyStore / HubStore / PresenceStore) to a CloudKit custom zone in
/// the user's private database.
///
/// Build B scope: **owner-only solo sync.** Data round-trips to CloudKit
/// and back across the same iCloud account's devices, and survives
/// reinstall. CKShare / multi-participant is Build C.
///
/// Design choices:
///  • `CKSyncEngine` (iOS 17+) handles change tokens, batching, retry,
///    and offline queueing — we just say "these records changed" and
///    "here's how to merge what came back."
///  • UserDefaults stays the offline cache / first-paint; CloudKit is the
///    source of truth when reachable.
///  • Pilot-scale simplification: on any local collection change we
///    re-enqueue that collection's record IDs (≤ ~30 records total in a
///    family). CKSyncEngine only uploads real diffs. Not worth a
///    field-level dirty-tracking layer yet.
@MainActor
final class HaloCloudSync: ObservableObject {
    static let shared = HaloCloudSync()

    enum DatabaseScope: String, Codable {
        case privateOwner
        case sharedParticipant

        var label: String {
            switch self {
            case .privateOwner: return "private owner"
            case .sharedParticipant: return "shared participant"
            }
        }
    }

    @Published private(set) var accountAvailable = false
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isRunning = false
    @Published private(set) var databaseScope: DatabaseScope = .privateOwner
    @Published private(set) var activeZoneDescription = CloudKitSchema.zoneName

    /// Rolling, on-device diagnostics log. Surfaced in the CloudKit
    /// diagnostics screen so we can read exactly what the sync engine is
    /// doing on a real device instead of guessing. Capped + persisted so
    /// it survives a relaunch (but NOT app deletion — that's fine, the
    /// repro is "delete + reinstall" and we read the log on the fresh
    /// install up to the point of failure).
    @Published private(set) var log: [String] = []
    private let logKey = "halowalk.cksync.log.v1"
    private let logCap = 240

    func note(_ line: String) {
        let ts = Self.logTimeFormatter.string(from: Date())
        let entry = "\(ts)  \(line)"
        log.append(entry)
        if log.count > logCap { log.removeFirst(log.count - logCap) }
        UserDefaults.standard.set(log, forKey: logKey)
    }
    func clearLog() {
        log.removeAll()
        UserDefaults.standard.removeObject(forKey: logKey)
    }
    private static let logTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    /// Force a full re-push of local state + a fetch. Wired to the
    /// diagnostics "Force re-sync" button.
    func forceResync() {
        note("forceResync() requested")
        enqueueEntireLocalState()
        Task {
            try? await engine?.sendChanges()
            try? await engine?.fetchChanges()
            note("forceResync() complete")
        }
    }

    func deleteLocationReadings(for memberId: UUID) {
        guard let engine else { return }
        let deletes = FamilyStore.shared.devices(for: memberId).map {
            CKSyncEngine.PendingRecordZoneChange.deleteRecord(
                CloudKitSchema.readingRecordID(memberId: memberId, deviceId: $0.id))
        }
        guard !deletes.isEmpty else { return }
        engine.state.add(pendingRecordZoneChanges: deletes)
        note("deleteLocationReadings: queued \(deletes.count) reading delete(s) for \(memberId)")
        Task { try? await engine.sendChanges() }
    }

    func acceptShare(metadata: CKShare.Metadata) {
        note("acceptShare: begin")
        Task {
            do {
                try await accept(metadata)
                await MainActor.run {
                    self.configureSharedSession(zoneID: metadata.rootRecordID.zoneID)
                    self.restart()
                    self.note("acceptShare: accepted zone=\(metadata.rootRecordID.zoneID.zoneName)/\(metadata.rootRecordID.zoneID.ownerName)")
                }
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    self.note("acceptShare FAILED: \(error.localizedDescription)")
                }
            }
        }
    }

    #if os(iOS)
    func prepareFamilyShare(
        completion: @escaping (CKShare?, CKContainer?, Error?) -> Void
    ) {
        Task {
            do {
                let share = try await self.loadOrCreateFamilyShare()
                await MainActor.run {
                    self.note("prepareFamilyShare: ready")
                    completion(share, self.container, nil)
                }
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    self.note("prepareFamilyShare FAILED: \(error.localizedDescription)")
                    completion(nil, self.container, error)
                }
            }
        }
    }
    #endif

    private var engine: CKSyncEngine?
    private var cancellables = Set<AnyCancellable>()

    /// Set while we're writing remote records into the local stores, so
    /// the store observers don't treat the merge as a local edit and
    /// bounce it straight back up (sync loop).
    private var applyingRemoteChanges = false

    /// Did the initial cloud fetch return any records? Distinguishes
    /// "fresh install of a user who already has cloud data" (cloud wins,
    /// don't push local seed) from "very first run ever" (cloud empty,
    /// this device must seed it). Without this, a reinstall's MockData
    /// seed clobbers the user's real cloud data — the avatar-not-staying
    /// bug from Build 30.
    private var fetchedAnyRecords = false

    private let privateStateKey = "halowalk.cksync.state.v1"
    private let sharedStateKey = "halowalk.cksync.shared.state.v1"
    private let sharedZoneNameKey = "halowalk.cksync.shared.zoneName.v1"
    private let sharedZoneOwnerKey = "halowalk.cksync.shared.ownerName.v1"
    private var container: CKContainer {
        CKContainer(identifier: CloudKitSchema.containerID)
    }
    private var activeDatabase: CKDatabase {
        switch databaseScope {
        case .privateOwner: return container.privateCloudDatabase
        case .sharedParticipant: return container.sharedCloudDatabase
        }
    }
    private var stateKey: String {
        switch databaseScope {
        case .privateOwner: return privateStateKey
        case .sharedParticipant: return sharedStateKey
        }
    }

    private init() {
        log = (UserDefaults.standard.array(forKey: logKey) as? [String]) ?? []
        restoreSharedSessionIfPresent()
    }

    private func restoreSharedSessionIfPresent() {
        guard
            let zoneName = UserDefaults.standard.string(forKey: sharedZoneNameKey),
            let ownerName = UserDefaults.standard.string(forKey: sharedZoneOwnerKey)
        else {
            CloudKitSchema.usePrivateZone()
            databaseScope = .privateOwner
            activeZoneDescription = "\(CloudKitSchema.zoneID.zoneName) / \(CloudKitSchema.zoneID.ownerName)"
            return
        }
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        CloudKitSchema.useSharedZone(zoneID)
        databaseScope = .sharedParticipant
        activeZoneDescription = "\(zoneName) / \(ownerName)"
    }

    private func configureSharedSession(zoneID: CKRecordZone.ID) {
        UserDefaults.standard.set(zoneID.zoneName, forKey: sharedZoneNameKey)
        UserDefaults.standard.set(zoneID.ownerName, forKey: sharedZoneOwnerKey)
        CloudKitSchema.useSharedZone(zoneID)
        databaseScope = .sharedParticipant
        activeZoneDescription = "\(zoneID.zoneName) / \(zoneID.ownerName)"
        UserDefaults.standard.removeObject(forKey: sharedStateKey)
    }

    private func restart() {
        cancellables.removeAll()
        engine = nil
        isRunning = false
        fetchedAnyRecords = false
        start()
    }

    private func accept(_ metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var didResume = false
            func resumeOnce(_ result: Result<Void, Error>) {
                guard !didResume else { return }
                didResume = true
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            let op = CKAcceptSharesOperation(shareMetadatas: [metadata])
            op.perShareResultBlock = { _, result in
                if case .failure(let error) = result {
                    resumeOnce(.failure(error))
                }
            }
            op.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    resumeOnce(.success(()))
                case .failure(let error):
                    resumeOnce(.failure(error))
                }
            }
            container.add(op)
        }
    }

    #if os(iOS)
    private func loadOrCreateFamilyShare() async throws -> CKShare {
        guard databaseScope == .privateOwner else {
            throw NSError(
                domain: "HaloWalk.CloudSharing",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Only the family owner can manage the share."]
            )
        }
        let root = try await fetchOrBuildFamilyRootRecord()
        if let shareRef = root.share {
            let share = try await fetchShare(recordID: shareRef.recordID)
            cache(share)
            return share
        }

        let share = CKShare(
            rootRecord: root,
            shareID: CloudKitSchema.shareRecordID(familyId: FamilyStore.shared.family.id)
        )
        share[CKShare.SystemFieldKey.title] = FamilyStore.shared.family.name as CKRecordValue
        share.publicPermission = .none
        let saved = try await modify(recordsToSave: [root, share], recordIDsToDelete: nil, database: container.privateCloudDatabase)
        for record in saved { cache(record) }
        return saved.compactMap { $0 as? CKShare }.first ?? share
    }

    private func fetchOrBuildFamilyRootRecord() async throws -> CKRecord {
        let id = CloudKitSchema.familyRecordID(FamilyStore.shared.family.id)
        if let cached = cachedBaseRecord(for: id) {
            let fresh = CloudKitSchema.record(for: FamilyStore.shared.family)
            for key in fresh.allKeys() { cached[key] = fresh[key] }
            return cached
        }
        do {
            let record = try await container.privateCloudDatabase.record(for: id)
            cache(record)
            let fresh = CloudKitSchema.record(for: FamilyStore.shared.family)
            for key in fresh.allKeys() { record[key] = fresh[key] }
            return record
        } catch {
            return CloudKitSchema.record(for: FamilyStore.shared.family)
        }
    }

    private func fetchShare(recordID: CKRecord.ID) async throws -> CKShare {
        let record = try await container.privateCloudDatabase.record(for: recordID)
        guard let share = record as? CKShare else {
            throw NSError(
                domain: "HaloWalk.CloudSharing",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "CloudKit returned a non-share record."]
            )
        }
        return share
    }

    private func modify(
        recordsToSave: [CKRecord]?,
        recordIDsToDelete: [CKRecord.ID]?,
        database: CKDatabase
    ) async throws -> [CKRecord] {
        try await withCheckedThrowingContinuation { continuation in
            let op = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete)
            op.savePolicy = .changedKeys
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: recordsToSave ?? [])
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(op)
        }
    }
    #endif

    // MARK: - Lifecycle

    /// Call once after launch. Order matters to avoid the seed-clobbers-
    /// server race:
    ///   1. boot the engine (no record changes pending yet — only the
    ///      zone-create, and observers NOT wired so nothing local is
    ///      enqueued)
    ///   2. fetch first — pull whatever's in the cloud into the local
    ///      stores via `upsertFromCloud`
    ///   3. wire the store observers (after the fetch, so the merge in
    ///      step 2 doesn't echo back up)
    ///   4. only if the cloud came back EMPTY (true first-ever run, not a
    ///      reinstall) does this device seed the cloud from local state
    func start() {
        guard engine == nil else { return }
        note("start(): begin scope=\(databaseScope.label), zone=\(CloudKitSchema.zoneID.zoneName)/\(CloudKitSchema.zoneID.ownerName)")
        Task {
            let status = try? await container.accountStatus()
            self.accountAvailable = (status == .available)
            note("accountStatus = \(String(describing: status))")
            guard self.accountAvailable else {
                self.lastError = "iCloud unavailable (status: \(String(describing: status)))."
                note("ABORT — iCloud unavailable")
                return
            }
            self.bootEngine()
            let localAvatar = FamilyStore.shared.me?.avatarId ?? "nil"
            note("local member avatar BEFORE fetch = \(localAvatar)")

            note("fetchChanges() begin")
            try? await self.engine?.fetchChanges()
            note("fetchChanges() done — fetchedAnyRecords=\(self.fetchedAnyRecords)")
            let afterAvatar = FamilyStore.shared.me?.avatarId ?? "nil"
            note("local member avatar AFTER fetch = \(afterAvatar)")

            self.observeStores()
            self.isRunning = true

            // Build 35: delete duplicate Home hubs that local dedupe
            // pruned, so they don't resurrect from the cloud on the next
            // fetch. Do this AFTER the fetch (otherwise the just-fetched
            // dupes would re-add them locally).
            let pruned = HubStore.homesPrunedFromCloud
            if !pruned.isEmpty {
                let deletes = pruned.map {
                    CKSyncEngine.PendingRecordZoneChange.deleteRecord(
                        CloudKitSchema.hubRecordID($0))
                }
                self.engine?.state.add(pendingRecordZoneChanges: deletes)
                note("pruning \(pruned.count) duplicate Home record(s) from cloud")
                HubStore.homesPrunedFromCloud.removeAll()
            }

            if !self.fetchedAnyRecords {
                note("cloud empty → seeding from local state")
                self.enqueueEntireLocalState()
                try? await self.engine?.sendChanges()
            } else {
                note("cloud had data → NOT seeding (adopt cloud)")
            }
            try? await self.engine?.sendChanges()
        }
    }

    private func bootEngine() {
        loadSystemFields()
        let saved = UserDefaults.standard.data(forKey: stateKey)
        let stateSerialization: CKSyncEngine.State.Serialization? = saved.flatMap {
            try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0)
        }
        var config = CKSyncEngine.Configuration(
            database: activeDatabase,
            stateSerialization: stateSerialization,
            delegate: self
        )
        config.automaticallySync = true
        self.engine = CKSyncEngine(config)
        // Owners create the custom zone in their private database.
        // Participants receive the already-created shared zone after
        // accepting the CKShare; saving the zone in shared DB is invalid.
        if databaseScope == .privateOwner {
            self.engine?.state.add(pendingDatabaseChanges: [
                .saveZone(CKRecordZone(zoneID: CloudKitSchema.zoneID))
            ])
        }
    }

    // MARK: - Local → Cloud

    private func observeStores() {
        // No debounce on purpose. `@Published` sinks fire synchronously
        // on the same call stack as the mutation, so when the mutation
        // is a remote merge (inside `apply()`, flag set), the enqueue
        // methods see `applyingRemoteChanges == true` and skip — that's
        // the sync-loop guard. A debounce would delay the sink until
        // after the flag reset and break it. CKSyncEngine batches the
        // actual network sends itself, so enqueueing eagerly is cheap
        // (it just adds deduped pending record IDs to engine state).
        FamilyStore.shared.$members
            .sink { [weak self] _ in self?.enqueueFamily() }
            .store(in: &cancellables)
        FamilyStore.shared.$relationships
            .sink { [weak self] _ in self?.enqueueFamily() }
            .store(in: &cancellables)
        FamilyStore.shared.$devices
            .sink { [weak self] _ in self?.enqueueFamily() }
            .store(in: &cancellables)
        FamilyStore.shared.$family
            .sink { [weak self] _ in self?.enqueueFamily() }
            .store(in: &cancellables)
        HubStore.shared.$hubs
            .sink { [weak self] _ in self?.enqueueHubs() }
            .store(in: &cancellables)
        PresenceStore.shared.$readings
            .sink { [weak self] _ in self?.enqueueReadings() }
            .store(in: &cancellables)
    }

    private func enqueueEntireLocalState() {
        enqueueFamily()
        enqueueHubs()
        enqueueReadings()
    }

    private func enqueueFamily() {
        guard !applyingRemoteChanges, let engine else {
            note("enqueueFamily SKIPPED (applyingRemote=\(applyingRemoteChanges), engine=\(engine != nil))")
            return
        }
        var changes: [CKSyncEngine.PendingRecordZoneChange] = []
        changes.append(.saveRecord(CloudKitSchema.familyRecordID(FamilyStore.shared.family.id)))
        changes += FamilyStore.shared.members.map { .saveRecord(CloudKitSchema.memberRecordID($0.id)) }
        changes += FamilyStore.shared.relationships.map { .saveRecord(CloudKitSchema.relationshipRecordID($0.id)) }
        changes += FamilyStore.shared.devices.map { .saveRecord(CloudKitSchema.deviceRecordID($0.id)) }
        engine.state.add(pendingRecordZoneChanges: changes)
        let av = FamilyStore.shared.me?.avatarId ?? "nil"
        note("enqueueFamily: \(changes.count) changes (my avatar=\(av))")
    }
    private func enqueueHubs() {
        guard !applyingRemoteChanges, let engine else { return }
        engine.state.add(pendingRecordZoneChanges:
            HubStore.shared.hubs.map { .saveRecord(CloudKitSchema.hubRecordID($0.id)) })
    }
    private func enqueueReadings() {
        guard !applyingRemoteChanges, let engine else { return }
        var changes: [CKSyncEngine.PendingRecordZoneChange] = []
        for (memberId, byDevice) in PresenceStore.shared.readings {
            guard FamilyStore.shared.member(memberId)?.sharesLocation != false else { continue }
            for deviceId in byDevice.keys {
                changes.append(.saveRecord(
                    CloudKitSchema.readingRecordID(memberId: memberId, deviceId: deviceId)))
            }
        }
        engine.state.add(pendingRecordZoneChanges: changes)
    }

    // MARK: - Materialize a record for a pending change

    /// Build the record to send. CRITICAL: we start from the cached
    /// server record's *system fields* (which carry `recordChangeTag`)
    /// when we have them, and copy the current data fields onto it.
    ///
    /// CloudKit uses optimistic concurrency: updating an existing server
    /// record requires a CKRecord that carries the server's current
    /// change tag. A freshly-constructed `CKRecord(recordType:recordID:)`
    /// has no tag — the *first* save (a create) works, but every
    /// subsequent update is rejected with `serverRecordChanged` and the
    /// edit is silently lost. That's the "yesterday's avatar stuck,
    /// today's didn't" bug. Reusing cached system fields fixes it.
    private func materialize(_ recordID: CKRecord.ID) -> CKRecord? {
        guard let fresh = freshRecord(recordID) else {
            note("materialize \(recordID.recordName): MODEL GONE → nil (nothing sent)")
            return nil  // model gone — nothing to send
        }
        let cached = cachedBaseRecord(for: recordID)
        let base = cached ?? CKRecord(recordType: fresh.recordType, recordID: recordID)
        for key in fresh.allKeys() {
            base[key] = fresh[key]
        }
        if recordID.recordName.hasPrefix("member_") {
            note("materialize \(recordID.recordName): avatar=\(fresh["avatarId"] as? String ?? "nil") tag=\(cached?.recordChangeTag ?? "none")")
        }
        return base
    }

    /// A virgin record carrying just the current data fields. System
    /// fields (change tag) are layered on by `materialize`.
    private func freshRecord(_ recordID: CKRecord.ID) -> CKRecord? {
        let name = recordID.recordName
        if name.hasPrefix("family_") {
            return CloudKitSchema.record(for: FamilyStore.shared.family)
        }
        if name.hasPrefix("member_"),
           let id = uuid(afterPrefix: "member_", in: name),
           let m = FamilyStore.shared.member(id) {
            return CloudKitSchema.record(for: m)
        }
        if name.hasPrefix("rel_"),
           let id = uuid(afterPrefix: "rel_", in: name),
           let rel = FamilyStore.shared.relationships.first(where: { $0.id == id }) {
            return CloudKitSchema.record(for: rel)
        }
        if name.hasPrefix("device_"),
           let id = uuid(afterPrefix: "device_", in: name),
           let d = FamilyStore.shared.devices.first(where: { $0.id == id }) {
            return CloudKitSchema.record(for: d)
        }
        if name.hasPrefix("hub_"),
           let id = uuid(afterPrefix: "hub_", in: name),
           let h = HubStore.shared.hubs.first(where: { $0.id == id }) {
            return CloudKitSchema.record(for: h)
        }
        if name.hasPrefix("reading_") {
            // reading_<memberUUID>_<deviceUUID>
            let parts = name.dropFirst("reading_".count).split(separator: "_")
            if parts.count == 2,
               let memberId = UUID(uuidString: String(parts[0])),
               let deviceId = UUID(uuidString: String(parts[1])),
               let reading = PresenceStore.shared.reading(memberId: memberId, deviceId: deviceId) {
                return CloudKitSchema.record(for: reading)
            }
        }
        return nil
    }
    private func uuid(afterPrefix prefix: String, in name: String) -> UUID? {
        UUID(uuidString: String(name.dropFirst(prefix.count)))
    }

    // MARK: - CKRecord system-fields cache
    // Keyed by zone + recordName → archived system fields (recordID + change
    // tag + zone). Persisted so change tags survive relaunch. Updated
    // whenever we see an authoritative server record (fetch or successful
    // send).

    private var systemFields: [String: Data] = [:]
    private let systemFieldsKey = "halowalk.cksync.systemFields.v2"

    private func loadSystemFields() {
        if let data = UserDefaults.standard.data(forKey: systemFieldsKey),
           let map = try? JSONDecoder().decode([String: Data].self, from: data) {
            systemFields = map
        }
    }
    private func saveSystemFields() {
        if let data = try? JSONEncoder().encode(systemFields) {
            UserDefaults.standard.set(data, forKey: systemFieldsKey)
        }
    }
    private func cache(_ record: CKRecord) {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        systemFields[systemFieldKey(for: record.recordID)] = coder.encodedData
        saveSystemFields()
    }
    private func cachedBaseRecord(for recordID: CKRecord.ID) -> CKRecord? {
        guard let data = systemFields[systemFieldKey(for: recordID)],
              let coder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        coder.requiresSecureCoding = true
        let rec = CKRecord(coder: coder)
        coder.finishDecoding()
        return rec
    }
    private func systemFieldKey(for recordID: CKRecord.ID) -> String {
        "\(recordID.zoneID.ownerName)|\(recordID.zoneID.zoneName)|\(recordID.recordName)"
    }

    // MARK: - Cloud → Local

    private func apply(_ records: [CKRecord]) {
        guard !records.isEmpty else { return }
        applyingRemoteChanges = true
        defer { applyingRemoteChanges = false }

        // Standard CKSyncEngine conflict rule: a fetched *server* record
        // must NOT overwrite a local record that has an unsent pending
        // local change. Our local edit is newer and is queued to go up —
        // if we let the stale server copy stomp it here, the queued
        // saveRecord then re-materializes the stomped value and we lose
        // the edit. This is exactly the "avatar reverts but new hubs
        // stick" bug: existing records get fetched (and stomped) before
        // the edit sends; brand-new records have no server copy to stomp.
        let pendingSaveIDs: Set<CKRecord.ID> = Set(
            (engine?.state.pendingRecordZoneChanges ?? []).compactMap {
                if case .saveRecord(let id) = $0 { return id }
                return nil
            }
        )

        for r in records {
            cache(r)
            if pendingSaveIDs.contains(r.recordID) {
                note("apply \(r.recordID.recordName): SKIP (pending local edit)")
                continue
            }
            switch r.recordType {
            case CloudKitSchema.RecordType.member:
                if let m = CloudKitSchema.member(from: r) {
                    note("apply member \(r.recordID.recordName): avatar=\(r["avatarId"] as? String ?? "nil") → upsert")
                    FamilyStore.shared.upsertFromCloud(member: m)
                } else {
                    note("apply member \(r.recordID.recordName): member(from:) RETURNED NIL — record rejected on read. keys=\(r.allKeys())")
                }
            case CloudKitSchema.RecordType.relationship:
                if let rel = CloudKitSchema.relationship(from: r) { FamilyStore.shared.upsertFromCloud(relationship: rel) }
            case CloudKitSchema.RecordType.device:
                if let d = CloudKitSchema.device(from: r) { FamilyStore.shared.upsertFromCloud(device: d) }
            case CloudKitSchema.RecordType.hub:
                if let h = CloudKitSchema.hub(from: r) { HubStore.shared.upsertFromCloud(hub: h) }
            case CloudKitSchema.RecordType.locationReading:
                if let reading = CloudKitSchema.reading(from: r) { PresenceStore.shared.ingest(reading) }
            case CloudKitSchema.RecordType.family:
                if let f = CloudKitSchema.family(from: r) { FamilyStore.shared.upsertFromCloud(family: f) }
            default:
                break
            }
        }
        lastSyncAt = Date()
    }

    private func persistState(_ serialization: CKSyncEngine.State.Serialization) {
        if let data = try? JSONEncoder().encode(serialization) {
            UserDefaults.standard.set(data, forKey: stateKey)
        }
    }
}

// MARK: - CKSyncEngineDelegate

extension HaloCloudSync: CKSyncEngineDelegate {
    nonisolated func handleEvent(
        _ event: CKSyncEngine.Event,
        syncEngine: CKSyncEngine
    ) async {
        switch event {
        case .stateUpdate(let e):
            await MainActor.run { self.persistState(e.stateSerialization) }

        case .accountChange(let e):
            await MainActor.run {
                switch e.changeType {
                case .signIn:
                    self.accountAvailable = true
                    self.enqueueEntireLocalState()
                case .signOut:
                    self.accountAvailable = false
                case .switchAccounts:
                    self.accountAvailable = true
                @unknown default:
                    break
                }
            }

        case .fetchedRecordZoneChanges(let e):
            let modified = e.modifications.map(\.record)
            let deletions = e.deletions.count
            await MainActor.run {
                if !modified.isEmpty { self.fetchedAnyRecords = true }
                self.note("FETCHED \(modified.count) records, \(deletions) deletions: \(modified.map { $0.recordID.recordName }.joined(separator: ", "))")
                self.apply(modified)
                // If applying just dedup'd a cloud-resurrected Home,
                // delete the loser server-side so it stays gone.
                let pruned = HubStore.homesPrunedFromCloud
                if !pruned.isEmpty {
                    self.engine?.state.add(pendingRecordZoneChanges:
                        pruned.map { .deleteRecord(CloudKitSchema.hubRecordID($0)) })
                    self.note("pruned \(pruned.count) resurrected Home(s) from cloud")
                    HubStore.homesPrunedFromCloud.removeAll()
                }
            }

        case .sentRecordZoneChanges(let e):
            await MainActor.run {
                if !e.savedRecords.isEmpty {
                    self.note("SENT OK: \(e.savedRecords.map { $0.recordID.recordName }.joined(separator: ", "))")
                }
                for saved in e.savedRecords { self.cache(saved) }

                for failure in e.failedRecordSaves {
                    let ck = failure.error as? CKError
                    let codeName = ck.map { "\($0.code.rawValue):\($0.code)" } ?? "non-CKError"
                    self.note("SEND FAILED \(failure.record.recordID.recordName) — \(codeName) — \(failure.error.localizedDescription)")
                    if ck?.code == .serverRecordChanged,
                       let serverRecord = ck?.serverRecord {
                        self.cache(serverRecord)
                        self.engine?.state.add(pendingRecordZoneChanges: [
                            .saveRecord(failure.record.recordID)
                        ])
                        self.note("  → adopted server tag, re-queued \(failure.record.recordID.recordName)")
                    } else {
                        self.lastError = failure.error.localizedDescription
                    }
                }
                if e.failedRecordSaves.isEmpty { self.lastSyncAt = Date() }
            }

        case .fetchedDatabaseChanges, .sentDatabaseChanges,
             .willFetchChanges, .didFetchChanges,
             .willSendChanges, .didSendChanges,
             .willFetchRecordZoneChanges, .didFetchRecordZoneChanges:
            break

        @unknown default:
            break
        }
    }

    nonisolated func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = context.options.scope
        let pending = syncEngine.state.pendingRecordZoneChanges.filter {
            scope.contains($0)
        }
        guard !pending.isEmpty else { return nil }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { recordID in
            await MainActor.run { self.materialize(recordID) }
        }
    }
}
