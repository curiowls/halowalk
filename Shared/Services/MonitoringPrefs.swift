import Foundation
import Combine

/// Per-device monitoring profile preference, persisted to UserDefaults
/// and observable by SwiftUI / the LocationFidelityCoordinator.
@MainActor
final class MonitoringPrefs: ObservableObject {
    static let shared = MonitoringPrefs()

    @Published var profile: MonitoringProfile {
        didSet { save() }
    }

    private static let key = "halowalk.monitoring.profile.v1"

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.key),
           let p = MonitoringProfile(rawValue: raw) {
            self.profile = p
        } else {
            // Default new + existing-but-unset installs to Smart, per the
            // Build 23 plan. No migration banner — wearers are monitored
            // by definition; how aggressively isn't a concern to surface.
            self.profile = .smart
        }
    }

    private func save() {
        UserDefaults.standard.set(profile.rawValue, forKey: Self.key)
    }
}
