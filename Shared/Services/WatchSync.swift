import Foundation
import WatchConnectivity
import CoreLocation
import Combine

/// iPhone↔Watch sync over WatchConnectivity. The iPhone is the source of
/// truth for hubs / triggers / family / theme; it pushes those down via
/// `updateApplicationContext` (overwritten on every change). The Watch
/// pushes the wearer's location back up via `transferUserInfo` (queued).
@MainActor
final class WatchSync: NSObject, ObservableObject {
    static let shared = WatchSync()

    private var session: WCSession?

    /// The two halves of "is the connection working." `isReachable` is
    /// realtime (peer is alive *right now*); `isPaired` reflects whether
    /// any peer was ever activated.
    @Published private(set) var isReachable: Bool = false
    @Published private(set) var isPaired: Bool = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastSyncAt: Date?

    /// Persistent device id for the local device — the watch generates one
    /// on first launch and reuses it across launches so the iPhone can
    /// keep its location readings keyed under a consistent device.
    private static let localDeviceIdKey = "halowalk.localDeviceId.v1"

    static var localDeviceId: UUID {
        if let s = UserDefaults.standard.string(forKey: localDeviceIdKey),
           let id = UUID(uuidString: s) {
            return id
        }
        let new = UUID()
        UserDefaults.standard.set(new.uuidString, forKey: localDeviceIdKey)
        return new
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    // MARK: - iPhone → Watch — application context

    func pushApplicationContext() {
        guard let session, session.activationState == .activated else { return }
        let payload: [String: Any] = [
            "hubs": HubStore.shared.hubs.map(serialize(hub:)),
            "members": FamilyStore.shared.members.map(serialize(member:)),
            "devices": FamilyStore.shared.devices.map(serialize(device:)),
            "accountMemberId": FamilyStore.shared.account.memberId.uuidString,
            "themeId": ThemeManager.shared.theme.id,
            "guardiansSharing": Array(PresenceStore.shared.guardiansSharing.map { $0.uuidString }),
            "presence": serializePresence(),
            "syncedAt": Date().timeIntervalSince1970
        ]
        do {
            try session.updateApplicationContext(payload)
            self.lastSyncAt = Date()
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    // MARK: - Watch → iPhone

    /// Watch sends a fresh location reading to the iPhone. Throttled by
    /// the caller — typically once per ~60s or per significant movement.
    func sendLocationReading(_ reading: LocationReading) {
        guard let session, session.activationState == .activated else { return }
        let payload: [String: Any] = [
            "type": "locationReading",
            "memberId": reading.memberId.uuidString,
            "deviceId": reading.deviceId.uuidString,
            "lat": reading.latitude,
            "lon": reading.longitude,
            "accuracy": reading.horizontalAccuracy,
            "timestamp": reading.timestamp.timeIntervalSince1970,
            "battery": reading.batteryPercent ?? -1,
            "onWrist": reading.isOnWrist ?? false,
            "moving": reading.isMoving ?? false
        ]
        // userInfo is queued — survives device sleep, no need to be reachable.
        session.transferUserInfo(payload)
    }

    /// Watch → iPhone quick-reply message. Queued via transferUserInfo so it
    /// survives the iPhone being in pocket / asleep at the moment of send.
    func sendMessage(fromMemberId: UUID, toMemberId: UUID, body: String) {
        guard let session, session.activationState == .activated else { return }
        let payload: [String: Any] = [
            "type": "message",
            "messageId": UUID().uuidString,
            "fromMemberId": fromMemberId.uuidString,
            "toMemberId": toMemberId.uuidString,
            "body": body,
            "timestamp": Date().timeIntervalSince1970
        ]
        session.transferUserInfo(payload)
    }

    /// Cross-device boost request — "please bump your fidelity for these
    /// memberIds for the next `ttl` seconds." Used when a guardian opens
    /// a location-aware screen or starts a Continuous Watch. The
    /// receiving device's `LocationFidelityCoordinator` honors the boost
    /// for the duration.
    ///
    /// Build 23: only iPhone↔Watch via WCSession. iPhone↔iPhone needs
    /// CloudKit family sync (Build 24) — calling this on the iPhone today
    /// only reaches the paired watch (Tiger's iPhone → Andrew's Watch via
    /// Family Setup pairing).
    func sendBoostRequest(forMemberIds: [UUID], fidelity: LocationFidelity, ttl: TimeInterval) {
        guard let session, session.activationState == .activated else { return }
        let payload: [String: Any] = [
            "type": "boostRequest",
            "id": UUID().uuidString,
            "fromMemberId": FamilyStore.shared.account.memberId.uuidString,
            "forMemberIds": forMemberIds.map { $0.uuidString },
            "fidelity": fidelity.rawValue,
            "expiresAt": Date().addingTimeInterval(ttl).timeIntervalSince1970
        ]
        session.transferUserInfo(payload)
    }

    /// Cancel any boost request from this device.
    func sendBoostCancel() {
        guard let session, session.activationState == .activated else { return }
        let payload: [String: Any] = [
            "type": "boostCancel",
            "fromMemberId": FamilyStore.shared.account.memberId.uuidString
        ]
        session.transferUserInfo(payload)
    }

    // MARK: - Serialization

    private func serialize(hub: Hub) -> [String: Any] {
        [
            "id": hub.id.uuidString,
            "name": hub.name,
            "icon": hub.icon,
            "address": hub.address,
            "lat": hub.latitude,
            "lon": hub.longitude,
            "haloRadiusMeters": hub.haloRadiusMeters,
            "colorHex": hub.colorHex,
            "assignedMemberIds": hub.assignedMemberIds.map { $0.uuidString }
        ]
    }
    private func serialize(member: Member) -> [String: Any] {
        [
            "id": member.id.uuidString,
            "name": member.name,
            "displayName": member.displayName,
            "initial": member.initial,
            "accentColorHex": member.accentColorHex,
            "preferredThemeId": member.preferredThemeId
        ]
    }
    private func serialize(device: Device) -> [String: Any] {
        [
            "id": device.id.uuidString,
            "memberId": device.memberId.uuidString,
            "kind": device.kind.rawValue,
            "displayName": device.displayName,
            "hasCellularData": device.hasCellularData
        ]
    }
    /// Latest reading per (memberId, deviceId) — flat list.
    private func serializePresence() -> [[String: Any]] {
        var out: [[String: Any]] = []
        for (memberId, byDevice) in PresenceStore.shared.readings {
            for (deviceId, r) in byDevice {
                out.append([
                    "memberId": memberId.uuidString,
                    "deviceId": deviceId.uuidString,
                    "lat": r.latitude,
                    "lon": r.longitude,
                    "accuracy": r.horizontalAccuracy,
                    "timestamp": r.timestamp.timeIntervalSince1970,
                    "battery": r.batteryPercent ?? -1
                ])
            }
        }
        return out
    }

    // MARK: - Deserialization (consumed by both sides)

    private func ingestLocationReading(_ payload: [String: Any]) {
        guard
            let memberStr = payload["memberId"] as? String,
            let memberId = UUID(uuidString: memberStr),
            let deviceStr = payload["deviceId"] as? String,
            let deviceId = UUID(uuidString: deviceStr),
            let lat = payload["lat"] as? Double,
            let lon = payload["lon"] as? Double,
            let acc = payload["accuracy"] as? Double,
            let ts = payload["timestamp"] as? Double
        else { return }
        let battery = payload["battery"] as? Int ?? -1
        let reading = LocationReading(
            memberId: memberId,
            deviceId: deviceId,
            latitude: lat,
            longitude: lon,
            horizontalAccuracy: acc,
            timestamp: Date(timeIntervalSince1970: ts),
            inHubId: nil,
            state: .unknown,
            batteryPercent: battery >= 0 ? battery : nil,
            isOnWrist: payload["onWrist"] as? Bool,
            isMoving: payload["moving"] as? Bool
        )
        PresenceStore.shared.ingest(reading)
        self.lastSyncAt = Date()
    }

    /// On the iPhone, a quick-reply message from the watch lands in the
    /// guardian's notification feed and fires a local UNNotification so it
    /// surfaces to the wearer's family even if HaloWalk isn't open.
    /// On the watch, we just record the lastSyncAt — outbound messages
    /// are the watch's own concern, and inbound messages aren't supported
    /// on the wearer's watch yet.
    private func ingestMessage(_ payload: [String: Any]) {
        guard
            let fromStr = payload["fromMemberId"] as? String,
            let fromId = UUID(uuidString: fromStr),
            let toStr = payload["toMemberId"] as? String,
            let toId = UUID(uuidString: toStr),
            let body = payload["body"] as? String
        else { return }
        self.lastSyncAt = Date()
        #if os(iOS)
        let from = FamilyStore.shared.member(fromId)
        let to = FamilyStore.shared.member(toId)
        let title: String = {
            if let from { return "\(from.displayName) said:" }
            return "Message from watch"
        }()
        let n = AppNotification(
            id: UUID(),
            severity: .quiet,
            category: .wearerResponded,
            title: title,
            body: body,
            timestamp: Date(),
            aboutMemberId: fromId,
            triggeredByTriggerId: nil,
            suggestedRespond: .quickReply,
            read: false,
            dismissed: false
        )
        NotificationStore.shared.add(n)
        // Only fire a system banner to the recipient guardian. Today the
        // guardian = whoever is signed in on this iPhone.
        if to?.id == FamilyStore.shared.account.memberId {
            NotificationDelivery.shared.deliver(n)
        }
        #endif
    }

    private func applyContext(_ payload: [String: Any]) {
        if let hubsRaw = payload["hubs"] as? [[String: Any]] {
            let hubs = hubsRaw.compactMap(deserialize(hub:))
            HubStore.shared.replaceAll(hubs: hubs)
        }
        if let membersRaw = payload["members"] as? [[String: Any]] {
            let members = membersRaw.compactMap(deserialize(member:))
            FamilyStore.shared.replaceAll(members: members)
        }
        if let devicesRaw = payload["devices"] as? [[String: Any]] {
            let devices = devicesRaw.compactMap(deserialize(device:))
            // Preserve the local device entry if not in the iPhone's list.
            let merged = mergeDevices(incoming: devices)
            FamilyStore.shared.devices = merged
        }
        if let presenceRaw = payload["presence"] as? [[String: Any]] {
            for entry in presenceRaw {
                ingestLocationReading(entry)
            }
        }
        if let themeId = payload["themeId"] as? String {
            ThemeManager.shared.setTheme(themeId)
        }
        if let sharingIds = payload["guardiansSharing"] as? [String] {
            PresenceStore.shared.guardiansSharing = Set(
                sharingIds.compactMap { UUID(uuidString: $0) }
            )
        }
        self.lastSyncAt = Date()
    }

    private func mergeDevices(incoming: [Device]) -> [Device] {
        let local = FamilyStore.shared.devices
        let incomingIds = Set(incoming.map(\.id))
        // Keep any local devices that weren't in the incoming push (e.g. a
        // freshly-created "this watch" entry that hasn't been registered
        // upstream yet).
        let preserved = local.filter { !incomingIds.contains($0.id) }
        return incoming + preserved
    }

    private func deserialize(hub raw: [String: Any]) -> Hub? {
        guard
            let idStr = raw["id"] as? String, let id = UUID(uuidString: idStr),
            let name = raw["name"] as? String,
            let icon = raw["icon"] as? String,
            let address = raw["address"] as? String,
            let lat = raw["lat"] as? Double,
            let lon = raw["lon"] as? Double,
            let radius = raw["haloRadiusMeters"] as? Double,
            let colorHex = raw["colorHex"] as? UInt32
        else { return nil }
        let assigned = (raw["assignedMemberIds"] as? [String])?
            .compactMap { UUID(uuidString: $0) } ?? []
        return Hub(
            id: id, name: name, icon: icon, address: address,
            latitude: lat, longitude: lon,
            haloRadiusMeters: radius, colorHex: colorHex,
            assignedMemberIds: assigned,
            createdById: id, createdAt: Date(),
            notes: nil
        )
    }
    private func deserialize(member raw: [String: Any]) -> Member? {
        guard
            let idStr = raw["id"] as? String, let id = UUID(uuidString: idStr),
            let name = raw["name"] as? String,
            let displayName = raw["displayName"] as? String,
            let initial = raw["initial"] as? String,
            let accentColorHex = raw["accentColorHex"] as? UInt32,
            let preferredThemeId = raw["preferredThemeId"] as? String
        else { return nil }
        return Member(
            id: id, name: name, displayName: displayName,
            birthday: nil, pronouns: nil, initial: initial,
            accentColorHex: accentColorHex, avatarSystemImage: nil,
            preferredThemeId: preferredThemeId
        )
    }
    private func deserialize(device raw: [String: Any]) -> Device? {
        guard
            let idStr = raw["id"] as? String, let id = UUID(uuidString: idStr),
            let memberStr = raw["memberId"] as? String, let memberId = UUID(uuidString: memberStr),
            let kindStr = raw["kind"] as? String,
            let kind = Device.Kind(rawValue: kindStr),
            let displayName = raw["displayName"] as? String,
            let hasCellular = raw["hasCellularData"] as? Bool
        else { return nil }
        return Device(
            id: id, memberId: memberId, kind: kind,
            displayName: displayName, hasCellularData: hasCellular,
            isOnWrist: nil, lastSeenAt: nil, batteryPercent: nil
        )
    }
}

extension WatchSync: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                              activationDidCompleteWith activationState: WCSessionActivationState,
                              error: Error?) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            self.isPaired = (activationState == .activated)
            self.pushApplicationContext()
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            // Watch is the consumer for now; iPhone is the source of truth.
            #if os(watchOS)
            self.applyContext(applicationContext)
            #endif
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in
            switch userInfo["type"] as? String {
            case "locationReading":
                self.ingestLocationReading(userInfo)
            case "message":
                self.ingestMessage(userInfo)
            case "boostRequest":
                self.ingestBoostRequest(userInfo)
            case "boostCancel":
                self.ingestBoostCancel(userInfo)
            default:
                break
            }
        }
    }

    private func ingestBoostRequest(_ payload: [String: Any]) {
        guard
            let idStr = payload["id"] as? String,
            let id = UUID(uuidString: idStr),
            let fromStr = payload["fromMemberId"] as? String,
            let fromId = UUID(uuidString: fromStr),
            let memberStrs = payload["forMemberIds"] as? [String],
            let fidelityRaw = payload["fidelity"] as? Int,
            let fidelity = LocationFidelity(rawValue: fidelityRaw),
            let expiresAt = payload["expiresAt"] as? Double
        else { return }
        let memberIds = memberStrs.compactMap(UUID.init(uuidString:))
        let boost = RemoteBoost(
            id: id,
            fromMemberId: fromId,
            forMemberIds: memberIds,
            fidelity: fidelity,
            expiresAt: Date(timeIntervalSince1970: expiresAt)
        )
        ContinuousWatchStore.shared.addIncomingBoost(boost)
        self.lastSyncAt = Date()
    }
    private func ingestBoostCancel(_ payload: [String: Any]) {
        guard
            let fromStr = payload["fromMemberId"] as? String,
            let fromId = UUID(uuidString: fromStr)
        else { return }
        ContinuousWatchStore.shared.removeIncomingBoosts(from: fromId)
        self.lastSyncAt = Date()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }
}
