import CoreLocation
import SwiftUI

struct GroupWalksView: View {
    @Environment(\.theme) var theme
    @ObservedObject private var walkStore = WalkSessionStore.shared
    @ObservedObject private var familyStore = FamilyStore.shared
    @ObservedObject private var hubStore = HubStore.shared
    @ObservedObject private var presenceStore = PresenceStore.shared

    @State private var name = "Walk together"
    @State private var selectedHubId: UUID?
    @State private var durationMinutes = 45
    @State private var selectedParticipantIds: Set<UUID> = []
    @State private var didInitialize = false

    private let durations = [15, 30, 45, 60, 90, 120]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                activeWalksSection
                startWalkSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(theme.palette.paper.ignoresSafeArea())
        .navigationTitle("Group walks")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: initializeDraftIfNeeded)
    }

    private var activeWalksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupWalkSectionLabel("Active")
            if walkStore.activeSessions.isEmpty {
                EmptyGroupWalksView()
            } else {
                ForEach(walkStore.activeSessions) { session in
                    GroupWalkSessionView(
                        session: session,
                        onEnd: { walkStore.end(session.id) }
                    )
                }
            }
        }
    }

    private var startWalkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupWalkSectionLabel("Start a walk")
            VStack(alignment: .leading, spacing: 12) {
                TextField("Walk name", text: $name)
                    .textInputAutocapitalization(.words)
                    .font(theme.typography.font(.handTight, size: 16, weight: .bold))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(theme.palette.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Picker("Meet at", selection: $selectedHubId) {
                    Text("Choose a hub").tag(Optional<UUID>.none)
                    ForEach(hubStore.hubs) { hub in
                        Text(hub.name).tag(Optional(hub.id))
                    }
                }
                .pickerStyle(.menu)
                .font(theme.typography.font(.handFlow, size: 14))

                Picker("Duration", selection: $durationMinutes) {
                    ForEach(durations, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Participants")
                        .font(theme.typography.font(.handTight, size: 13, weight: .bold))
                        .foregroundColor(theme.palette.ink2)
                    ForEach(familyStore.visibleMembers) { member in
                        ParticipantToggleRow(
                            member: member,
                            isSelected: selectedParticipantIds.contains(member.id),
                            isLocked: member.id == familyStore.account.memberId
                        ) {
                            toggle(member.id)
                        }
                    }
                }

                Button(action: startWalk) {
                    Label("Start group walk", systemImage: "figure.walk.motion")
                        .font(theme.typography.font(.handTight, size: 15, weight: .bold))
                        .foregroundColor(theme.palette.paper)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Capsule().fill(canStart ? theme.palette.ink : theme.palette.ink3.opacity(0.5)))
                }
                .buttonStyle(.plain)
                .disabled(!canStart)
            }
            .padding(14)
            .background(theme.palette.paper.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var canStart: Bool {
        selectedHubId != nil && selectedParticipantIds.count >= 2
    }

    private func initializeDraftIfNeeded() {
        guard !didInitialize else { return }
        didInitialize = true
        selectedHubId = hubStore.hubs.first?.id
        selectedParticipantIds = Set(familyStore.visibleMembers.map(\.id))
        selectedParticipantIds.insert(familyStore.account.memberId)
    }

    private func toggle(_ memberId: UUID) {
        guard memberId != familyStore.account.memberId else { return }
        if selectedParticipantIds.contains(memberId) {
            selectedParticipantIds.remove(memberId)
        } else {
            selectedParticipantIds.insert(memberId)
        }
    }

    private func startWalk() {
        guard let selectedHubId,
              let hub = hubStore.hubs.first(where: { $0.id == selectedHubId }) else { return }
        walkStore.start(
            name: name,
            organizerId: familyStore.account.memberId,
            participantIds: Array(selectedParticipantIds),
            destinationHubId: hub.id,
            destinationName: hub.name,
            durationMinutes: durationMinutes,
            meetingRadiusMeters: max(80, hub.haloRadiusMeters)
        )
    }
}

private struct EmptyGroupWalksView: View {
    @Environment(\.theme) var theme

    var body: some View {
        Text("No group walk is active.")
            .font(theme.typography.font(.handFlow, size: 14))
            .foregroundColor(theme.palette.ink3)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.palette.paper.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct GroupWalkSectionLabel: View {
    @Environment(\.theme) var theme
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(theme.typography.font(.handTight, size: 11))
            .tracking(0.6)
            .foregroundColor(theme.palette.ink3)
            .padding(.top, 4)
    }
}

private struct GroupWalkSessionView: View {
    @Environment(\.theme) var theme
    @ObservedObject private var familyStore = FamilyStore.shared
    @ObservedObject private var hubStore = HubStore.shared
    @ObservedObject private var presenceStore = PresenceStore.shared

    let session: WalkSession
    let onEnd: () -> Void

    private var destinationHub: Hub? {
        guard let id = session.destinationHubId else { return nil }
        return hubStore.hubs.first { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name)
                        .font(theme.typography.font(.handTight, size: 18, weight: .bold))
                        .foregroundColor(theme.palette.ink)
                    Text("Meet at \(session.destinationName) · \(timeLeft)")
                        .font(theme.typography.font(.handFlow, size: 13))
                        .foregroundColor(theme.palette.ink3)
                }
                Spacer()
                Button("End", action: onEnd)
                    .font(theme.typography.font(.handTight, size: 13, weight: .bold))
                    .foregroundColor(theme.palette.haloRed)
            }

            ForEach(participants) { member in
                HStack(spacing: 10) {
                    MemberAvatar(member, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(member.displayName)
                            .font(theme.typography.font(.handTight, size: 14, weight: .bold))
                            .foregroundColor(theme.palette.ink)
                        Text(statusLine(for: member))
                            .font(theme.typography.font(.handFlow, size: 12))
                            .foregroundColor(theme.palette.ink3)
                    }
                    Spacer()
                    Image(systemName: statusIcon(for: member))
                        .foregroundColor(statusColor(for: member))
                }
            }
        }
        .padding(14)
        .background(theme.palette.paper.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var participants: [Member] {
        familyStore.members
            .filter { session.participantIds.contains($0.id) }
            .sorted { $0.displayName < $1.displayName }
    }

    private var timeLeft: String {
        let seconds = max(0, session.endsAt.timeIntervalSinceNow)
        if seconds < 60 { return "ending now" }
        return "\(Int(ceil(seconds / 60))) min left"
    }

    private func statusLine(for member: Member) -> String {
        guard let reading = presenceStore.primaryReading(for: member.id) else {
            return "Waiting for location"
        }
        guard let destinationHub else {
            return freshnessLine(for: reading)
        }
        let meters = CLLocation(latitude: reading.latitude, longitude: reading.longitude)
            .distance(from: destinationLocation(for: destinationHub))
        if meters <= session.meetingRadiusMeters {
            return "Arrived · \(freshnessLine(for: reading))"
        }
        return "\(Units.distance(meters: meters)) away · \(freshnessLine(for: reading))"
    }

    private func statusIcon(for member: Member) -> String {
        guard let reading = presenceStore.primaryReading(for: member.id),
              let destinationHub else { return "location.slash" }
        let meters = CLLocation(latitude: reading.latitude, longitude: reading.longitude)
            .distance(from: destinationLocation(for: destinationHub))
        return meters <= session.meetingRadiusMeters ? "checkmark.circle.fill" : "figure.walk"
    }

    private func statusColor(for member: Member) -> Color {
        guard let reading = presenceStore.primaryReading(for: member.id),
              let destinationHub else { return theme.palette.ink3 }
        let meters = CLLocation(latitude: reading.latitude, longitude: reading.longitude)
            .distance(from: destinationLocation(for: destinationHub))
        return meters <= session.meetingRadiusMeters ? theme.palette.haloGreen : theme.palette.ink2
    }

    private func destinationLocation(for hub: Hub) -> CLLocation {
        CLLocation(latitude: hub.latitude, longitude: hub.longitude)
    }

    private func freshnessLine(for reading: LocationReading) -> String {
        let seconds = max(0, Date().timeIntervalSince(reading.timestamp))
        if seconds < 60 { return "now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = Int(minutes / 60)
        return "\(hours) hr ago"
    }
}

private struct ParticipantToggleRow: View {
    @Environment(\.theme) var theme
    let member: Member
    let isSelected: Bool
    let isLocked: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                MemberAvatar(member, size: 30)
                Text(member.displayName)
                    .font(theme.typography.font(.handFlow, size: 14))
                    .foregroundColor(theme.palette.ink)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? theme.palette.haloGreen : theme.palette.ink3)
            }
            .opacity(isLocked ? 0.72 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }
}
