import SwiftUI
import CoreLocation

/// "Me" tab — wearer-style surfaces on the iPhone. Visible only when the
/// signed-in Member is being watched by someone (i.e. Lou, Maya, or Andrew
/// in the mock data — but for them this only appears if they're the signed-
/// in account on that iPhone).
///
/// Mirrors the watch's three-screen layout vertically:
///   – Halo Glance hero (where am I, where's the nearest hub)
///   – Quick-Tap Hubs list (destinations including guardian moving pins)
///   – "I'm wandering" entry / SOS
struct MeTabView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var familyStore: FamilyStore
    @EnvironmentObject var hubStore: HubStore
    @EnvironmentObject var presenceStore: PresenceStore
    @EnvironmentObject var locationManager: LocationManager

    private var meId: UUID { familyStore.account.memberId }
    private var me: Member? { familyStore.me }

    private var nearest: (hub: Hub, meters: Double)? {
        guard let loc = locationManager.current else { return nil }
        return hubStore.nearestHub(to: loc, forMember: meId)
    }
    private var primaryDestinations: [Destination] {
        var result: [Destination] = []
        let hubs = hubStore.hubs(forMembers: [meId])
        for hub in hubs.prefix(6) {
            result.append(.hub(hub))
        }
        // Guardians who are sharing — moving pins.
        let watchers = familyStore.watchers(of: meId)
        for guardian in watchers where presenceStore.guardiansSharing.contains(guardian.id) {
            result.append(.guardian(guardian))
        }
        return result
    }

    enum Destination: Hashable {
        case hub(Hub)
        case guardian(Member)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MeHeader()
                HaloGlanceHero(nearest: nearest)
                DestinationList(destinations: primaryDestinations,
                                onPick: { _ in /* future: launch turn-by-turn */ })
                WanderingPanel()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.paper.ignoresSafeArea())
    }
}

private struct MeHeader: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var familyStore: FamilyStore
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Hi \(familyStore.me?.displayName ?? "there") ♡")
                .font(theme.typography.font(.handTight, size: 22, weight: .bold))
            Text("here's where you are")
                .font(theme.typography.font(.handFlow, size: 14))
                .foregroundColor(theme.palette.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Big arrow + distance hero. Shows direction to nearest hub or
/// "you're at Home ♡" when in a halo.
private struct HaloGlanceHero: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var locationManager: LocationManager
    let nearest: (hub: Hub, meters: Double)?

    private var insideHalo: Bool {
        guard let loc = locationManager.current, let n = nearest else { return false }
        return loc.distance(from: CLLocation(
            latitude: n.hub.coordinate.latitude,
            longitude: n.hub.coordinate.longitude
        )) <= n.hub.haloRadiusMeters
    }
    private var bearing: Double {
        guard let loc = locationManager.current, let n = nearest else { return 0 }
        let lat1 = loc.coordinate.latitude * .pi / 180
        let lat2 = n.hub.coordinate.latitude * .pi / 180
        let dLon = (n.hub.coordinate.longitude - loc.coordinate.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    var body: some View {
        VStack(spacing: 8) {
            if insideHalo, let n = nearest {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundColor(theme.palette.haloGreen)
                Text("You're at \(n.hub.name) ♡")
                    .font(theme.typography.font(.handTight, size: 22, weight: .bold))
                Text("Safe at base.")
                    .font(theme.typography.font(.handFlow, size: 14))
                    .foregroundColor(theme.palette.ink2)
            } else if let n = nearest {
                ArrowGlyph(size: 100, direction: bearing, color: theme.palette.haloGreen)
                Text(Units.distanceFrom(n.meters, hub: n.hub.name))
                    .font(theme.typography.font(.handTight, size: 18, weight: .bold))
                Text("head this way")
                    .font(theme.typography.font(.handFlow, size: 14))
                    .foregroundColor(theme.palette.ink3)
            } else {
                Image(systemName: "location.slash")
                    .font(.system(size: 56))
                    .foregroundColor(theme.palette.ink3)
                Text("Looking for hubs…")
                    .font(theme.typography.font(.handFlow, size: 14))
                    .foregroundColor(theme.palette.ink3)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .sketchBorder(padding: 0)
    }
}

/// Quick-Tap-Hubs-equivalent list. Hubs first, sharing guardians as live pins.
private struct DestinationList: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var locationManager: LocationManager
    let destinations: [MeTabView.Destination]
    let onPick: (MeTabView.Destination) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Where to?")
                .font(theme.typography.font(.handTight, size: 11))
                .tracking(0.5)
                .foregroundColor(theme.palette.ink3)
            VStack(spacing: 6) {
                ForEach(destinations, id: \.self) { dest in
                    Button { onPick(dest) } label: {
                        DestinationRow(destination: dest)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct DestinationRow: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var presenceStore: PresenceStore
    let destination: MeTabView.Destination

    var body: some View {
        HStack(spacing: 10) {
            iconBadge
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(theme.typography.font(.handTight, size: 14, weight: .bold))
                    .foregroundColor(theme.palette.ink)
                if let sub = sublabel {
                    Text(sub)
                        .font(theme.typography.font(.handFlow, size: 12))
                        .foregroundColor(theme.palette.ink3)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(distanceText)
                .font(theme.typography.font(.handTight, size: 12))
                .foregroundColor(theme.palette.ink2)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.palette.ink3)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .sketchBorder(padding: 0)
    }

    @ViewBuilder
    private var iconBadge: some View {
        switch destination {
        case .hub(let hub):
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(hub.color)
                    RoundedRectangle(cornerRadius: 10).stroke(theme.palette.line, lineWidth: 1.2)
                    HubIconView(icon: hub.icon, size: 16, color: theme.palette.paper)
                }
                .frame(width: 36, height: 36)
            }
        case .guardian(let g):
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle().fill(g.accentColor)
                    Circle().stroke(theme.palette.line, lineWidth: 1.2)
                    Text(g.initial)
                        .font(theme.typography.font(.handTight, size: 14, weight: .bold))
                        .foregroundColor(theme.palette.paper)
                }
                .frame(width: 36, height: 36)
                Circle()
                    .fill(theme.palette.haloGreen)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(theme.palette.paper, lineWidth: 1.2))
                    .offset(x: 4, y: -4)
            }
        }
    }

    private var label: String {
        switch destination {
        case .hub(let hub):    return hub.name
        case .guardian(let g): return g.displayName
        }
    }
    private var sublabel: String? {
        switch destination {
        case .hub(let hub):
            return hub.address.isEmpty ? nil : hub.address
        case .guardian:
            return "live location · tap to head over"
        }
    }
    private var distanceText: String {
        let coord: CLLocationCoordinate2D
        switch destination {
        case .hub(let hub):
            coord = hub.coordinate
        case .guardian(let g):
            guard let r = presenceStore.primaryReading(for: g.id) else { return "—" }
            coord = r.coordinate
        }
        guard let loc = locationManager.current else { return "—" }
        let target = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        return Units.distance(meters: loc.distance(from: target))
    }
}

private struct WanderingPanel: View {
    @Environment(\.theme) var theme
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Just out & about")
                .font(theme.typography.font(.handTight, size: 11))
                .tracking(0.5)
                .foregroundColor(theme.palette.ink3)
            HStack(spacing: 8) {
                Button {} label: {
                    Label("+1 mi halo", systemImage: "circle.dashed")
                        .font(theme.typography.font(.handTight, size: 13, weight: .bold))
                        .foregroundColor(theme.palette.paper)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Capsule().fill(theme.palette.haloGreen))
                }
                .buttonStyle(.plain)
                Button {} label: {
                    Label("Need help", systemImage: "exclamationmark.triangle.fill")
                        .font(theme.typography.font(.handTight, size: 13, weight: .bold))
                        .foregroundColor(theme.palette.paper)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Capsule().fill(theme.palette.haloRed))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
