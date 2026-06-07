import Foundation

/// A device that belongs to a Member. A Member can have multiple — e.g. an
/// iPhone + an Apple Watch. Each device produces its own LocationReadings.
struct Device: Identifiable, Codable, Hashable {
    let id: UUID
    var memberId: UUID
    var kind: Kind
    var displayName: String
    var hasCellularData: Bool
    /// True when this device is the one currently on the user's wrist (only
    /// meaningful for Apple Watch). Set by the watch app reporting its own
    /// state via WatchConnectivity.
    var isOnWrist: Bool?
    var lastSeenAt: Date?
    var batteryPercent: Int?

    enum Kind: String, Codable {
        case iPhone
        case appleWatch
        case iPad

        var sfSymbol: String {
            switch self {
            case .iPhone:     return "iphone"
            case .appleWatch: return "applewatch"
            case .iPad:       return "ipad"
            }
        }
        var displayLabel: String {
            switch self {
            case .iPhone:     return "iPhone"
            case .appleWatch: return "Apple Watch"
            case .iPad:       return "iPad"
            }
        }
    }
}
