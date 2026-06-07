import SwiftUI
import CoreLocation

/// Minimalist arrow + distance. Theme-driven appearance — "Modern" gets
/// hi-contrast inverted, "Playful" gets pink-on-paper, "Artisan" gets
/// the neutral green-on-paper look. The destination is whichever hub or
/// guardian was tapped to enter Glance; falls back to the nearest hub.
struct GlanceArrowVariant: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var hubStore: HubStore
    @EnvironmentObject var familyStore: FamilyStore
    @EnvironmentObject var presenceStore: PresenceStore

    let targetHubId: UUID?
    let targetGuardianId: UUID?

    init(targetHubId: UUID? = nil, targetGuardianId: UUID? = nil) {
        self.targetHubId = targetHubId
        self.targetGuardianId = targetGuardianId
    }

    private var themeId: String { familyStore.me?.preferredThemeId ?? "artisan" }
    private var isModern: Bool { themeId == "modern" }
    private var isPlayful: Bool { themeId == "playful" }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            VStack(spacing: 4) {
                Text(targetName)
                    .font(theme.typography.font(.handTight, size: isModern ? 18 : 14, weight: .bold))
                    .foregroundColor(textColor)
                    .padding(.top, 4)
                    .lineLimit(1)
                Spacer()
                ArrowGlyph(size: arrowSize, direction: bearingDegrees, color: arrowColor)
                Spacer()
                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(distanceText.value)
                            .font(theme.typography.font(.handTight, size: isModern ? 36 : 28, weight: .bold))
                        Text(" \(distanceText.unit)")
                            .font(theme.typography.font(.handTight, size: 13))
                    }
                    .foregroundColor(arrowColor)
                    Text(stateText)
                        .font(theme.typography.font(.handTight, size: 9))
                        .foregroundColor(textColor.opacity(0.85))
                }
                .padding(.bottom, 6)
            }
            .padding(.horizontal, 6)
        }
        // Arrow + bearing needs the highest precision tier — wearer is
        // walking and watching the arrow.
        .locationAware(.foregroundFine)
    }

    // MARK: - Theme-aware colors. Always darken the BG and lighten the FG
    // so the wearer's view stays readable on OLED watch screens.

    private var backgroundColor: Color {
        if isModern { return theme.palette.watchBackground }
        // Even on Artisan / Playful, the watch wants a dark background;
        // the iPhone palette's "paper" is too bright on a watch face.
        return theme.palette.watchBackground
    }
    private var textColor: Color {
        theme.palette.watchForeground
    }
    private var arrowColor: Color {
        if isModern { return theme.palette.haloYellow }
        if isPlayful { return theme.palette.haloPink }
        return theme.palette.haloGreen
    }
    private var arrowSize: CGFloat { isModern ? 100 : 76 }

    // MARK: - Resolved destination

    private struct Target {
        let coordinate: CLLocationCoordinate2D
        let name: String
        let radius: CLLocationDistance
    }

    private var resolvedTarget: Target? {
        if let id = targetHubId, let h = hubStore.hubs.first(where: { $0.id == id }) {
            return Target(coordinate: h.coordinate, name: h.name, radius: h.haloRadiusMeters)
        }
        if let id = targetGuardianId,
           let m = familyStore.member(id),
           let r = presenceStore.reading(for: id) {
            return Target(coordinate: r.coordinate, name: m.displayName, radius: 50)
        }
        if let loc = locationManager.current,
           let n = hubStore.nearestHub(to: loc, forMember: familyStore.account.memberId) {
            return Target(coordinate: n.hub.coordinate, name: n.hub.name, radius: n.hub.haloRadiusMeters)
        }
        return nil
    }

    private var targetName: String {
        resolvedTarget?.name.uppercased() ?? "—"
    }
    private var distanceText: (value: String, unit: String) {
        guard let t = resolvedTarget, let loc = locationManager.current else { return ("–", "") }
        let m = loc.distance(from: CLLocation(latitude: t.coordinate.latitude, longitude: t.coordinate.longitude))
        if m < 1000 {
            return ("\(Int(m))", "m")
        }
        let km = m / 1000.0
        return (String(format: km < 10 ? "%.1f" : "%.0f", km), "km")
    }
    private var stateText: String {
        guard let loc = locationManager.current, let t = resolvedTarget else { return "WAITING FOR GPS" }
        let inHalo = loc.distance(from: CLLocation(latitude: t.coordinate.latitude, longitude: t.coordinate.longitude)) <= t.radius
        return inHalo ? "IN HALO ♡" : "HEAD THIS WAY"
    }
    private var bearingDegrees: Double {
        guard let loc = locationManager.current, let t = resolvedTarget else { return 0 }
        let lat1 = loc.coordinate.latitude * .pi / 180
        let lat2 = t.coordinate.latitude * .pi / 180
        let dLon = (t.coordinate.longitude - loc.coordinate.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
}
