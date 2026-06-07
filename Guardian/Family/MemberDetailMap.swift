import SwiftUI
import MapKit
import CoreLocation

/// Compact map shown on Member detail. Shows the member's most recent
/// location (single pin) + their assigned hubs as halos. Read-only —
/// tap to push the full Family map.
struct MemberDetailMap: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var hubStore: HubStore
    @EnvironmentObject var presenceStore: PresenceStore

    @EnvironmentObject var familyStore: FamilyStore
    let memberId: UUID
    let onTapFull: () -> Void

    private var reading: LocationReading? { presenceStore.reading(for: memberId) }
    private var member: Member? { familyStore.member(memberId) }
    private var assignedHubs: [Hub] {
        hubStore.hubs.filter { $0.assignedMemberIds.contains(memberId) }
    }

    var body: some View {
        Group {
            if let reading, let member {
                Map(initialPosition: .region(initialRegion(for: reading))) {
                    ForEach(assignedHubs) { hub in
                        MapCircle(center: hub.coordinate, radius: hub.haloRadiusMeters)
                            .foregroundStyle(hub.color.opacity(0.18))
                            .stroke(hub.color, style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                    }
                    Annotation(member.displayName, coordinate: reading.coordinate) {
                        // Build 25: avatar + name pin to match the family map.
                        // The name pill is part of this marker view; MapKit's
                        // default title label is suppressed below.
                        VStack(spacing: 1) {
                            MemberAvatar(member, size: 34)
                            Text(member.displayName)
                                .font(theme.typography.font(.handTight, size: 9, weight: .bold))
                                .foregroundColor(theme.palette.ink)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(theme.palette.paper.opacity(0.92)))
                        }
                    }
                    .annotationTitles(.hidden)
                }
                .mapStyle(.standard(elevation: .flat))
                .frame(height: 160)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.palette.line, lineWidth: 1.2)
                )
                .onTapGesture { onTapFull() }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.palette.paper2)
                    Text("No recent location")
                        .font(theme.typography.font(.handFlow, size: 13))
                        .foregroundColor(theme.palette.ink3)
                }
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.palette.line, lineWidth: 1.2)
                )
            }
        }
    }

    private func initialRegion(for reading: LocationReading) -> MKCoordinateRegion {
        // If the wearer's reading is near one of their assigned hubs,
        // frame both. Otherwise center on the reading.
        if let near = assignedHubs.min(by: { lhs, rhs in
            let l = CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
            let r = CLLocation(latitude: rhs.latitude, longitude: rhs.longitude)
            let p = CLLocation(latitude: reading.latitude, longitude: reading.longitude)
            return p.distance(from: l) < p.distance(from: r)
        }) {
            let lat = (reading.latitude + near.latitude) / 2
            let lon = (reading.longitude + near.longitude) / 2
            let dLat = max(abs(reading.latitude - near.latitude) * 2.5, 0.005)
            let dLon = max(abs(reading.longitude - near.longitude) * 2.5, 0.005)
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: dLat, longitudeDelta: dLon)
            )
        }
        return MKCoordinateRegion(
            center: reading.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
}
