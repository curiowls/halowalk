import Foundation

/// A user-initiated "watch this person closely until X" session. Distinct
/// from the always-on monitoring profile — these are explicit, time-bound
/// upticks in fidelity. Examples:
///   • "Watch Andrew until he arrives Home"
///   • "Watch Maya for the next 30 minutes"
///
/// An active ContinuousWatch keeps the watcher's local fidelity at
/// foregroundCoarse for the duration, AND sends a BoostRequest to the
/// watched member's devices (via WatchSync today, CloudKit in Build 24+)
/// so the wearer's broadcast tier is bumped too.
///
/// Active continuous watches override quiet hours (explicit user intent).
struct ContinuousWatch: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let watcherId: UUID    // who initiated
    let watchedId: UUID    // whose location they want
    let until: UntilCondition
    let startedAt: Date
}

enum UntilCondition: Codable, Equatable, Hashable {
    case arrivesAtHub(hubId: UUID)
    case leavesHub(hubId: UUID)
    case untilTime(date: Date)
    case forDuration(seconds: TimeInterval)
    case manualStop
}

extension ContinuousWatch {
    /// Returns true if the `until` condition has been reached given the
    /// current time and (optionally) a hub-entry/exit event the engine
    /// just processed. Pure function — testable without state.
    func hasResolved(
        now: Date = Date(),
        recentlyEnteredHubId: UUID? = nil,
        recentlyExitedHubId: UUID? = nil
    ) -> Bool {
        switch until {
        case .untilTime(let date):
            return now >= date
        case .forDuration(let seconds):
            return now.timeIntervalSince(startedAt) >= seconds
        case .arrivesAtHub(let hubId):
            return recentlyEnteredHubId == hubId
        case .leavesHub(let hubId):
            return recentlyExitedHubId == hubId
        case .manualStop:
            return false
        }
    }

    /// Human-readable label for the active banner / list rows.
    func describeUntil(memberDisplayName: String, hubName: (UUID) -> String?) -> String {
        switch until {
        case .arrivesAtHub(let hubId):
            return "until \(memberDisplayName) arrives at \(hubName(hubId) ?? "their hub")"
        case .leavesHub(let hubId):
            return "until \(memberDisplayName) leaves \(hubName(hubId) ?? "their hub")"
        case .untilTime(let date):
            let f = DateFormatter()
            f.timeStyle = .short
            f.dateStyle = .none
            return "until \(f.string(from: date))"
        case .forDuration(let seconds):
            if seconds < 3600 { return "for \(Int(seconds / 60)) min" }
            let h = seconds / 3600
            return "for \(h.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(h)) : String(format: "%.1f", h)) hr"
        case .manualStop:
            return "until you stop"
        }
    }
}

/// Sent device-to-device over WatchSync (and later CloudKit). Receiving
/// device honors the boost for `expiresAt` then drops it.
struct RemoteBoost: Codable, Equatable, Hashable {
    let id: UUID
    let fromMemberId: UUID
    let forMemberIds: [UUID]
    let fidelity: LocationFidelity
    let expiresAt: Date
}
