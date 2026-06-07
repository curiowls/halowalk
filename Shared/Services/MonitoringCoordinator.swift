import Foundation
import Combine

/// Glue layer that keeps LocationManager's monitored regions in sync with
/// the Hub list and the wearer's identity. Without this, region monitoring
/// goes stale whenever a hub is added/removed/reassigned.
@MainActor
final class MonitoringCoordinator {
    static let shared = MonitoringCoordinator()

    private var cancellables = Set<AnyCancellable>()

    private init() {}

    func start() {
        // Re-register regions whenever hubs change.
        HubStore.shared.$hubs
            .sink { [weak self] hubs in
                guard let self else { return }
                let me = FamilyStore.shared.account.memberId
                LocationManager.shared.updateMonitoredRegions(forWearer: me, hubs: hubs)
            }
            .store(in: &cancellables)

        // Re-register regions whenever the signed-in account changes
        // (e.g. after onboarding).
        FamilyStore.shared.$account
            .sink { account in
                LocationManager.shared.updateMonitoredRegions(
                    forWearer: account.memberId,
                    hubs: HubStore.shared.hubs
                )
            }
            .store(in: &cancellables)
    }
}
