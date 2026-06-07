import SwiftUI
import CoreLocation

/// Spatial "petals" view — destinations arranged around the wearer.
/// Reads from the real Hub store and includes live guardians as moving pins.
/// Tapping a petal launches Glance pointed at that specific destination.
struct HubsPetalsVariant: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var hubStore: HubStore
    @EnvironmentObject var familyStore: FamilyStore
    @EnvironmentObject var presenceStore: PresenceStore

    fileprivate struct Petal: Identifiable {
        let id = UUID()
        let icon: String
        let name: String
        let color: Color
        let isLive: Bool
        let route: WatchRoute
    }

    private var petals: [Petal] {
        var result: [Petal] = []
        let availableHubs = hubStore.hubs(forWearers: [familyStore.account.memberId])
        for hub in availableHubs.prefix(4) {
            result.append(Petal(
                icon: hub.icon, name: hub.name, color: hub.color,
                isLive: false, route: .glanceToHub(hub.id)
            ))
        }
        if let guardian = familyStore.watcherMembers.first(where: {
            presenceStore.guardiansSharing.contains($0.id)
        }) {
            result.append(Petal(
                icon: guardian.initial, name: guardian.displayName,
                color: guardian.accentColor, isLive: true, route: .glanceToGuardian(guardian.id)
            ))
        }
        return result
    }

    /// Hand-placed coordinates around the watch face center.
    private let positions: [(x: CGFloat, y: CGFloat)] = [
        (0.50, 0.18),
        (0.18, 0.40),
        (0.82, 0.40),
        (0.20, 0.78),
        (0.80, 0.78)
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(petals.enumerated()), id: \.element.id) { i, petal in
                    if i < positions.count {
                        let pos = positions[i]
                        NavigationLink(value: petal.route) {
                            PetalView(petal: petal)
                        }
                        .buttonStyle(.plain)
                        .position(x: geo.size.width * pos.x, y: geo.size.height * pos.y)
                    }
                }
                ZStack {
                    Circle()
                        .stroke(theme.palette.watchSurfaceBorder,
                                style: StrokeStyle(lineWidth: 1.2, dash: [2, 2]))
                        .background(Circle().fill(theme.palette.watchSurface))
                    Text("you")
                        .font(theme.typography.font(.hand, size: 8))
                        .foregroundColor(theme.palette.watchMuted)
                }
                .frame(width: 22, height: 22)
                .position(x: geo.size.width * 0.5, y: geo.size.height * 0.5)
            }
        }
    }
}

private struct PetalView: View {
    @Environment(\.theme) var theme
    fileprivate let petal: HubsPetalsVariant.Petal

    var body: some View {
        VStack(spacing: 1) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle().fill(petal.color)
                    Circle().stroke(theme.palette.watchSurfaceBorder, lineWidth: 1.2)
                    HubIconView(icon: petal.icon, size: 14, color: .white)
                }
                .frame(width: 36, height: 36)
                if petal.isLive {
                    Circle()
                        .fill(theme.palette.haloGreen)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(theme.palette.watchSurface, lineWidth: 1.2))
                        .offset(x: 4, y: -4)
                }
            }
            Text(petal.name)
                .font(theme.typography.font(.hand, size: 8))
                .foregroundColor(theme.palette.watchForeground)
                .lineLimit(1)
        }
    }
}
