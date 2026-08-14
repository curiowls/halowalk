import Foundation
import Combine

/// Persists temporary group walks. This first slice is local/shared-model
/// ready; CloudKit sync can add a WalkSession record type when we deploy the
/// group-walking schema.
@MainActor
final class WalkSessionStore: ObservableObject {
    static let shared = WalkSessionStore()

    @Published private(set) var sessions: [WalkSession] = []

    private static let key = "halowalk.walk_sessions.v1"
    private var pruneTimer: Timer?

    private init() {
        load()
        startPruneTimer()
    }

    var activeSessions: [WalkSession] {
        sessions.filter(\.isActive)
    }

    func activeSessions(for memberId: UUID) -> [WalkSession] {
        activeSessions.filter { $0.includes(memberId) }
    }

    func isMemberInActiveWalk(_ memberId: UUID) -> Bool {
        activeSessions.contains { $0.includes(memberId) }
    }

    @discardableResult
    func start(
        name rawName: String,
        organizerId: UUID,
        participantIds: [UUID],
        destinationHubId: UUID?,
        destinationName rawDestinationName: String,
        durationMinutes: Int,
        meetingRadiusMeters: Double = 120
    ) -> WalkSession {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let destinationName = rawDestinationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let uniqueParticipants = Array(Set(participantIds + [organizerId]))
        let now = Date()
        let session = WalkSession(
            id: UUID(),
            name: name.isEmpty ? "Group walk" : String(name.prefix(60)),
            organizerId: organizerId,
            participantIds: uniqueParticipants,
            destinationHubId: destinationHubId,
            destinationName: destinationName.isEmpty ? "Meeting point" : String(destinationName.prefix(60)),
            meetingRadiusMeters: meetingRadiusMeters,
            startedAt: now,
            endsAt: now.addingTimeInterval(TimeInterval(max(5, durationMinutes)) * 60),
            endedAt: nil
        )
        sessions.insert(session, at: 0)
        save()
        return session
    }

    func end(_ id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].endedAt = Date()
        save()
    }

    func delete(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        save()
    }

    func pruneExpired(now: Date = Date()) {
        var changed = false
        for index in sessions.indices where sessions[index].endedAt == nil && sessions[index].endsAt <= now {
            sessions[index].endedAt = sessions[index].endsAt
            changed = true
        }
        if changed { save() }
    }

    private func startPruneTimer() {
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pruneExpired()
            }
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let parsed = try? JSONDecoder().decode([WalkSession].self, from: data) else {
            sessions = []
            return
        }
        sessions = parsed
        pruneExpired()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

