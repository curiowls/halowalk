import Foundation
import CloudKit

/// Single source of truth for HaloWalk's CloudKit schema: container id,
/// zone, record type names, field keys, and the model ⇄ CKRecord
/// conversion. `HaloCloudSync` (the CKSyncEngine owner) is the only
/// caller — everything CloudKit-shaped lives here so the sync engine
/// stays focused on sync mechanics.
enum CloudKitSchema {
    static let containerID = "iCloud.com.halowalk.guardian"

    /// One custom zone per family. The owner creates it in their private
    /// DB; Build C shares it via CKShare and participants see it in their
    /// shared DB. The zone name is constant — a device belongs to exactly
    /// one HaloWalk family.
    static let zoneName = "HaloFamily"
    static var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    enum RecordType {
        static let family = "Family"
        static let member = "Member"
        static let relationship = "Relationship"
        static let device = "Device"
        static let hub = "Hub"
        static let locationReading = "LocationReading"
    }

    // Stable record names. Model UUID → record name so re-saving the same
    // model overwrites rather than duplicates. LocationReading is keyed by
    // (member, device) so each device has exactly one latest-reading
    // record that gets overwritten, never appended.
    static func familyRecordID(_ id: UUID) -> CKRecord.ID {
        .init(recordName: "family_\(id.uuidString)", zoneID: zoneID)
    }
    static func memberRecordID(_ id: UUID) -> CKRecord.ID {
        .init(recordName: "member_\(id.uuidString)", zoneID: zoneID)
    }
    static func relationshipRecordID(_ id: UUID) -> CKRecord.ID {
        .init(recordName: "rel_\(id.uuidString)", zoneID: zoneID)
    }
    static func deviceRecordID(_ id: UUID) -> CKRecord.ID {
        .init(recordName: "device_\(id.uuidString)", zoneID: zoneID)
    }
    static func hubRecordID(_ id: UUID) -> CKRecord.ID {
        .init(recordName: "hub_\(id.uuidString)", zoneID: zoneID)
    }
    static func readingRecordID(memberId: UUID, deviceId: UUID) -> CKRecord.ID {
        .init(recordName: "reading_\(memberId.uuidString)_\(deviceId.uuidString)", zoneID: zoneID)
    }
}

// MARK: - Member ⇄ CKRecord

extension CloudKitSchema {
    static func record(for member: Member) -> CKRecord {
        let r = CKRecord(recordType: RecordType.member, recordID: memberRecordID(member.id))
        r["id"] = member.id.uuidString
        r["name"] = member.name
        r["displayName"] = member.displayName
        r["initial"] = member.initial
        r["accentColorHex"] = Int64(member.accentColorHex)
        r["avatarId"] = member.avatarId
        r["avatarSystemImage"] = member.avatarSystemImage
        r["pronouns"] = member.pronouns
        r["birthday"] = member.birthday
        r["preferredThemeId"] = member.preferredThemeId
        return r
    }
    static func member(from r: CKRecord) -> Member? {
        guard
            let idStr = r["id"] as? String, let id = UUID(uuidString: idStr),
            let name = r["name"] as? String,
            let displayName = r["displayName"] as? String,
            let initial = r["initial"] as? String,
            let accent = r["accentColorHex"] as? Int64,
            let themeId = r["preferredThemeId"] as? String
        else { return nil }
        return Member(
            id: id, name: name, displayName: displayName,
            birthday: r["birthday"] as? Date,
            pronouns: r["pronouns"] as? String,
            initial: initial,
            accentColorHex: UInt32(truncatingIfNeeded: accent),
            avatarSystemImage: r["avatarSystemImage"] as? String,
            avatarId: r["avatarId"] as? String,
            preferredThemeId: themeId
        )
    }
}

// MARK: - Relationship ⇄ CKRecord

extension CloudKitSchema {
    static func record(for rel: Relationship) -> CKRecord {
        let r = CKRecord(recordType: RecordType.relationship, recordID: relationshipRecordID(rel.id))
        r["id"] = rel.id.uuidString
        r["watcherId"] = rel.watcherId.uuidString
        r["watchedId"] = rel.watchedId.uuidString
        r["label"] = rel.label
        r["createdAt"] = rel.createdAt
        return r
    }
    static func relationship(from r: CKRecord) -> Relationship? {
        guard
            let idStr = r["id"] as? String, let id = UUID(uuidString: idStr),
            let wr = r["watcherId"] as? String, let watcherId = UUID(uuidString: wr),
            let wd = r["watchedId"] as? String, let watchedId = UUID(uuidString: wd),
            let createdAt = r["createdAt"] as? Date
        else { return nil }
        return Relationship(
            id: id, watcherId: watcherId, watchedId: watchedId,
            label: r["label"] as? String, createdAt: createdAt
        )
    }
}

// MARK: - Device ⇄ CKRecord

extension CloudKitSchema {
    static func record(for d: Device) -> CKRecord {
        let r = CKRecord(recordType: RecordType.device, recordID: deviceRecordID(d.id))
        r["id"] = d.id.uuidString
        r["memberId"] = d.memberId.uuidString
        r["kind"] = d.kind.rawValue
        r["displayName"] = d.displayName
        r["hasCellularData"] = d.hasCellularData ? 1 : 0
        return r
    }
    static func device(from r: CKRecord) -> Device? {
        guard
            let idStr = r["id"] as? String, let id = UUID(uuidString: idStr),
            let mid = r["memberId"] as? String, let memberId = UUID(uuidString: mid),
            let kindRaw = r["kind"] as? String, let kind = Device.Kind(rawValue: kindRaw),
            let displayName = r["displayName"] as? String
        else { return nil }
        let cellular = (r["hasCellularData"] as? Int64 ?? 0) == 1
        return Device(
            id: id, memberId: memberId, kind: kind,
            displayName: displayName, hasCellularData: cellular,
            isOnWrist: nil, lastSeenAt: nil, batteryPercent: nil
        )
    }
}

// MARK: - Hub ⇄ CKRecord

extension CloudKitSchema {
    static func record(for hub: Hub) -> CKRecord {
        let r = CKRecord(recordType: RecordType.hub, recordID: hubRecordID(hub.id))
        r["id"] = hub.id.uuidString
        r["name"] = hub.name
        r["icon"] = hub.icon
        r["address"] = hub.address
        r["latitude"] = hub.latitude
        r["longitude"] = hub.longitude
        r["haloRadiusMeters"] = hub.haloRadiusMeters
        r["colorHex"] = Int64(hub.colorHex)
        r["assignedMemberIds"] = hub.assignedMemberIds.map(\.uuidString)
        r["createdById"] = hub.createdById.uuidString
        r["createdAt"] = hub.createdAt
        r["notes"] = hub.notes
        return r
    }
    static func hub(from r: CKRecord) -> Hub? {
        guard
            let idStr = r["id"] as? String, let id = UUID(uuidString: idStr),
            let name = r["name"] as? String,
            let icon = r["icon"] as? String,
            let address = r["address"] as? String,
            let lat = r["latitude"] as? Double,
            let lon = r["longitude"] as? Double,
            let radius = r["haloRadiusMeters"] as? Double,
            let color = r["colorHex"] as? Int64,
            let creator = r["createdById"] as? String, let createdById = UUID(uuidString: creator),
            let createdAt = r["createdAt"] as? Date
        else { return nil }
        let assigned = (r["assignedMemberIds"] as? [String])?.compactMap { UUID(uuidString: $0) } ?? []
        return Hub(
            id: id, name: name, icon: icon, address: address,
            latitude: lat, longitude: lon,
            haloRadiusMeters: radius, colorHex: UInt32(truncatingIfNeeded: color),
            assignedMemberIds: assigned,
            createdById: createdById, createdAt: createdAt,
            notes: r["notes"] as? String
        )
    }
}

// MARK: - LocationReading ⇄ CKRecord (overwrite per member+device)

extension CloudKitSchema {
    static func record(for reading: LocationReading) -> CKRecord {
        let r = CKRecord(
            recordType: RecordType.locationReading,
            recordID: readingRecordID(memberId: reading.memberId, deviceId: reading.deviceId)
        )
        r["memberId"] = reading.memberId.uuidString
        r["deviceId"] = reading.deviceId.uuidString
        r["latitude"] = reading.latitude
        r["longitude"] = reading.longitude
        r["horizontalAccuracy"] = reading.horizontalAccuracy
        r["timestamp"] = reading.timestamp
        r["inHubId"] = reading.inHubId?.uuidString
        r["state"] = reading.state.rawValue
        r["batteryPercent"] = reading.batteryPercent.map(Int64.init)
        r["isOnWrist"] = reading.isOnWrist.map { $0 ? Int64(1) : Int64(0) }
        r["isMoving"] = reading.isMoving.map { $0 ? Int64(1) : Int64(0) }
        return r
    }
    static func reading(from r: CKRecord) -> LocationReading? {
        guard
            let mid = r["memberId"] as? String, let memberId = UUID(uuidString: mid),
            let did = r["deviceId"] as? String, let deviceId = UUID(uuidString: did),
            let lat = r["latitude"] as? Double,
            let lon = r["longitude"] as? Double,
            let acc = r["horizontalAccuracy"] as? Double,
            let ts = r["timestamp"] as? Date,
            let stateRaw = r["state"] as? String,
            let state = LocationReading.HaloState(rawValue: stateRaw)
        else { return nil }
        let inHub = (r["inHubId"] as? String).flatMap { UUID(uuidString: $0) }
        let battery = (r["batteryPercent"] as? Int64).map { Int($0) }
        let onWrist = (r["isOnWrist"] as? Int64).map { $0 == 1 }
        let moving = (r["isMoving"] as? Int64).map { $0 == 1 }
        return LocationReading(
            memberId: memberId, deviceId: deviceId,
            latitude: lat, longitude: lon, horizontalAccuracy: acc,
            timestamp: ts, inHubId: inHub, state: state,
            batteryPercent: battery, isOnWrist: onWrist, isMoving: moving
        )
    }
}

// MARK: - Family ⇄ CKRecord (the CKShare root in Build C)

extension CloudKitSchema {
    static func record(for family: Family) -> CKRecord {
        let r = CKRecord(recordType: RecordType.family, recordID: familyRecordID(family.id))
        r["id"] = family.id.uuidString
        r["name"] = family.name
        r["organizerId"] = family.organizerId.uuidString
        r["memberIds"] = family.memberIds.map(\.uuidString)
        r["createdAt"] = family.createdAt
        return r
    }
    static func family(from r: CKRecord) -> Family? {
        guard
            let idStr = r["id"] as? String, let id = UUID(uuidString: idStr),
            let name = r["name"] as? String,
            let org = r["organizerId"] as? String, let organizerId = UUID(uuidString: org),
            let createdAt = r["createdAt"] as? Date
        else { return nil }
        let memberIds = (r["memberIds"] as? [String])?.compactMap { UUID(uuidString: $0) } ?? []
        return Family(
            id: id, name: name, organizerId: organizerId,
            memberIds: memberIds, createdAt: createdAt
        )
    }
}
