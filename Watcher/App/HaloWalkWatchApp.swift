import SwiftUI
import Combine
import CoreLocation

@main
struct HaloWalkWatchApp: App {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var familyStore = FamilyStore.shared
    @StateObject private var hubStore = HubStore.shared
    @StateObject private var notificationStore = NotificationStore.shared
    @StateObject private var triggerStore = TriggerStore.shared
    @StateObject private var presenceStore = PresenceStore.shared
    @StateObject private var watchSync = WatchSync.shared

    var body: some Scene {
        WindowGroup {
            WatchRoot()
                .environmentObject(themeManager)
                .environmentObject(locationManager)
                .environmentObject(familyStore)
                .environmentObject(hubStore)
                .environmentObject(notificationStore)
                .environmentObject(triggerStore)
                .environmentObject(presenceStore)
                .environmentObject(watchSync)
                .environment(\.theme, themeManager.theme)
                .task {
                    // Build 23: tier-driven location services on the watch
                    // side too. Coordinator picks the right tier based on
                    // foregrounded screens + monitoring profile + remote
                    // boosts received from the paired iPhone.
                    LocationFidelityCoordinator.shared.start()
                    WatchSync.shared.activate()
                    WatchLocationReporter.shared.start()
                }
        }
    }
}

/// Throttled forwarder of CLLocation updates → WatchSync. Sends one
/// reading per ~60 seconds (or every ~50m of movement, whichever first).
@MainActor
final class WatchLocationReporter {
    static let shared = WatchLocationReporter()

    private var cancellables = Set<AnyCancellable>()
    private var lastSentAt: Date = .distantPast
    private var lastSentCoordinate: CLLocationCoordinate2D?
    private let minInterval: TimeInterval = 60
    private let minMovementMeters: Double = 50

    private init() {}

    func start() {
        LocationManager.shared.$current
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.consider(location)
            }
            .store(in: &cancellables)
    }

    private func consider(_ location: CLLocation) {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastSentAt)
        let moved: Double = {
            guard let last = lastSentCoordinate else { return .infinity }
            return location.distance(from: CLLocation(
                latitude: last.latitude, longitude: last.longitude
            ))
        }()
        guard elapsed >= minInterval || moved >= minMovementMeters else { return }
        lastSentAt = now
        lastSentCoordinate = location.coordinate

        let memberId = FamilyStore.shared.account.memberId
        guard FamilyStore.shared.member(memberId)?.sharesLocation != false else {
            PresenceStore.shared.removeReadings(for: memberId)
            return
        }
        let reading = LocationReading(
            memberId: memberId,
            deviceId: WatchSync.localDeviceId,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracy: location.horizontalAccuracy,
            timestamp: now,
            inHubId: nil,
            state: .unknown,
            batteryPercent: nil,
            isOnWrist: true,    // we're on the wrist if location is updating
            isMoving: moved > 5
        )
        // Ingest locally too so the watch's own UI updates immediately.
        PresenceStore.shared.ingest(reading)
        WatchSync.shared.sendLocationReading(reading)
    }
}
