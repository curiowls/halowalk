import Foundation
import CoreLocation
import SwiftUI

/// A named place with a halo radius. Hubs are shared across the family —
/// a single "Home" hub can apply to multiple Members.
struct Hub: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var address: String
    var latitude: Double
    var longitude: Double
    var haloRadiusMeters: Double
    var colorHex: UInt32

    /// Members tracked against this hub. Empty = applies to all watched
    /// Members (i.e. anyone who is the target of a watcher relationship).
    var assignedMemberIds: [UUID]

    var createdById: UUID
    var createdAt: Date
    var notes: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    var color: Color { Color(hex: colorHex) }

    static func == (lhs: Hub, rhs: Hub) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct Corridor: Identifiable, Codable {
    let id: UUID
    var name: String
    var fromHubId: UUID
    var toHubId: UUID
    var assignedMemberIds: [UUID]
    var maxDurationMinutes: Int
    var pathLatitudes: [Double]
    var pathLongitudes: [Double]

    var pathCoordinates: [CLLocationCoordinate2D] {
        zip(pathLatitudes, pathLongitudes).map {
            CLLocationCoordinate2D(latitude: $0.0, longitude: $0.1)
        }
    }
}
