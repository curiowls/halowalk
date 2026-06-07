import Foundation

/// Per-device user choice for "how aggressively should HaloWalk track me?"
/// Battery numbers are estimates based on Apple's energy guide and
/// observed comparable apps (Life360 self-reports ~10%/day with always-on).
enum MonitoringProfile: String, CaseIterable, Codable, Identifiable {
    /// Visits + regions only. No SLC. Continuous only when a location
    /// screen is foregrounded, then capped at coarse. Best for "set & forget".
    case minimal
    /// Visits + SLC + regions. Coarse continuous on map screens.
    /// The default — good fresh-pin UX without burn.
    case smart
    /// Continuous coarse always (background too); fine when on map screens.
    /// "Find My / Life360" style.
    case live

    var id: String { rawValue }

    var label: String {
        switch self {
        case .minimal: return "Minimal"
        case .smart:   return "Smart"
        case .live:    return "Live"
        }
    }

    var headline: String {
        switch self {
        case .minimal: return "Updates only when you arrive or leave a saved place."
        case .smart:   return "Updates every few minutes in the background, live when you're on the map. Recommended for most families."
        case .live:    return "Always tracking, like Find My. Best for peace of mind during active travel."
        }
    }

    /// Honest, range-based daily-drain estimate, surfaced verbatim in the UI.
    /// "Actual battery use varies with how often you're on the move."
    var batteryEstimate: String {
        switch self {
        case .minimal: return "~1% per day"
        case .smart:   return "~2–4% per day"
        case .live:    return "~8–12% per day"
        }
    }

    /// What this profile sets the *floor* fidelity to when no boosts /
    /// continuous-watches / foreground screens are active.
    var backgroundFidelity: LocationFidelity {
        switch self {
        case .minimal: return .background   // visits + regions only (LocationManager
                                            //   skips SLC for this profile)
        case .smart:   return .background   // visits + SLC + regions
        case .live:    return .foregroundCoarse  // continuous, even backgrounded
        }
    }

    /// Foreground tier when a location-aware screen is up.
    var foregroundFidelity: LocationFidelity {
        switch self {
        case .minimal, .smart: return .foregroundCoarse
        case .live:            return .foregroundFine
        }
    }

    /// True if SLC should be wired in when running the background backbone.
    /// Minimal skips SLC to save the modest extra drain — visits + regions
    /// still cover the "they got somewhere" signals.
    var includesSignificantLocationChanges: Bool {
        switch self {
        case .minimal: return false
        case .smart, .live: return true
        }
    }
}
