import SwiftUI
import CoreLocation

/// Vertical list of destinations. Includes both fixed Hubs and live
/// guardians (the "moving pin"). Tapping a hub navigates to Glance with
/// that hub as the target; tapping a guardian navigates to Glance with
/// that guardian as the target. A "Quick reply" row at the bottom lets
/// the wearer compose a short message to a guardian without leaving the
/// watch — covers the wearer's two main jobs ("map and contact/respond
/// to guardian") right from the launcher.
struct HubsListVariant: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var hubStore: HubStore
    @EnvironmentObject var familyStore: FamilyStore
    @EnvironmentObject var presenceStore: PresenceStore
    @EnvironmentObject var locationManager: LocationManager

    private var availableHubs: [Hub] {
        hubStore.hubs(forWearers: [familyStore.account.memberId])
    }
    private var sharingGuardians: [Member] {
        familyStore.watcherMembers.filter {
            presenceStore.guardiansSharing.contains($0.id)
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("Where to?")
                .font(theme.typography.font(.handTight, size: 12, weight: .bold))
                .foregroundColor(theme.palette.watchForeground)
                .padding(.top, 2)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(availableHubs.prefix(4)) { hub in
                        NavigationLink(value: WatchRoute.glanceToHub(hub.id)) {
                            HubRow(
                                icon: hub.icon,
                                name: hub.name,
                                distance: distanceLabel(to: hub.coordinate),
                                color: hub.color,
                                isLive: false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(sharingGuardians) { guardian in
                        NavigationLink(value: WatchRoute.glanceToGuardian(guardian.id)) {
                            HubRow(
                                icon: guardian.initial,
                                name: guardian.displayName,
                                distance: distanceLabel(to: presenceStore.reading(for: guardian.id)?.coordinate),
                                color: guardian.accentColor,
                                isLive: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    NavigationLink(value: WatchRoute.quickReply) {
                        HubRow(
                            icon: "✉",
                            name: "Quick reply",
                            distance: "",
                            color: theme.palette.haloBlue,
                            isLive: false
                        )
                    }
                    .buttonStyle(.plain)
                    NavigationLink(value: WatchRoute.wander) {
                        HubRow(
                            icon: "✦",
                            name: "Just wandering",
                            distance: "",
                            color: Color(hex: 0x6A8DB3),
                            isLive: false
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }
        }
        .locationAware()
    }

    private func distanceLabel(to coord: CLLocationCoordinate2D?) -> String {
        guard let coord, let loc = locationManager.current else { return "—" }
        let target = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let m = loc.distance(from: target)
        if m < 1000 { return "\(Int(m))m" }
        let km = m / 1000.0
        return String(format: km < 10 ? "%.1fkm" : "%.0fkm", km)
    }
}

private struct HubRow: View {
    @Environment(\.theme) var theme
    let icon: String
    let name: String
    let distance: String
    let color: Color
    let isLive: Bool

    var body: some View {
        HStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(color)
                    RoundedRectangle(cornerRadius: 6).stroke(theme.palette.watchSurfaceBorder, lineWidth: 1)
                    HubIconView(icon: icon, size: 12, color: .white)
                }
                .frame(width: 22, height: 22)
                if isLive {
                    Circle()
                        .fill(theme.palette.haloGreen)
                        .frame(width: 6, height: 6)
                        .overlay(Circle().stroke(theme.palette.watchSurface, lineWidth: 1))
                        .offset(x: 3, y: -3)
                }
            }
            Text(name)
                .font(theme.typography.font(.handTight, size: 11, weight: .bold))
                .foregroundColor(theme.palette.watchForeground)
                .lineLimit(1)
            Spacer()
            if !distance.isEmpty {
                Text(distance)
                    .font(theme.typography.font(.handFlow, size: 11))
                    .foregroundColor(theme.palette.watchMuted)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8).fill(theme.palette.watchSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(theme.palette.watchSurfaceBorder, lineWidth: 1)
        )
    }
}
