import SwiftUI
import CoreLocation
import MapKit

/// Hubs tab — list/map toggle, member-filter chip strip, "+ Add Location"
/// CTA. Tap any hub (card or map pin) to open the EditHubSheet.
struct HubsTabView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var familyStore: FamilyStore
    @EnvironmentObject var hubStore: HubStore
    @EnvironmentObject var locationManager: LocationManager

    enum Mode { case list, map }
    @State private var mode: Mode = .list
    @State private var filterMemberId: UUID? = nil
    @State private var showAddSheet = false
    @State private var editingHub: Hub? = nil

    private var visibleHubs: [Hub] {
        guard let mid = filterMemberId else { return hubStore.hubs }
        return hubStore.hubs.filter {
            $0.assignedMemberIds.isEmpty || $0.assignedMemberIds.contains(mid)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HubsHeader(mode: $mode)
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 8)

            FilterChipBar(
                wearers: familyStore.watchedMembers,
                selected: $filterMemberId
            )
            .padding(.bottom, 6)

            ZStack {
                // Both children fill the same frame so the parent layout
                // doesn't shift on toggle.
                if mode == .list {
                    listView
                } else {
                    mapView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.paper.ignoresSafeArea())
        .sheet(isPresented: $showAddSheet) {
            AddHubSheet()
        }
        .sheet(item: $editingHub) { hub in
            EditHubSheet(hub: hub)
        }
        // Hubs map shows static pins — but the current-location pulldown
        // and distance-from-here computations want fresh location too.
        .locationAware()
    }

    @ViewBuilder
    private var listView: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(visibleHubs) { hub in
                    Button { editingHub = hub } label: {
                        HubCard(hub: hub)
                    }
                    .buttonStyle(.plain)
                }
                AddCurrentLocationCard {
                    showAddSheet = true
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }

    @ViewBuilder
    private var mapView: some View {
        Map(initialPosition: .region(initialRegion())) {
            ForEach(visibleHubs) { hub in
                MapCircle(center: hub.coordinate, radius: hub.haloRadiusMeters)
                    .foregroundStyle(hub.color.opacity(0.18))
                    .stroke(hub.color, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                Annotation(hub.name, coordinate: hub.coordinate) {
                    HubPin(hub: hub) { editingHub = hub }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
    }

    private func initialRegion() -> MKCoordinateRegion {
        // Center on the bounding box of visible hubs, or current location, or
        // the user's current location, or fall back to seed region.
        if !visibleHubs.isEmpty {
            let lats = visibleHubs.map(\.latitude)
            let lons = visibleHubs.map(\.longitude)
            let minLat = lats.min() ?? 0, maxLat = lats.max() ?? 0
            let minLon = lons.min() ?? 0, maxLon = lons.max() ?? 0
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            let span = MKCoordinateSpan(
                latitudeDelta: max(0.01, (maxLat - minLat) * 1.4),
                longitudeDelta: max(0.01, (maxLon - minLon) * 1.4)
            )
            return MKCoordinateRegion(center: center, span: span)
        }
        if let loc = locationManager.current {
            return MKCoordinateRegion(
                center: loc.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }
        return MKCoordinateRegion(
            center: MockData.belmontRegion,
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
    }
}

private struct HubsHeader: View {
    @Environment(\.theme) var theme
    @Binding var mode: HubsTabView.Mode
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Hubs")
                    .font(theme.typography.font(.handTight, size: 22, weight: .bold))
                Text("the places that anchor everyone's day")
                    .font(theme.typography.font(.handFlow, size: 14))
                    .foregroundColor(theme.palette.ink3)
            }
            Spacer()
            ListMapToggle(mode: $mode)
        }
    }
}

private struct ListMapToggle: View {
    @Environment(\.theme) var theme
    @Binding var mode: HubsTabView.Mode
    var body: some View {
        HStack(spacing: 0) {
            half(.list, icon: "list.bullet", label: "List")
            half(.map, icon: "map", label: "Map")
        }
        .padding(2)
        .background(Capsule().fill(theme.palette.paper2))
        .overlay(Capsule().stroke(theme.palette.line, lineWidth: 1.2))
    }
    @ViewBuilder
    private func half(_ which: HubsTabView.Mode, icon: String, label: String) -> some View {
        let selected = mode == which
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { mode = which }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(theme.typography.font(.handTight, size: 12, weight: .bold))
            }
            .foregroundColor(selected ? theme.palette.paper : theme.palette.ink2)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(selected ? theme.palette.ink : .clear))
        }
        .buttonStyle(.plain)
    }
}

private struct FilterChipBar: View {
    @Environment(\.theme) var theme
    let wearers: [Member]
    @Binding var selected: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(title: "All", color: theme.palette.ink, isSelected: selected == nil) {
                    selected = nil
                }
                ForEach(wearers) { wearer in
                    chip(title: wearer.displayName, color: wearer.accentColor,
                         isSelected: selected == wearer.id) {
                        selected = wearer.id
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    @ViewBuilder
    private func chip(title: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title).font(theme.typography.font(.handTight, size: 12, weight: .bold))
            }
            .foregroundColor(isSelected ? theme.palette.paper : theme.palette.ink)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(isSelected ? theme.palette.ink : theme.palette.paper2))
            .overlay(Capsule().stroke(theme.palette.line, lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }
}

private struct HubCard: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var familyStore: FamilyStore
    let hub: Hub

    private var assignedNames: String {
        let names = hub.assignedMemberIds.compactMap { familyStore.member($0)?.displayName }
        return names.isEmpty ? "everyone" : names.joined(separator: ", ")
    }
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(hub.color)
                RoundedRectangle(cornerRadius: 12).stroke(theme.palette.line, lineWidth: 1.5)
                HubIconView(icon: hub.icon, size: 20, color: theme.palette.paper)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(hub.name)
                    .font(theme.typography.font(.handTight, size: 14, weight: .bold))
                    .foregroundColor(theme.palette.ink)
                Text(hub.address.isEmpty ? coordinateText : hub.address)
                    .font(theme.typography.font(.handFlow, size: 12))
                    .foregroundColor(theme.palette.ink3)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "scope").font(.system(size: 9))
                    Text(Units.radius(meters: hub.haloRadiusMeters))
                        .font(theme.typography.font(.handTight, size: 10))
                    Text("·").foregroundColor(theme.palette.ink3)
                    Image(systemName: "person.2.fill").font(.system(size: 9))
                    Text(assignedNames)
                        .font(theme.typography.font(.handTight, size: 10))
                        .lineLimit(1)
                }
                .foregroundColor(theme.palette.ink2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.palette.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sketchBorder(seed: hub.id.uuidString.hashValue)
    }
    private var coordinateText: String {
        String(format: "%.4f, %.4f", hub.latitude, hub.longitude)
    }
}

private struct AddCurrentLocationCard: View {
    @Environment(\.theme) var theme
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "mappin.circle")
                    .font(.system(size: 22))
                    .foregroundColor(theme.palette.ink2)
                Text("+ Add Location")
                    .font(theme.typography.font(.handTight, size: 14, weight: .bold))
                    .foregroundColor(theme.palette.ink)
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(theme.palette.ink2)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .sketchBorder(dashed: true, padding: 14)
        }
        .buttonStyle(.plain)
    }
}

/// Hub annotation with tap → edit. Used on both Hubs map and Family map.
struct HubPin: View {
    @Environment(\.theme) var theme
    let hub: Hub
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle().fill(hub.color)
                Circle().stroke(theme.palette.line, lineWidth: 1.5)
                HubIconView(icon: hub.icon, size: 14, color: theme.palette.paper)
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }
}
