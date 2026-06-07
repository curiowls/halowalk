import Foundation
import Combine

/// Watches the local stores for changes and pushes the latest state to the
/// paired Watch (or iPhone) via WatchSync. Debounced so a burst of edits
/// (e.g. importing many hubs in quick succession) only generates one push.
@MainActor
final class WatchSyncCoordinator {
    static let shared = WatchSyncCoordinator()

    private var cancellables = Set<AnyCancellable>()

    private init() {}

    func start() {
        // Push when hubs change.
        HubStore.shared.$hubs
            .dropFirst()    // skip the initial value; we already push on activation
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { _ in WatchSync.shared.pushApplicationContext() }
            .store(in: &cancellables)

        // Push when members change (add/edit/theme).
        FamilyStore.shared.$members
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { _ in WatchSync.shared.pushApplicationContext() }
            .store(in: &cancellables)

        // Push when triggers change.
        TriggerStore.shared.$triggers
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { _ in WatchSync.shared.pushApplicationContext() }
            .store(in: &cancellables)

        // Push when guardian sharing changes.
        PresenceStore.shared.$guardiansSharing
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { _ in WatchSync.shared.pushApplicationContext() }
            .store(in: &cancellables)

        // Push when presence readings change (e.g. the iPhone moves and
        // updates its own pin) so the watch sees the latest positions.
        // 5-second debounce keeps the WatchConnectivity queue from
        // pulsing on every tiny GPS sample while the user walks.
        PresenceStore.shared.$readings
            .dropFirst()
            .debounce(for: .seconds(5), scheduler: DispatchQueue.main)
            .sink { _ in WatchSync.shared.pushApplicationContext() }
            .store(in: &cancellables)

        // Push when theme changes.
        ThemeManager.shared.$theme
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { _ in WatchSync.shared.pushApplicationContext() }
            .store(in: &cancellables)
    }
}
