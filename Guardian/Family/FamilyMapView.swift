import SwiftUI
import MapKit
import CoreLocation

/// Shared map showing every member + every hub. Tap a member to push their
/// Member Detail; tap a hub to open its Edit sheet.
struct FamilyMapView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var familyStore: FamilyStore
    @EnvironmentObject var hubStore: HubStore
    @EnvironmentObject var presenceStore: PresenceStore

    let onMemberTap: (UUID) -> Void
    let onHubTap: (Hub) -> Void

    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: MockData.belmontRegion,
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
    )

    var body: some View {
        Map(position: $camera) {
            // Hubs as MapCircle halos + tappable pins
            ForEach(hubStore.hubs) { hub in
                MapCircle(center: hub.coordinate, radius: hub.haloRadiusMeters)
                    .foregroundStyle(hub.color.opacity(0.18))
                    .stroke(hub.color, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                Annotation(hub.name, coordinate: hub.coordinate) {
                    HubPin(hub: hub) { onHubTap(hub) }
                }
            }

            // Members — render every fresh device reading at a fanned-out
            // coordinate when multiple markers cluster at the same place.
            // Without this, e.g. Maya's iPhone + Andrew's Watch both at
            // Home render as one unreadable blob.
            //
            // `.annotationTitles(.hidden)` suppresses MapKit's default
            // label below the marker — our custom marker already has a
            // name pill, so without this we'd see the name twice. The
            // accessibility label (first arg) stays for VoiceOver.
            ForEach(renderedMarkers, id: \.id) { marker in
                Annotation(marker.member.displayName, coordinate: marker.coordinate) {
                    MemberMapMarker(
                        member: marker.member,
                        state: marker.state,
                        deviceKind: marker.deviceKind,
                        isPaired: marker.isPaired
                    ) {
                        onMemberTap(marker.member.id)
                    }
                }
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(.standard(elevation: .flat))
    }

    // MARK: - Marker layout

    /// One rendered marker on the map. Identified per (memberId, deviceId)
    /// because a divergent member produces two markers we still want to
    /// fan apart from each other.
    private struct RenderedMarker {
        let id: String
        let member: Member
        let coordinate: CLLocationCoordinate2D
        let state: LocationReading.HaloState
        let deviceKind: Device.Kind?
        let isPaired: Bool
    }

    /// All markers we want to render, with overlap resolved by fanning
    /// each cluster around its centroid.
    private var renderedMarkers: [RenderedMarker] {
        // Step 1: build raw markers from fresh readings, falling back to
        // the most recent stale reading if nothing fresh.
        let now = Date()
        var raw: [RenderedMarker] = []
        let myId = familyStore.account.memberId
        for member in familyStore.members {
            let all = presenceStore.readings(for: member.id)
            let fresh = all.filter { now.timeIntervalSince($0.timestamp) < 300 }
            var toShow = fresh.isEmpty ? Array(all.suffix(1)) : fresh

            // For the local account member, live GPS is ground truth.
            // A stale LocationReading we generated in an earlier session
            // syncs back from CloudKit on reinstall and would otherwise
            // show "me" at an old location until the next GPS fix. If we
            // have a current fix, render the local user there instead.
            if member.id == myId, let here = LocationManager.shared.current {
                let liveFresh = now.timeIntervalSince(here.timestamp) < 300
                if liveFresh || toShow.isEmpty {
                    let dev = familyStore.devices(for: member.id)
                        .first { $0.kind == .iPhone }?.id ?? member.id
                    toShow = [LocationReading(
                        memberId: member.id, deviceId: dev,
                        latitude: here.coordinate.latitude,
                        longitude: here.coordinate.longitude,
                        horizontalAccuracy: here.horizontalAccuracy,
                        timestamp: here.timestamp,
                        inHubId: nil, state: .unknown,
                        batteryPercent: nil, isOnWrist: nil, isMoving: nil
                    )]
                }
            }

            let diverged = (presenceStore.divergenceMeters(for: member.id) ?? 0) > 100
            for r in toShow {
                let device = familyStore.devices(for: member.id).first { $0.id == r.deviceId }
                raw.append(RenderedMarker(
                    id: "\(member.id.uuidString)-\(r.deviceId.uuidString)",
                    member: member,
                    coordinate: r.coordinate,
                    state: r.state,
                    deviceKind: device?.kind,
                    isPaired: diverged
                ))
            }
        }

        // Step 2: cluster by proximity. Two markers within `clusterRadius`
        // meters of each other belong to the same cluster.
        let clusterRadius: Double = 25
        var clusters: [[RenderedMarker]] = []
        for marker in raw {
            if let idx = clusters.firstIndex(where: { cluster in
                cluster.contains { existing in
                    distance(existing.coordinate, marker.coordinate) <= clusterRadius
                }
            }) {
                clusters[idx].append(marker)
            } else {
                clusters.append([marker])
            }
        }

        // Step 3: for each multi-member cluster, fan the markers around
        // the centroid in a radial pattern. Single-marker clusters render
        // at their original coordinate.
        var out: [RenderedMarker] = []
        for cluster in clusters {
            if cluster.count == 1 {
                out.append(cluster[0])
                continue
            }
            let center = centroid(cluster.map(\.coordinate))
            // Fan radius scales with cluster size so 4 markers don't
            // crash into each other. ~35 m for 2-3, ~50 m for 4+.
            let fanMeters: Double = cluster.count <= 3 ? 35 : 50
            let dLat = metersToLatitudeDegrees(fanMeters)
            let dLon = metersToLongitudeDegrees(fanMeters, atLatitude: center.latitude)
            // Sort by id so order is stable across renders (member's
            // position in the fan doesn't jump on every refresh).
            let sorted = cluster.sorted { $0.id < $1.id }
            for (i, m) in sorted.enumerated() {
                let angle = (Double(i) / Double(sorted.count)) * 2 * .pi - .pi / 2
                let offsetCoord = CLLocationCoordinate2D(
                    latitude: center.latitude + sin(angle) * dLat,
                    longitude: center.longitude + cos(angle) * dLon
                )
                out.append(RenderedMarker(
                    id: m.id,
                    member: m.member,
                    coordinate: offsetCoord,
                    state: m.state,
                    deviceKind: m.deviceKind,
                    isPaired: m.isPaired
                ))
            }
        }

        // Step 4: a member marker sitting on a hub pin gets its face
        // covered by the hub's house icon (the "house on Chelsea" bug —
        // a Home dropped at the user's current location). The member
        // fan-out only de-overlaps members from each other, not from
        // hubs. Nudge any member within ~28 m of a hub northward so the
        // avatar clears the pin; the name label sits below, still legible.
        let hubAvoid: Double = 28
        out = out.map { marker in
            guard let nearHub = hubStore.hubs.first(where: {
                distance($0.coordinate, marker.coordinate) <= hubAvoid
            }) else { return marker }
            let lift = metersToLatitudeDegrees(34)
            return RenderedMarker(
                id: marker.id,
                member: marker.member,
                coordinate: CLLocationCoordinate2D(
                    latitude: nearHub.coordinate.latitude + lift,
                    longitude: marker.coordinate.longitude
                ),
                state: marker.state,
                deviceKind: marker.deviceKind,
                isPaired: marker.isPaired
            )
        }
        return out
    }

    // MARK: - Geo helpers

    private func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
    private func centroid(_ coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        let lat = coords.map(\.latitude).reduce(0, +) / Double(coords.count)
        let lon = coords.map(\.longitude).reduce(0, +) / Double(coords.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    private func metersToLatitudeDegrees(_ m: Double) -> Double {
        // 1° latitude ≈ 111_111 m anywhere on Earth.
        m / 111_111.0
    }
    private func metersToLongitudeDegrees(_ m: Double, atLatitude lat: Double) -> Double {
        // 1° longitude ≈ 111_111 * cos(latitude) m.
        m / (111_111.0 * cos(lat * .pi / 180))
    }
}

private struct MemberMapMarker: View {
    @Environment(\.theme) var theme
    let member: Member
    let state: LocationReading.HaloState
    let deviceKind: Device.Kind?
    let isPaired: Bool   // true when this Member has multiple fresh readings
    let onTap: () -> Void

    private var ringColor: Color {
        switch state {
        case .leftOrbit: return theme.palette.haloRed
        case .wandering: return theme.palette.haloYellow
        case .onCorridor, .inHalo: return theme.palette.haloGreen
        case .noPing, .unknown: return theme.palette.ink3
        }
    }

    var body: some View {
        Button(action: onTap) {
            // Build 25: avatar illustration + name under, no circle ring.
            // The status accent moves to a tiny colored dot tucked at the
            // top-right of the avatar so map glances still surface
            // wandering/leftOrbit without the heavy ring chrome.
            VStack(spacing: 1) {
                ZStack(alignment: .topTrailing) {
                    MemberAvatar(member, size: 42)
                    // State dot in the top-right corner. Only show when
                    // the state actually carries info (skip neutral/unknown).
                    if showsStateDot {
                        Circle()
                            .fill(ringColor)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(theme.palette.paper, lineWidth: 1.5))
                            .offset(x: 3, y: -2)
                    }
                    // Device-kind glyph when the member's devices have
                    // diverged — useful "which marker is phone vs watch?"
                    if isPaired, let kind = deviceKind {
                        Image(systemName: kind.sfSymbol)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(theme.palette.ink)
                            .padding(2)
                            .background(Circle().fill(theme.palette.paper))
                            .overlay(Circle().stroke(theme.palette.line, lineWidth: 1))
                            .offset(x: 6, y: 12)
                    }
                }
                // Name pill under the avatar. Bold + paper-tinted bg so it
                // reads cleanly against street/satellite backgrounds.
                Text(member.displayName)
                    .font(theme.typography.font(.handTight, size: 10, weight: .bold))
                    .foregroundColor(theme.palette.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(theme.palette.paper.opacity(0.92))
                    )
                    .overlay(
                        Capsule().stroke(theme.palette.line.opacity(0.5), lineWidth: 0.5)
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var showsStateDot: Bool {
        switch state {
        case .inHalo, .onCorridor, .wandering, .leftOrbit: return true
        case .noPing, .unknown: return false
        }
    }
}
