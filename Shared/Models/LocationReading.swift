import Foundation
import CoreLocation

/// A single location sample. Now keyed by *both* memberId AND deviceId —
/// a Member with two devices produces two parallel reading streams that
/// the resolver combines into a single "primary location."
struct LocationReading: Codable, Hashable {
    var memberId: UUID
    var deviceId: UUID
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double
    var timestamp: Date

    var inHubId: UUID?
    var state: HaloState

    var batteryPercent: Int?
    /// Apple Watch is on the user's wrist (when known). Drives the resolver
    /// heuristic that prefers the wrist-on device.
    var isOnWrist: Bool?
    /// Device has been moving in the last ~2 minutes. Drives the "moving
    /// device wins over stationary" tiebreak in the resolver.
    var isMoving: Bool?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum HaloState: String, Codable {
        case inHalo
        case onCorridor
        case wandering
        case leftOrbit
        case noPing
        case unknown
    }
}

/// Tracks a guardian's location for the "head toward Mom" feature on a
/// wearer's watch/phone. Same shape as LocationReading + a sharing flag.
struct GuardianPresence: Codable {
    var guardianId: UUID
    var lastReading: LocationReading?
    var sharingLocation: Bool
}
