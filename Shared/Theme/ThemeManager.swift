import SwiftUI
import Combine

/// Owns the active theme + per-screen variant preferences. Inject as
/// `.environmentObject(ThemeManager.shared)` at the app root.
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var theme: Theme {
        didSet {
            UserDefaults.standard.set(theme.id, forKey: Self.themeKey)
        }
    }

    @Published var variantPrefs: VariantPrefs {
        didSet {
            if let data = try? JSONEncoder().encode(variantPrefs) {
                UserDefaults.standard.set(data, forKey: Self.variantKey)
            }
        }
    }

    private static let themeKey = "halowalk.theme.id"
    private static let variantKey = "halowalk.variant.prefs"

    init() {
        let savedId = UserDefaults.standard.string(forKey: Self.themeKey) ?? Theme.artisan.id
        self.theme = Theme.allRegistered.first { $0.id == savedId } ?? .artisan

        if let data = UserDefaults.standard.data(forKey: Self.variantKey),
           let prefs = try? JSONDecoder().decode(VariantPrefs.self, from: data) {
            self.variantPrefs = prefs
        } else {
            self.variantPrefs = VariantPrefs()
        }
    }

    func setTheme(_ id: String) {
        if let next = Theme.allRegistered.first(where: { $0.id == id }) {
            theme = next
        }
    }
}

/// Which variant the user prefers for each multi-variant screen. The pilot ships
/// all three for every screen — this remembers the last one they swiped to so
/// the app boots into their preferred surface.
struct VariantPrefs: Codable, Equatable {
    var glance: Int = 0       // 0=turn-by-turn, 1=hi-contrast, 2=friendly
    var hubs: Int = 0         // 0=list, 1=petals, 2=suggested
    var wander: Int = 0       // 0=enlarge halo, 1=three choices, 2=countdown

    var hubCreator: Int = 0   // 0=map, 1=list, 2=constellation
    var statusBoard: Int = 0
    var triggers: Int = 0
    var notifications: Int = 0
    var respond: Int = 0
}

/// Convenience: read the active theme from any view.
struct ThemeKey: EnvironmentKey {
    static var defaultValue: Theme = .artisan
}
extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
