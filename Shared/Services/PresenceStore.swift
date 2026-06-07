import Foundation
import CoreLocation
import Combine

/// Latest known reading per (Member, Device). When a Member has multiple
/// devices, the resolver heuristic picks one canonical "primary" reading
/// the rest of the UI uses by default. The two-marker map / divergence
/// notification surface the divergence honestly when devices disagree.
@MainActor
final class PresenceStore: ObservableObject {
    static let shared = PresenceStore()

    /// Keyed [memberId: [deviceId: reading]]
    @Published var readings: [UUID: [UUID: LocationReading]] = [:]
    @Published var guardiansSharing: Set<UUID> = []

    init() {
        for r in MockData.initialReadings {
            var byDevice = readings[r.memberId] ?? [:]
            byDevice[r.deviceId] = r
            readings[r.memberId] = byDevice
        }
        guardiansSharing = [MockData.tigerId, MockData.audreyId]
    }

    // MARK: - Reads

    /// All recent readings for a Member.
    func readings(for memberId: UUID) -> [LocationReading] {
        Array((readings[memberId] ?? [:]).values)
    }

    /// Reading from a specific device, if any.
    func reading(memberId: UUID, deviceId: UUID) -> LocationReading? {
        readings[memberId]?[deviceId]
    }

    /// Resolver: pick the most-likely-on-person device's reading.
    /// Order: wrist-detect → fresh + moving → fresh → most recent stale.
    func primaryReading(for memberId: UUID) -> LocationReading? {
        let all = Array((readings[memberId] ?? [:]).values)
        guard !all.isEmpty else { return nil }
        let now = Date()
        let fresh = all.filter { now.timeIntervalSince($0.timestamp) < 300 }

        // 1. Wrist-detect (only watches set this, only when actually worn)
        if let wrist = fresh.first(where: { $0.isOnWrist == true }) {
            return wrist
        }
        // 2. Fresh + moving
        let movingFresh = fresh.filter { $0.isMoving == true }
        if let m = movingFresh.sorted(by: { $0.timestamp > $1.timestamp }).first {
            return m
        }
        // 3. Most recent fresh
        if let r = fresh.sorted(by: { $0.timestamp > $1.timestamp }).first {
            return r
        }
        // 4. Most recent stale (last resort)
        return all.sorted(by: { $0.timestamp > $1.timestamp }).first
    }

    /// Best reading for a single device (used by per-device rows in the UI).
    func reading(for memberId: UUID) -> LocationReading? {
        primaryReading(for: memberId)
    }

    // MARK: - Divergence

    /// Returns the meters between the Member's two most-distant fresh
    /// devices. nil if fewer than 2 fresh readings.
    func divergenceMeters(for memberId: UUID) -> Double? {
        let now = Date()
        let fresh = (readings[memberId] ?? [:]).values
            .filter { now.timeIntervalSince($0.timestamp) < 300 }
        guard fresh.count >= 2 else { return nil }
        var maxD: Double = 0
        let arr = Array(fresh)
        for i in 0..<arr.count {
            for j in (i + 1)..<arr.count {
                let a = CLLocation(latitude: arr[i].latitude, longitude: arr[i].longitude)
                let b = CLLocation(latitude: arr[j].latitude, longitude: arr[j].longitude)
                maxD = max(maxD, a.distance(from: b))
            }
        }
        return maxD
    }
    func isDiverged(_ memberId: UUID, threshold: Double = 100) -> Bool {
        (divergenceMeters(for: memberId) ?? 0) > threshold
    }

    // MARK: - Writes

    func ingest(_ reading: LocationReading) {
        var byDevice = readings[reading.memberId] ?? [:]
        byDevice[reading.deviceId] = reading
        readings[reading.memberId] = byDevice
    }

    func removeReadings(for memberId: UUID) {
        readings.removeValue(forKey: memberId)
        guardiansSharing.remove(memberId)
    }

    /// Convenience for guardian "moving pin" features.
    func guardianPresences(in family: Family, knownMembers: [Member]) -> [GuardianPresence] {
        let watchers = knownMembers.filter { m in
            FamilyStore.shared.relationships.contains { $0.watcherId == m.id }
        }
        return watchers.map { g in
            GuardianPresence(
                guardianId: g.id,
                lastReading: primaryReading(for: g.id),
                sharingLocation: guardiansSharing.contains(g.id)
            )
        }
    }
}
