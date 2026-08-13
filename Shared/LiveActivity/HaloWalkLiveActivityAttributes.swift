#if canImport(ActivityKit)
import ActivityKit
import Foundation

struct HaloWalkLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var statusLine: String
        var locationLine: String
        var freshnessLine: String
        var conditionLine: String
        var accuracyLine: String?
        var stateKind: TrackingStateKind
        var progress: Double?
        var updatedAt: Date
        var endsAt: Date?
    }

    var watchId: UUID
    var watchedMemberId: UUID
    var watcherId: UUID
    var watchedName: String
    var watchedInitial: String
    var accentHex: UInt32
    var startedAt: Date
}

enum TrackingStateKind: String, Codable, Hashable {
    case live
    case atHub
    case moving
    case away
    case stale
    case unknown
}
#endif
