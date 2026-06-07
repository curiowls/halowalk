import Foundation
import CoreLocation

/// The four tiers of location-services fidelity HaloWalk runs at. The
/// `LocationFidelityCoordinator` picks one of these tiers each time its
/// inputs change (foreground screen, active continuous-watches, quiet
/// hours, monitoring profile). The `LocationManager` knows how to map a
/// tier into the corresponding CLLocationManager configuration.
enum LocationFidelity: Int, Comparable, Codable {
    /// Nothing is running. App not signed in / location denied.
    case off
    /// Visits + significant location changes + region monitoring.
    /// Near-zero battery cost; survives app termination.
    case background
    /// Continuous updates, ~100 m accuracy, 50 m distance filter,
    /// pauses-when-stationary on. Used when a location-aware screen
    /// is foregrounded.
    case foregroundCoarse
    /// Continuous updates, ~10 m accuracy, 10 m distance filter.
    /// Used when the wearer is actively navigating (watch Glance) or
    /// the user explicitly chose Live profile.
    case foregroundFine

    static func < (lhs: LocationFidelity, rhs: LocationFidelity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// CL configuration baked from the tier. Kept here so all callers
    /// agree on what each tier means.
    var coreLocationConfig: (accuracy: CLLocationAccuracy, distanceFilter: CLLocationDistance, pausesAutomatically: Bool, activityType: CLActivityType) {
        switch self {
        case .off, .background:
            // The CL knobs don't matter when continuous updates aren't
            // running; pick conservative defaults.
            return (kCLLocationAccuracyKilometer, 500, true, .otherNavigation)
        case .foregroundCoarse:
            return (kCLLocationAccuracyHundredMeters, 50, true, .otherNavigation)
        case .foregroundFine:
            return (kCLLocationAccuracyNearestTenMeters, 10, true, .otherNavigation)
        }
    }

    /// True if this tier requires `startUpdatingLocation` to be running.
    var needsContinuousUpdates: Bool {
        switch self {
        case .off, .background: return false
        case .foregroundCoarse, .foregroundFine: return true
        }
    }

    /// True if this tier needs the always-on event-driven backbone
    /// (visits + SLC + regions). Background and above use it; off is off.
    var needsBackgroundBackbone: Bool {
        self != .off
    }
}
