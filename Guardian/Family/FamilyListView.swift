import SwiftUI
import CoreLocation

/// List of family members with status, place, and tap-to-drill.
struct FamilyListView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var familyStore: FamilyStore
    @EnvironmentObject var hubStore: HubStore
    @EnvironmentObject var presenceStore: PresenceStore

    let onTap: (UUID) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(orderedMembers, id: \.id) { member in
                    Button { onTap(member.id) } label: {
                        FamilyMemberCard(member: member)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }

    /// Wearers first, then guardians (so the at-risk people are visually on
    /// top). Within each group, critical/wandering states float up.
    private var orderedMembers: [Member] {
        let wearers = familyStore.watchedMembers.sorted { a, b in
            severity(a) > severity(b)
        }
        let guardians = familyStore.watcherMembers.sorted { a, b in a.name < b.name }
        return wearers + guardians
    }

    private func severity(_ m: Member) -> Int {
        guard let r = presenceStore.reading(for: m.id) else { return 0 }
        switch r.state {
        case .leftOrbit: return 4
        case .wandering: return 3
        case .onCorridor: return 2
        case .inHalo: return 1
        case .noPing, .unknown: return 0
        }
    }
}

/// One row in the Family list. Shows name, age, place, status tag, and
/// status dot. Tapping pushes Member Detail.
struct FamilyMemberCard: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var familyStore: FamilyStore
    @EnvironmentObject var hubStore: HubStore
    @EnvironmentObject var presenceStore: PresenceStore

    let member: Member

    private var resolved: Resolved {
        guard let reading = presenceStore.reading(for: member.id) else {
            return Resolved(
                accent: theme.palette.ink3,
                dot: .neutral,
                place: "no recent ping",
                tag: ""
            )
        }
        let location = CLLocation(latitude: reading.latitude, longitude: reading.longitude)

        if let inHubId = reading.inHubId,
           let hub = hubStore.hubs.first(where: { $0.id == inHubId }) {
            return Resolved(
                accent: theme.palette.haloGreen,
                dot: .green,
                place: "\(hub.name) · in halo",
                tag: "safe at base ♡"
            )
        }
        switch reading.state {
        case .onCorridor:
            return Resolved(accent: theme.palette.haloGreen, dot: .green,
                            place: "on a corridor", tag: "on the way")
        case .wandering:
            let nearest = nearestHubLabel(location: location)
            return Resolved(accent: theme.palette.haloYellow, dot: .yellow,
                            place: nearest, tag: "on the move")
        case .leftOrbit:
            let nearest = nearestHubLabel(location: location)
            return Resolved(accent: theme.palette.haloRed, dot: .red,
                            place: nearest, tag: "out of orbit")
        case .noPing:
            return Resolved(accent: theme.palette.ink3, dot: .neutral,
                            place: "watch hasn't pinged", tag: "")
        case .inHalo, .unknown:
            return Resolved(accent: theme.palette.ink3, dot: .neutral,
                            place: "—", tag: "")
        }
    }

    private func nearestHubLabel(location: CLLocation) -> String {
        if familyStore.isWatched(member.id),
           let near = hubStore.nearestHub(to: location, forMember: member.id) {
            return Units.distanceFrom(near.meters, hub: near.hub.name)
        }
        return "moving around"
    }

    var body: some View {
        HStack(spacing: 10) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(member.displayName)
                        .font(theme.typography.font(.handTight, size: 14, weight: .bold))
                        .foregroundColor(theme.palette.ink)
                    if let age = member.ageYears {
                        Text("· \(age)")
                            .font(theme.typography.font(.handTight, size: 13))
                            .foregroundColor(theme.palette.ink3)
                    }
                    if familyStore.isGuardian(member.id) {
                        Text("guardian")
                            .font(theme.typography.font(.handFlow, size: 11))
                            .foregroundColor(theme.palette.ink3)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().stroke(theme.palette.lineSoft, lineWidth: 1))
                    }
                }
                Text(resolved.place)
                    .font(theme.typography.font(.handFlow, size: 13))
                    .foregroundColor(theme.palette.ink2)
                    .lineLimit(2)
                if !resolved.tag.isEmpty {
                    Text(resolved.tag)
                        .font(theme.typography.font(.handFlow, size: 13))
                        .foregroundColor(resolved.accent)
                }
            }
            Spacer()
            VStack(spacing: 4) {
                StatusDot(status: resolved.dot)
                if let battery = batteryLabel {
                    Text(battery)
                        .font(theme.typography.font(.handTight, size: 9))
                        .foregroundColor(theme.palette.ink3)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.palette.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sketchBorder(seed: Int(member.id.uuidString.hashValue & 0xFF))
        .overlay(
            Rectangle()
                .fill(resolved.accent)
                .frame(width: 5)
                .padding(.vertical, 6),
            alignment: .leading
        )
    }

    @ViewBuilder
    private var avatar: some View {
        // Build 25: bundled illustration if available, fallback to the
        // initial-in-circle for any member without one. No name under
        // the list-row avatar — the name lives in the row's main column,
        // adding it twice would crowd the row.
        MemberAvatar(member, size: 44)
    }

    private var batteryLabel: String? {
        guard familyStore.isWatched(member.id),
              let pct = presenceStore.reading(for: member.id)?.batteryPercent else { return nil }
        return "\(pct)%"
    }

    private struct Resolved {
        let accent: Color
        let dot: StatusDot.Status
        let place: String
        let tag: String
    }
}
