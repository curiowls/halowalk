import SwiftUI
import MapKit
import CoreLocation

/// Turn-by-turn map. Real Apple MapKit on watchOS — the prior fake-map
/// fallback was confusing for wearers ("the map is a mock, not working").
/// The destination is whichever hub or guardian the user tapped to get
/// here; falls back to the nearest assigned hub if no specific target.
struct GlanceTurnByTurnVariant: View {
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

    @State private var camera: MapCameraPosition = .automatic

    enum Destination {
        case hub(Hub)
        case guardian(Member, CLLocationCoordinate2D)

        var coordinate: CLLocationCoordinate2D {
            switch self {
            case .hub(let h): return h.coordinate
            case .guardian(_, let c): return c
            }
        }
        var title: String {
            switch self {
            case .hub(let h): return h.name
            case .guardian(let m, _): return m.displayName
            }
        }
        var color: Color {
            switch self {
            case .hub(let h): return h.color
            case .guardian(let m, _): return m.accentColor
            }
        }
        var icon: String {
            switch self {
            case .hub(let h): return h.icon
            case .guardian(let m, _): return m.initial
            }
        }
        /// Halo radius for a hub; small "you've arrived" radius for a guardian.
        var radius: CLLocationDistance {
            switch self {
            case .hub(let h): return h.haloRadiusMeters
            case .guardian: return 50
            }
        }
    }

    private var destination: Destination? {
        if let id = targetHubId, let h = hubStore.hubs.first(where: { $0.id == id }) {
            return .hub(h)
        }
        if let id = targetGuardianId,
           let m = familyStore.member(id),
           let r = presenceStore.reading(for: id) {
            return .guardian(m, r.coordinate)
        }
        if let loc = locationManager.current,
           let nearest = hubStore.nearestHub(to: loc, forMember: familyStore.account.memberId)?.hub {
            return .hub(nearest)
        }
        return nil
    }

    var body: some View {
        ZStack {
            map.ignoresSafeArea()
            VStack(spacing: 4) {
                topBanner
                Spacer(minLength: 0)
                bottomPill
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .onAppear { recenter() }
        .onChange(of: locationManager.current?.coordinate.latitude) { _, _ in
            // Keep both endpoints framed as the wearer moves.
            recenter()
        }
        // Active turn-by-turn navigation needs 10-m precision.
        .locationAware(.foregroundFine)
    }

    @ViewBuilder
    private var map: some View {
        Map(position: $camera) {
            UserAnnotation()
            if let dest = destination {
                Annotation(dest.title, coordinate: dest.coordinate, anchor: .center) {
                    ZStack {
                        Circle().fill(dest.color)
                        Circle().stroke(Color.white, lineWidth: 1.5)
                        HubIconView(icon: dest.icon, size: 12, color: .white)
                    }
                    .frame(width: 26, height: 26)
                }
                MapCircle(center: dest.coordinate, radius: dest.radius)
                    .foregroundStyle(dest.color.opacity(0.18))
                    .stroke(dest.color, lineWidth: 1.2)
            }
        }
        .mapStyle(.standard(elevation: .flat))
    }

    private var topBanner: some View {
        HStack(spacing: 4) {
            if let dest = destination {
                ZStack {
                    Circle().fill(dest.color)
                    HubIconView(icon: dest.icon, size: 8, color: .white)
                }
                .frame(width: 14, height: 14)
            }
            Text(destination?.title ?? "—")
                .font(theme.typography.font(.handTight, size: 11, weight: .bold))
                .lineLimit(1)
            Spacer(minLength: 2)
            Text(distanceText)
                .font(theme.typography.font(.handTight, size: 11, weight: .bold))
        }
        .foregroundColor(theme.palette.watchForeground)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.palette.watchBackground.opacity(0.88))
        )
    }

    private var bottomPill: some View {
        HStack(spacing: 4) {
            Image(systemName: stateIcon)
                .font(.system(size: 9, weight: .bold))
            Text(stateText)
                .font(theme.typography.font(.handTight, size: 9, weight: .bold))
                .lineLimit(1)
            Spacer(minLength: 2)
            Button { recenter() } label: {
                Image(systemName: "scope")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundColor(theme.palette.watchForeground)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.palette.watchBackground.opacity(0.88))
        )
    }

    private var distanceText: String {
        guard let dest = destination, let loc = locationManager.current else { return "—" }
        let m = loc.distance(from: CLLocation(
            latitude: dest.coordinate.latitude,
            longitude: dest.coordinate.longitude
        ))
        if m < 1000 { return "\(Int(m)) m" }
        let km = m / 1000.0
        return String(format: km < 10 ? "%.1f km" : "%.0f km", km)
    }

    private var stateText: String {
        guard let dest = destination else { return "WAITING" }
        guard let loc = locationManager.current else { return "WAITING FOR GPS" }
        let d = loc.distance(from: CLLocation(
            latitude: dest.coordinate.latitude, longitude: dest.coordinate.longitude
        ))
        if d <= dest.radius { return "IN HALO" }
        return "ON THE WAY"
    }

    private var stateIcon: String {
        guard let dest = destination, let loc = locationManager.current else {
            return "location.slash.fill"
        }
        let d = loc.distance(from: CLLocation(
            latitude: dest.coordinate.latitude, longitude: dest.coordinate.longitude
        ))
        return d <= dest.radius ? "checkmark.circle.fill" : "location.fill"
    }

    private func recenter() {
        guard let dest = destination else { return }
        if let loc = locationManager.current {
            let userCoord = loc.coordinate
            let lat = (userCoord.latitude + dest.coordinate.latitude) / 2
            let lon = (userCoord.longitude + dest.coordinate.longitude) / 2
            let latDelta = max(abs(userCoord.latitude - dest.coordinate.latitude) * 2.5, 0.005)
            let lonDelta = max(abs(userCoord.longitude - dest.coordinate.longitude) * 2.5, 0.005)
            camera = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            ))
        } else {
            camera = .region(MKCoordinateRegion(
                center: dest.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            ))
        }
    }
}
