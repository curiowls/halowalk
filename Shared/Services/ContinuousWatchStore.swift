import Foundation
import Combine

/// Persists active ContinuousWatch sessions so they survive relaunch
/// (a guardian who started "watch Andrew until he gets home" expects
/// it to survive backgrounding the app). Notifies via Combine so the
/// LocationFidelityCoordinator and the UI banner can react.
@MainActor
final class ContinuousWatchStore: ObservableObject {
    static let shared = ContinuousWatchStore()

    @Published private(set) var active: [ContinuousWatch] = []
    /// Boost requests received from other devices via WatchSync (or, in
    /// the future, CloudKit). Each carries an expiry; a timer prunes them.
    @Published private(set) var incomingBoosts: [RemoteBoost] = []

    private static let key = "halowalk.continuous_watches.v1"
    private var pruneTimer: Timer?

    private init() {
        load()
        startPruneTimer()
    }

    // MARK: - Watches

    /// Returns true if any active watch's watchedId matches the member.
    func isWatching(_ memberId: UUID) -> Bool {
        active.contains { $0.watchedId == memberId }
    }
    /// Returns watches initiated by this user.
    func watches(by memberId: UUID) -> [ContinuousWatch] {
        active.filter { $0.watcherId == memberId }
    }
    /// Returns watches targeting this user (i.e. someone is watching them).
    func watchesOf(_ memberId: UUID) -> [ContinuousWatch] {
        active.filter { $0.watchedId == memberId }
    }

    func start(_ watch: ContinuousWatch) {
        // Idempotent: replace any existing watch from the same watcher
        // for the same target so we don't accumulate duplicates.
        active.removeAll {
            $0.watcherId == watch.watcherId && $0.watchedId == watch.watchedId
        }
        active.append(watch)
        save()
    }
    func stop(_ id: UUID) {
        active.removeAll { $0.id == id }
        save()
    }
    func stopAll(byWatcher watcherId: UUID, watchedId: UUID) {
        active.removeAll {
            $0.watcherId == watcherId && $0.watchedId == watchedId
        }
        save()
    }

    /// Called from the trigger engine on hub entry/exit so time-bounded
    /// watches can resolve. Returns the resolved watches so the caller
    /// can fire confirmation notifications.
    @discardableResult
    func tick(now: Date = Date(),
              recentlyEnteredHubId: UUID? = nil,
              recentlyExitedHubId: UUID? = nil) -> [ContinuousWatch] {
        let resolved = active.filter {
            $0.hasResolved(
                now: now,
                recentlyEnteredHubId: recentlyEnteredHubId,
                recentlyExitedHubId: recentlyExitedHubId
            )
        }
        if !resolved.isEmpty {
            let resolvedIds = Set(resolved.map(\.id))
            active.removeAll { resolvedIds.contains($0.id) }
            save()
        }
        return resolved
    }

    // MARK: - Incoming boosts

    func addIncomingBoost(_ boost: RemoteBoost) {
        // Replace any prior boost from the same sender — fresh wins.
        incomingBoosts.removeAll { $0.fromMemberId == boost.fromMemberId }
        incomingBoosts.append(boost)
    }
    func removeIncomingBoosts(from memberId: UUID) {
        incomingBoosts.removeAll { $0.fromMemberId == memberId }
    }
    func pruneExpiredBoosts(now: Date = Date()) {
        let before = incomingBoosts.count
        incomingBoosts.removeAll { $0.expiresAt <= now }
        if incomingBoosts.count != before {
            // didChange via @Published triggers downstream
        }
    }

    /// Highest fidelity any active incoming boost requests for the given
    /// member. nil if no boost applies.
    func incomingBoostFidelity(forMemberId memberId: UUID, now: Date = Date()) -> LocationFidelity? {
        let applicable = incomingBoosts.filter {
            $0.expiresAt > now && $0.forMemberIds.contains(memberId)
        }
        return applicable.map(\.fidelity).max()
    }

    // MARK: - Persistence

    private func startPruneTimer() {
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.pruneExpiredBoosts()
                // Time/duration-based watches resolve themselves here too.
                self.tick()
            }
        }
    }
    private func load() {
        guard let d = UserDefaults.standard.data(forKey: Self.key),
              let parsed = try? JSONDecoder().decode([ContinuousWatch].self, from: d) else {
            active = []
            return
        }
        active = parsed
    }
    private func save() {
        if let d = try? JSONEncoder().encode(active) {
            UserDefaults.standard.set(d, forKey: Self.key)
        }
    }
}
