import SwiftUI
import CoreLocation

/// Pushed from the Family list/map. Shows live status, hub assignments,
/// recent notifications about this person, and the Quick Reply / Nudge /
/// Head Out actions.
struct MemberDetailView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var familyStore: FamilyStore
    @EnvironmentObject var hubStore: HubStore
    @EnvironmentObject var presenceStore: PresenceStore
    @EnvironmentObject var notificationStore: NotificationStore

    let memberId: UUID
    @State private var presentedRespond: AppNotification.RespondKind?
    @State private var showingWatchSheet = false
    @ObservedObject private var watchStore = ContinuousWatchStore.shared

    private var member: Member? { familyStore.member(memberId) }
    private var reading: LocationReading? { presenceStore.reading(for: memberId) }
    private var canWatch: Bool {
        guard let member else { return false }
        // Don't offer "watch yourself" or watching a fellow guardian who
        // doesn't broadcast.
        return member.id != familyStore.account.memberId
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let member {
                    StatusHero(member: member, reading: reading)
                    ContinuousWatchBanner(
                        store: watchStore,
                        watchedMemberId: member.id
                    )
                    MemberDetailMap(memberId: member.id, onTapFull: {})
                    DivergenceBanner(memberId: member.id)
                    DeviceRows(memberId: member.id)
                    QuickActions(member: member, onAction: { presentedRespond = $0 })
                    if canWatch {
                        WatchLiveButton(showingSheet: $showingWatchSheet)
                    }
                    if familyStore.isWatched(member.id) {
                        AssignedHubs(memberId: member.id)
                        TodayTimeline(memberId: member.id)
                    } else {
                        GuardianSharingPanel(member: member)
                    }
                    RelevantNotifications(memberId: member.id)
                } else {
                    Text("Member not found.")
                        .padding()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .sheet(isPresented: $showingWatchSheet) {
            ContinuousWatchSheet(watchedMemberId: memberId)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.paper.ignoresSafeArea())
        .navigationTitle(member?.displayName ?? "Member")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $presentedRespond) { kind in
            respondSheet(for: kind)
        }
        // Member detail shows live location, distance, and the small map
        // — keep coarse continuous updates running while the user is here.
        .locationAware()
    }

    @ViewBuilder
    private func respondSheet(for kind: AppNotification.RespondKind) -> some View {
        if let member {
            NavigationStack {
                switch kind {
                case .quickReply: RespondQuickReplyView(toMemberId: member.id)
                case .nudgeHome:  RespondNudgeHomeView(toMemberId: member.id)
                case .headOut:    RespondHeadOutView(toMemberId: member.id)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

extension AppNotification.RespondKind: Identifiable {
    public var id: String { rawValue }
}

// MARK: - Watch live button

private struct WatchLiveButton: View {
    @Environment(\.theme) var theme
    @Binding var showingSheet: Bool
    var body: some View {
        Button {
            showingSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 14))
                Text("Watch live")
                    .font(theme.typography.font(.handTight, size: 13, weight: .bold))
                Spacer()
                Text("until…")
                    .font(theme.typography.font(.handFlow, size: 12))
                    .foregroundColor(theme.palette.ink3)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(theme.palette.ink3)
            }
            .foregroundColor(theme.palette.ink)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sketchBorder(padding: 0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Divergence banner (when devices are >100m apart)

private struct DivergenceBanner: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var presenceStore: PresenceStore
    let memberId: UUID

    var body: some View {
        if let dist = presenceStore.divergenceMeters(for: memberId), dist > 100 {
            HStack(spacing: 10) {
                Image(systemName: "iphone.and.arrow.right.outward")
                    .font(.system(size: 22))
                    .foregroundColor(theme.palette.haloYellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Devices are apart")
                        .font(theme.typography.font(.handTight, size: 13, weight: .bold))
                    Text("Phone and watch are \(Units.distance(meters: dist)) apart.")
                        .font(theme.typography.font(.handFlow, size: 12))
                        .foregroundColor(theme.palette.ink2)
                }
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sketchBorder(fill: theme.palette.highlightSoft, padding: 0)
        }
    }
}

// MARK: - Per-device rows

/// Lists every Device this Member has, with its own status pill,
/// last-seen, battery, and (if available) hub it's currently inside of.
private struct DeviceRows: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var familyStore: FamilyStore
    @EnvironmentObject var presenceStore: PresenceStore
    @EnvironmentObject var hubStore: HubStore
    let memberId: UUID

    private var devices: [Device] { familyStore.devices(for: memberId) }

    var body: some View {
        if devices.count > 1 {
            VStack(alignment: .leading, spacing: 6) {
                Text("Devices")
                    .font(theme.typography.font(.handTight, size: 11))
                    .tracking(0.5)
                    .foregroundColor(theme.palette.ink3)
                VStack(spacing: 8) {
                    ForEach(devices) { device in
                        DeviceRow(memberId: memberId, device: device)
                    }
                }
            }
        }
    }
}

private struct DeviceRow: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var presenceStore: PresenceStore
    @EnvironmentObject var hubStore: HubStore
    let memberId: UUID
    let device: Device

    private var reading: LocationReading? {
        presenceStore.reading(memberId: memberId, deviceId: device.id)
    }

    private var stateAccent: Color {
        guard let r = reading else { return theme.palette.ink3 }
        switch r.state {
        case .inHalo, .onCorridor: return theme.palette.haloGreen
        case .wandering: return theme.palette.haloYellow
        case .leftOrbit: return theme.palette.haloRed
        case .noPing, .unknown: return theme.palette.ink3
        }
    }
    private var statusLabel: String {
        guard let r = reading else { return "no recent ping" }
        if let id = r.inHubId, let hub = hubStore.hubs.first(where: { $0.id == id }) {
            return "at \(hub.name)"
        }
        switch r.state {
        case .onCorridor: return "on a corridor"
        case .wandering: return "moving around"
        case .leftOrbit: return "out of orbit"
        case .noPing: return "no ping"
        case .inHalo, .unknown: return "—"
        }
    }
    private var freshness: String {
        guard let r = reading else { return "stale" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: r.timestamp, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(theme.palette.paper2).frame(width: 36, height: 36)
                Circle().stroke(theme.palette.line, lineWidth: 1.2).frame(width: 36, height: 36)
                Image(systemName: device.kind.sfSymbol)
                    .font(.system(size: 16))
                    .foregroundColor(theme.palette.ink2)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(device.kind.displayLabel)
                        .font(theme.typography.font(.handTight, size: 13, weight: .bold))
                    if device.isOnWrist == true {
                        Text("· on wrist")
                            .font(theme.typography.font(.handFlow, size: 11))
                            .foregroundColor(theme.palette.ink3)
                    }
                }
                Text("\(statusLabel) · \(freshness)")
                    .font(theme.typography.font(.handFlow, size: 12))
                    .foregroundColor(theme.palette.ink3)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Circle().fill(stateAccent).frame(width: 8, height: 8)
                if let pct = reading?.batteryPercent {
                    Text("\(pct)%")
                        .font(theme.typography.font(.handTight, size: 10))
                        .foregroundColor(theme.palette.ink3)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sketchBorder(seed: device.id.uuidString.hashValue, padding: 0)
    }
}

// MARK: - Hero card showing the live state

private struct StatusHero: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var hubStore: HubStore
    @EnvironmentObject var familyStore: FamilyStore
    let member: Member
    let reading: LocationReading?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                MemberAvatar(member, size: 64)
                VStack(alignment: .leading, spacing: 0) {
                    Text(member.name)
                        .font(theme.typography.font(.handTight, size: 18, weight: .bold))
                    if let age = member.ageYears {
                        Text("\(age) years · \(familyStore.isGuardian(member.id) ? "guardian" : "wearer")")
                            .font(theme.typography.font(.handFlow, size: 13))
                            .foregroundColor(theme.palette.ink3)
                    } else {
                        Text(familyStore.isGuardian(member.id) ? "guardian" : "wearer")
                            .font(theme.typography.font(.handFlow, size: 13))
                            .foregroundColor(theme.palette.ink3)
                    }
                }
                Spacer()
                if let pct = reading?.batteryPercent {
                    BatteryBadge(percent: pct)
                }
            }
            Divider().background(theme.palette.lineSoft)
            VStack(alignment: .leading, spacing: 2) {
                Text(stateHeadline)
                    .font(theme.typography.font(.handTight, size: 15, weight: .bold))
                    .foregroundColor(stateAccent)
                Text(stateSubline)
                    .font(theme.typography.font(.handFlow, size: 14))
                    .foregroundColor(theme.palette.ink2)
                if let updated = reading?.timestamp {
                    Text("updated \(relativeTime(updated))")
                        .font(theme.typography.font(.handFlow, size: 12))
                        .foregroundColor(theme.palette.ink3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sketchBorder(padding: 14)
    }

    private var stateAccent: Color {
        guard let r = reading else { return theme.palette.ink3 }
        switch r.state {
        case .inHalo, .onCorridor: return theme.palette.haloGreen
        case .wandering: return theme.palette.haloYellow
        case .leftOrbit: return theme.palette.haloRed
        case .noPing, .unknown: return theme.palette.ink3
        }
    }
    private var stateHeadline: String {
        guard let r = reading else { return "no recent ping" }
        if let id = r.inHubId, let hub = hubStore.hubs.first(where: { $0.id == id }) {
            return "at \(hub.name) ♡"
        }
        switch r.state {
        case .onCorridor: return "on a safe corridor"
        case .wandering:  return "wandering"
        case .leftOrbit:  return "out of orbit"
        case .noPing:     return "watch hasn't pinged"
        case .inHalo:     return "in a halo"
        case .unknown:    return "—"
        }
    }
    private var stateSubline: String {
        guard let r = reading else { return "Waiting for a fresh location." }
        let location = CLLocation(latitude: r.latitude, longitude: r.longitude)
        if familyStore.isWatched(member.id),
           let near = hubStore.nearestHub(to: location, forMember: member.id) {
            return Units.distanceFrom(near.meters, hub: near.hub.name)
        }
        return "\(Units.accuracy(meters: r.horizontalAccuracy)) accuracy"
    }
    private func relativeTime(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: d, relativeTo: Date())
    }
}

private struct BatteryBadge: View {
    @Environment(\.theme) var theme
    let percent: Int
    var body: some View {
        let icon: String = {
            if percent < 20 { return "battery.25" }
            if percent < 60 { return "battery.50" }
            return "battery.100"
        }()
        let color: Color = percent < 20 ? theme.palette.haloRed : theme.palette.ink2
        return HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 12))
            Text("\(percent)%").font(theme.typography.font(.handTight, size: 11))
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().stroke(theme.palette.lineSoft, lineWidth: 1))
    }
}

// MARK: - Quick actions row

private struct QuickActions: View {
    @Environment(\.theme) var theme
    let member: Member
    let onAction: (AppNotification.RespondKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quick respond")
                .font(theme.typography.font(.handTight, size: 11))
                .tracking(0.5)
                .foregroundColor(theme.palette.ink3)
            HStack(spacing: 8) {
                actionChip(.quickReply, label: "Reply", icon: "heart.text.square")
                actionChip(.nudgeHome, label: "Nudge home", icon: "house.fill")
                actionChip(.headOut, label: "Head out", icon: "car.fill")
            }
        }
    }

    @ViewBuilder
    private func actionChip(_ kind: AppNotification.RespondKind, label: String, icon: String) -> some View {
        Button { onAction(kind) } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(theme.typography.font(.handTight, size: 11, weight: .bold))
            }
            .foregroundColor(theme.palette.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .sketchBorder(padding: 0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hubs assigned to this wearer

private struct AssignedHubs: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var hubStore: HubStore
    let memberId: UUID

    private var hubs: [Hub] {
        hubStore.hubs.filter { $0.assignedMemberIds.contains(memberId) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hubs · \(hubs.count)")
                .font(theme.typography.font(.handTight, size: 11))
                .tracking(0.5)
                .foregroundColor(theme.palette.ink3)
            if hubs.isEmpty {
                Text("No hubs assigned yet.")
                    .font(theme.typography.font(.handFlow, size: 13))
                    .foregroundColor(theme.palette.ink3)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(hubs) { hub in
                        HStack(spacing: 4) {
                            Circle().fill(hub.color).frame(width: 8, height: 8)
                            Text(hub.name)
                                .font(theme.typography.font(.handTight, size: 11))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().stroke(theme.palette.lineSoft, lineWidth: 1))
                    }
                }
            }
        }
    }
}

// MARK: - Today's orbit timeline

private struct TodayTimeline: View {
    @Environment(\.theme) var theme
    let memberId: UUID

    /// Mock timeline for now — wired to real history in Build 6.
    private let events: [(time: String, label: String, sub: String, accent: StatusDot.Status)] = [
        ("now",    "Walking home",      "0.3 mi from Home",    .green),
        ("3:18p",  "Left Library",      "via the corridor",    .green),
        ("3:05p",  "At Library",        "storytime ended",     .green),
        ("2:30p",  "Library corridor",  "School → Library",    .green),
        ("2:15p",  "Left School",       "after dismissal",     .green),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today's orbit")
                .font(theme.typography.font(.handTight, size: 11))
                .tracking(0.5)
                .foregroundColor(theme.palette.ink3)

            VStack(spacing: 8) {
                ForEach(0..<events.count, id: \.self) { i in
                    HStack(alignment: .top, spacing: 10) {
                        Text(events[i].time)
                            .font(theme.typography.font(.handTight, size: 11))
                            .foregroundColor(theme.palette.ink3)
                            .frame(width: 44, alignment: .leading)
                        StatusDot(status: events[i].accent)
                            .frame(width: 10, height: 10)
                            .padding(.top, 4)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(events[i].label)
                                .font(theme.typography.font(.handTight, size: 13, weight: .bold))
                            Text(events[i].sub)
                                .font(theme.typography.font(.handFlow, size: 12))
                                .foregroundColor(theme.palette.ink3)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Guardian-specific panel

private struct GuardianSharingPanel: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var presenceStore: PresenceStore
    @EnvironmentObject var familyStore: FamilyStore
    let member: Member

    private var sharing: Bool {
        presenceStore.guardiansSharing.contains(member.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sharing with the family")
                .font(theme.typography.font(.handTight, size: 11))
                .tracking(0.5)
                .foregroundColor(theme.palette.ink3)
            HStack {
                Text(sharing ? "Wearers can see your location." : "Location sharing is paused.")
                    .font(theme.typography.font(.handFlow, size: 14))
                    .foregroundColor(theme.palette.ink2)
                Spacer()
                if member.id == familyStore.account.memberId {
                    Toggle("", isOn: Binding(
                        get: { sharing },
                        set: { newVal in
                            if newVal {
                                presenceStore.guardiansSharing.insert(member.id)
                            } else {
                                presenceStore.guardiansSharing.remove(member.id)
                            }
                        }
                    ))
                    .labelsHidden()
                    .tint(theme.palette.haloGreen)
                }
            }
        }
        .padding(12)
        .sketchBorder(padding: 0)
    }
}

// MARK: - Notifications about this person

private struct RelevantNotifications: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var notificationStore: NotificationStore
    let memberId: UUID

    private var items: [AppNotification] {
        notificationStore.visible.filter { $0.aboutMemberId == memberId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent")
                .font(theme.typography.font(.handTight, size: 11))
                .tracking(0.5)
                .foregroundColor(theme.palette.ink3)
            if items.isEmpty {
                Text("No recent notifications about \(notificationStore.notifications.first(where: { $0.aboutMemberId == memberId })?.aboutMemberId.map { _ in "them" } ?? "them").")
                    .font(theme.typography.font(.handFlow, size: 13))
                    .foregroundColor(theme.palette.ink3)
            } else {
                ForEach(items.prefix(3)) { n in
                    NotificationRowCompact(notification: n)
                }
            }
        }
    }
}

private struct NotificationRowCompact: View {
    @Environment(\.theme) var theme
    let notification: AppNotification

    private var accent: Color {
        switch notification.severity {
        case .critical: return theme.palette.haloRed
        case .headsUp:  return theme.palette.haloYellow
        case .quiet:    return theme.palette.haloGreen
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(notification.title)
                .font(theme.typography.font(.handTight, size: 13, weight: .bold))
            Text(notification.body)
                .font(theme.typography.font(.handFlow, size: 13))
                .foregroundColor(theme.palette.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .sketchBorder(padding: 0)
        .overlay(
            Rectangle().fill(accent).frame(width: 4)
                .padding(.vertical, 4),
            alignment: .leading
        )
    }
}
