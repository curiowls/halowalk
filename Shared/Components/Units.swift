import Foundation

/// Locale-aware distance formatting. Internally we always store meters;
/// this helper formats for display using the device's measurement system.
enum Units {
    /// True for the US, Liberia, Myanmar — places that use feet/miles.
    static var isImperial: Bool {
        Locale.current.measurementSystem == .us
    }

    /// Short radius — used for halo size labels (e.g. "80 m" or "262 ft").
    static func radius(meters: Double) -> String {
        if isImperial {
            let feet = meters * 3.28084
            if feet < 1000 {
                return "\(Int(feet.rounded())) ft"
            }
            let miles = meters / 1609.344
            return String(format: "%.2f mi", miles)
        }
        return "\(Int(meters.rounded())) m"
    }

    /// Long distance — used for "0.30 mi from Home" labels.
    static func distance(meters: Double) -> String {
        if isImperial {
            let miles = meters / 1609.344
            if miles < 0.1 {
                let feet = meters * 3.28084
                return "\(Int(feet.rounded())) ft"
            }
            return String(format: "%.2f mi", miles)
        }
        if meters < 1000 {
            return "\(Int(meters.rounded())) m"
        }
        return String(format: "%.2f km", meters / 1000)
    }

    /// "0.30 mi from Home" — distance preposition included.
    static func distanceFrom(_ meters: Double, hub: String) -> String {
        "\(distance(meters: meters)) from \(hub)"
    }

    /// GPS accuracy badge: "± 8 m" or "± 26 ft".
    static func accuracy(meters: Double) -> String {
        if isImperial {
            let feet = meters * 3.28084
            return "± \(Int(feet.rounded())) ft"
        }
        return String(format: "± %.0f m", meters)
    }
}
