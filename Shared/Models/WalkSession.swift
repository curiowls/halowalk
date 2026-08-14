import Foundation

/// A temporary group walking session. Unlike relationship-based monitoring,
/// a walk session is opt-in, time-bound, and centered on one meeting point.
struct WalkSession: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var organizerId: UUID
    var participantIds: [UUID]
    var destinationHubId: UUID?
    var destinationName: String
    var meetingRadiusMeters: Double
    var startedAt: Date
    var endsAt: Date
    var endedAt: Date?

    var isActive: Bool {
        endedAt == nil && Date() < endsAt
    }

    func includes(_ memberId: UUID) -> Bool {
        participantIds.contains(memberId)
    }
}

