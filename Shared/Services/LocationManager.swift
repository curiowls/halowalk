import Foundation
import CoreLocation
import Combine

/// Wraps CLLocationManager with a tiered API. Callers don't fiddle with
/// `desiredAccuracy` / `distanceFilter` / `startUpdatingLocation` directly
/// — they ask the `LocationFidelityCoordinator` for a tier, and the
/// Coordinator calls `applyFidelity(_:profile:)` here.
///
/// Build 23 changes vs. the old continuous-only setup:
///  • Added an always-on backbone of region monitoring + visit monitoring
///    + significant location changes (the latter optional per profile).
///    These three survive app termination and cost almost no battery.
///  • Continuous high-frequency updates only run when a foreground tier
///    is requested.
///  • `pausesLocationUpdatesAutomatically` is now ON. Previously OFF —
///    that single line probably accounted for a lot of yesterday's drain.
@MainActor
final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    @Published var current: CLLocation?
    @Published var authorization: CLAuthorizationStatus = .notDetermined
    @Published var lastError: String?

    /// Set of hub ids the wearer is currently inside of. Computed from
    /// region callbacks (iOS) or manual containment checks (watchOS).
    @Published var insideHubIds: Set<UUID> = []

    /// Currently-running tier. Set via `applyFidelity`.
    @Published private(set) var fidelity: LocationFidelity = .off

    private let manager = CLLocationManager()

    private var monitoredHubIds: Set<UUID> = []
    private var continuousRunning = false
    private var slcRunning = false
    private var visitsRunning = false

    override init() {
        super.init()
        manager.delegate = self
        // Default to coarsest knobs; the coordinator will dial up as needed.
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 500
        manager.activityType = .otherNavigation
        #if os(iOS)
        manager.pausesLocationUpdatesAutomatically = true
        manager.allowsBackgroundLocationUpdates = false
        #endif
        authorization = manager.authorizationStatus
    }

    // MARK: - Permission

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    func requestAlwaysPermission() {
        #if os(iOS)
        manager.requestAlwaysAuthorization()
        #endif
    }

    // MARK: - Tiered API

    /// Apply the tier requested by the coordinator. Idempotent — safe to
    /// call repeatedly with the same value.
    func applyFidelity(_ desired: LocationFidelity, profile: MonitoringProfile) {
        // Make sure permission is requested at least once. The user
        // can also kick it from Privacy & Permissions.
        if authorization == .notDetermined {
            requestPermission()
        }
        guard authorization != .denied, authorization != .restricted else {
            self.fidelity = .off
            stopContinuous()
            stopBackbone()
            return
        }

        // Continuous updates: only when the tier needs them.
        if desired.needsContinuousUpdates {
            applyContinuousConfig(for: desired)
            startContinuousIfNeeded()
        } else {
            stopContinuous()
        }

        // Background backbone: always on whenever we're not fully off.
        if desired.needsBackgroundBackbone {
            startBackboneIfNeeded(profile: profile)
        } else {
            stopBackbone()
        }

        self.fidelity = desired
    }

    // MARK: - Continuous configuration

    private func applyContinuousConfig(for tier: LocationFidelity) {
        let config = tier.coreLocationConfig
        manager.desiredAccuracy = config.accuracy
        manager.distanceFilter = config.distanceFilter
        manager.activityType = config.activityType
        #if os(iOS)
        // pausesLocationUpdatesAutomatically is iOS-only — Apple Watch
        // doesn't expose it (the watch hardware handles pausing itself).
        manager.pausesLocationUpdatesAutomatically = config.pausesAutomatically
        #endif
    }
    private func startContinuousIfNeeded() {
        guard !continuousRunning else { return }
        manager.startUpdatingLocation()
        continuousRunning = true
        #if os(iOS)
        if authorization == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
        }
        #endif
    }
    private func stopContinuous() {
        guard continuousRunning else { return }
        manager.stopUpdatingLocation()
        continuousRunning = false
        #if os(iOS)
        manager.allowsBackgroundLocationUpdates = false
        #endif
    }

    // MARK: - Background backbone (visits + SLC + region monitoring)

    private func startBackboneIfNeeded(profile: MonitoringProfile) {
        #if os(iOS)
        if !visitsRunning {
            manager.startMonitoringVisits()
            visitsRunning = true
        }
        if profile.includesSignificantLocationChanges, !slcRunning {
            manager.startMonitoringSignificantLocationChanges()
            slcRunning = true
        } else if !profile.includesSignificantLocationChanges, slcRunning {
            manager.stopMonitoringSignificantLocationChanges()
            slcRunning = false
        }
        #endif
        // Region monitoring is updated on demand via updateMonitoredRegions
        // (called from MonitoringCoordinator when HubStore changes).
    }
    private func stopBackbone() {
        #if os(iOS)
        if visitsRunning {
            manager.stopMonitoringVisits()
            visitsRunning = false
        }
        if slcRunning {
            manager.stopMonitoringSignificantLocationChanges()
            slcRunning = false
        }
        #endif
    }

    // MARK: - Region monitoring (iOS)

    func updateMonitoredRegions(forWearer wearerId: UUID, hubs: [Hub]) {
        let relevant = hubs.filter {
            $0.assignedMemberIds.isEmpty || $0.assignedMemberIds.contains(wearerId)
        }
        let nextIds = Set(relevant.map(\.id))

        #if os(iOS)
        for hubId in monitoredHubIds where !nextIds.contains(hubId) {
            for region in manager.monitoredRegions where region.identifier == hubId.uuidString {
                manager.stopMonitoring(for: region)
            }
        }
        for hub in relevant where !monitoredHubIds.contains(hub.id) {
            let region = CLCircularRegion(
                center: hub.coordinate,
                radius: hub.haloRadiusMeters,
                identifier: hub.id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = true
            manager.startMonitoring(for: region)
        }
        #endif
        monitoredHubIds = nextIds
    }

    // MARK: - Manual containment fallback (watchOS + iOS belt-and-braces)

    private func recomputeContainment(against location: CLLocation, hubs: [Hub]) {
        var nextInside = Set<UUID>()
        for hub in hubs where monitoredHubIds.contains(hub.id) {
            let target = CLLocation(latitude: hub.latitude, longitude: hub.longitude)
            if location.distance(from: target) <= hub.haloRadiusMeters {
                nextInside.insert(hub.id)
            }
        }
        let entered = nextInside.subtracting(insideHubIds)
        let exited = insideHubIds.subtracting(nextInside)
        insideHubIds = nextInside
        for id in entered { TriggerEngine.shared.didEnter(hubId: id) }
        for id in exited { TriggerEngine.shared.didExit(hubId: id) }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let last = locations.last else { return }
        Task { @MainActor in
            self.current = last
            self.recomputeContainment(against: last, hubs: HubStore.shared.hubs)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            // Re-apply current fidelity now that authorization is known —
            // this kicks the manager out of the no-op state if permission
            // was just granted.
            let p = MonitoringPrefs.shared.profile
            self.applyFidelity(self.fidelity == .off ? .background : self.fidelity, profile: p)
        }
    }

    #if os(iOS)
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let uuid = UUID(uuidString: region.identifier) else { return }
        Task { @MainActor in
            self.insideHubIds.insert(uuid)
            TriggerEngine.shared.didEnter(hubId: uuid)
            // Resolve any "until arrives at this hub" continuous-watches.
            let resolved = ContinuousWatchStore.shared.tick(recentlyEnteredHubId: uuid)
            self.notifyResolved(resolved, reason: .arrivedAtHub(uuid))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let uuid = UUID(uuidString: region.identifier) else { return }
        Task { @MainActor in
            self.insideHubIds.remove(uuid)
            TriggerEngine.shared.didExit(hubId: uuid)
            let resolved = ContinuousWatchStore.shared.tick(recentlyExitedHubId: uuid)
            self.notifyResolved(resolved, reason: .leftHub(uuid))
        }
    }

    /// Visit monitoring callback. Apple's most battery-efficient location
    /// signal — fires on user "arrived" / "departed" events with a built-in
    /// dwell threshold. Ingest as a fresh PresenceStore reading so the
    /// family map shows "they got somewhere" without us running continuous
    /// updates.
    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        Task { @MainActor in
            let coord = visit.coordinate
            // A CLLocation with a synthetic horizontalAccuracy — visit
            // coords are typically accurate to ~50m.
            let location = CLLocation(
                coordinate: coord,
                altitude: 0,
                horizontalAccuracy: 50,
                verticalAccuracy: -1,
                timestamp: visit.departureDate.timeIntervalSince1970 > 0
                    ? visit.departureDate
                    : visit.arrivalDate
            )
            self.current = location
            self.recomputeContainment(against: location, hubs: HubStore.shared.hubs)
        }
    }
    #endif

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.lastError = error.localizedDescription
        }
    }
}

// MARK: - Continuous-watch resolution notifications

extension LocationManager {
    private enum ResolveReason {
        case arrivedAtHub(UUID)
        case leftHub(UUID)
    }
    private func notifyResolved(_ resolved: [ContinuousWatch], reason: ResolveReason) {
        #if os(iOS)
        guard !resolved.isEmpty else { return }
        for watch in resolved {
            let watchedName = FamilyStore.shared.member(watch.watchedId)?.displayName ?? "they"
            let title: String
            switch reason {
            case .arrivedAtHub(let hubId):
                let hubName = HubStore.shared.hubs.first(where: { $0.id == hubId })?.name ?? "their hub"
                title = "\(watchedName) arrived at \(hubName)"
            case .leftHub(let hubId):
                let hubName = HubStore.shared.hubs.first(where: { $0.id == hubId })?.name ?? "their hub"
                title = "\(watchedName) left \(hubName)"
            }
            let n = AppNotification(
                id: UUID(),
                severity: .quiet,
                category: .wearerResponded,
                title: title,
                body: "Your watch ended.",
                timestamp: Date(),
                aboutMemberId: watch.watchedId,
                triggeredByTriggerId: nil,
                suggestedRespond: nil,
                read: false,
                dismissed: false
            )
            NotificationStore.shared.add(n)
            NotificationDelivery.shared.deliver(n)
        }
        #endif
    }
}

extension CLLocation {
    func distanceMiles(to coord: CLLocationCoordinate2D) -> Double {
        let target = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        return self.distance(from: target) / 1609.344
    }
}
