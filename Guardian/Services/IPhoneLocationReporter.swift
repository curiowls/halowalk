import Foundation
import CoreLocation
import Combine
import UIKit

/// Throttled forwarder of CLLocation updates → PresenceStore. The watch
/// has its own equivalent (WatchLocationReporter); this is the iPhone
/// side. Without this, the iPhone's blue "using your location" indicator
/// fires but nothing in HaloWalk's own UI ever moves Chelsea's pin.
///
/// Throttle: send no more than once every ~30s, OR every ~25m of
/// movement, whichever comes first. Tighter than the watch reporter
/// because the iPhone has more battery headroom and the wearer expects
/// "the pin moves with me."
@MainActor
final class IPhoneLocationReporter {
    static let shared = IPhoneLocationReporter()

    private var cancellables = Set<AnyCancellable>()
    private var lastSentAt: Date = .distantPast
    private var lastSentCoordinate: CLLocationCoordinate2D?
    private let minInterval: TimeInterval = 30
    private let minMovementMeters: Double = 25

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
            HaloCloudSync.shared.deleteLocationReadings(for: memberId)
            return
        }
        let reading = LocationReading(
            memberId: memberId,
            deviceId: localPhoneDeviceId(forMemberId: memberId),
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracy: location.horizontalAccuracy,
            timestamp: now,
            inHubId: nil,
            state: .unknown,
            batteryPercent: batteryPercent(),
            isOnWrist: nil,
            isMoving: moved > 5
        )
        PresenceStore.shared.ingest(reading)
    }

    /// Pick the iPhone device record we should attribute readings to.
    /// Prefer the seed iPhone if it belongs to the local account; otherwise
    /// fall back to the WatchSync local-device id (still stable across
    /// launches via UserDefaults).
    private func localPhoneDeviceId(forMemberId memberId: UUID) -> UUID {
        let phone = FamilyStore.shared.devices.first { d in
            d.memberId == memberId && d.kind == .iPhone
        }
        return phone?.id ?? WatchSync.localDeviceId
    }

    private func batteryPercent() -> Int? {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        guard level >= 0 else { return nil }
        return Int(round(level * 100))
    }
}
