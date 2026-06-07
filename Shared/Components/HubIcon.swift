import SwiftUI
import MapKit

/// Default icon set for hubs. Each option pairs an SF Symbol with a
/// pre-assigned color — the user picks an icon and the color comes along
/// for the ride, so there's only one decision to make instead of two.
enum HubIconCatalog {
    struct Option: Identifiable, Hashable {
        let id: String          // SF Symbol name
        let label: String
        let colorHex: UInt32
        var systemName: String { id }
        var color: Color { Color(hex: colorHex) }
    }

    static let defaults: [Option] = [
        Option(id: "house.fill",            label: "Home",     colorHex: 0x5A9D6E),
        Option(id: "graduationcap.fill",    label: "School",   colorHex: 0x6A8DB3),
        Option(id: "books.vertical.fill",   label: "Library",  colorHex: 0xD99FB1),
        Option(id: "cart.fill",             label: "Grocery",  colorHex: 0xE8B94A),
        Option(id: "leaf.fill",             label: "Park",     colorHex: 0x4F8C5A),
        Option(id: "figure.run",            label: "Sports",   colorHex: 0xD56A5C),
        Option(id: "cup.and.saucer.fill",   label: "Café",     colorHex: 0xA67C52),
        Option(id: "cross.case.fill",       label: "Medical",  colorHex: 0xC44A5A),
        Option(id: "music.note.house.fill", label: "Activity", colorHex: 0xB47CD0),
        Option(id: "heart.fill",            label: "Family",   colorHex: 0xD99FB1),
        Option(id: "building.2.fill",       label: "Building", colorHex: 0x6A8DB3),
        Option(id: "mappin.and.ellipse",    label: "Other",    colorHex: 0x7A756E),
    ]

    /// Default fallback when nothing else fits.
    static let fallback: Option = defaults.last!

    /// Lookup by SF Symbol name, falling back to "Other".
    static func option(for systemName: String) -> Option {
        defaults.first { $0.id == systemName } ?? fallback
    }

    /// Map an Apple POI category from MKLocalSearch / MKMapItem to the
    /// best-fit hub icon. Used to pre-fill the icon when a user picks a
    /// search result, so they rarely have to change it.
    static func option(forPOI category: MKPointOfInterestCategory?) -> Option {
        // Only the category constants stable across iOS 17+ / watchOS 10+ —
        // newer ones (.tennis, .baseball, etc.) require iOS 18 / watchOS 11.
        guard let category else { return fallback }
        switch category {
        case .school, .university:
            return option(for: "graduationcap.fill")
        case .library:
            return option(for: "books.vertical.fill")
        case .foodMarket:
            return option(for: "cart.fill")
        case .park:
            return option(for: "leaf.fill")
        case .stadium, .fitnessCenter:
            return option(for: "figure.run")
        case .cafe, .restaurant, .bakery, .brewery, .winery:
            return option(for: "cup.and.saucer.fill")
        case .hospital, .pharmacy:
            return option(for: "cross.case.fill")
        case .theater, .museum, .nightlife, .movieTheater:
            return option(for: "music.note.house.fill")
        case .publicTransport, .postOffice, .fireStation, .police:
            return option(for: "building.2.fill")
        default:
            return fallback
        }
    }
}

/// Renders a hub's icon. Accepts both SF Symbol names (preferred) and
/// short text glyphs (legacy data).
struct HubIconView: View {
    let icon: String
    var size: CGFloat = 16
    var color: Color = .white

    var body: some View {
        if isSymbolName(icon) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(color)
        } else {
            Text(icon)
                .font(.system(size: size, weight: .bold))
                .foregroundColor(color)
        }
    }

    private func isSymbolName(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        if s.count <= 2 { return false }
        return s.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" }
    }
}
