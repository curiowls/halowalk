import SwiftUI

/// Triggers live behind the ··· menu — they're configured once during
/// onboarding and rarely revisited. The list shows each rule with its
/// affected wearers, condition, and severity.
struct TriggersListView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var triggerStore: TriggerStore
    @EnvironmentObject var familyStore: FamilyStore
    @EnvironmentObject var hubStore: HubStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Set & forget rules — only buzz me when it matters.")
                    .font(theme.typography.font(.handFlow, size: 14))
                    .foregroundColor(theme.palette.ink2)
                    .padding(.horizontal, 4)

                ForEach(Array(triggerStore.triggers.enumerated()), id: \.element.id) { i, trigger in
                    NavigationLink {
                        TriggerEditView(triggerId: trigger.id)
                    } label: {
                        TriggerCard(triggerIndex: i)
                    }
                    .buttonStyle(.plain)
                }

                // CRITICAL: do NOT call any function that mutates the store
                // inside the NavigationLink destination closure — SwiftUI
                // re-evaluates body whenever a @Published changes, and a
                // mutation here causes an infinite loop (Build 11–13 freeze).
                // The editor handles new-trigger creation via its Save button
                // when the id isn't found in the store yet.
                NavigationLink {
                    TriggerEditView(triggerId: UUID())
                } label: {
                    Text("+ New trigger")
                        .font(theme.typography.font(.handFlow, size: 16))
                        .foregroundColor(theme.palette.ink2)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .sketchBorder(dashed: true, padding: 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.paper.ignoresSafeArea())
        .navigationTitle("Triggers")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// (Unused — kept around as documentation of the bug. The new-trigger
    /// NavigationLink above passes a fresh UUID and lets the editor create
    /// the Trigger only when the user taps Save.)
    private func addTriggerStub() -> UUID {
        let new = Trigger(
            id: UUID(),
            name: "",
            affectsMemberIds: familyStore.watchedMembers.map(\.id),
            condition: .awayFromAllHubs(forMinutes: 20),
            notifyMode: .headsUp,
            notifyMemberIds: familyStore.watcherMembers.map(\.id),
            deviceSource: .primary,
            enabled: false,
            createdAt: Date()
        )
        // Don't add yet — return only the id so the editor can hydrate from
        // an in-memory stub. The editor's Save button commits.
        triggerStore.add(new)
        return new.id
    }
}

private struct TriggerCard: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var triggerStore: TriggerStore
    @EnvironmentObject var familyStore: FamilyStore
    @EnvironmentObject var hubStore: HubStore
    let triggerIndex: Int

    private var trigger: Trigger { triggerStore.triggers[triggerIndex] }

    private var modeColor: Color {
        switch trigger.notifyMode {
        case .quiet: return theme.palette.haloGreen
        case .headsUp: return theme.palette.haloYellow
        case .critical: return theme.palette.haloRed
        }
    }

    private var modeLabel: String {
        switch trigger.notifyMode {
        case .quiet: return "QUIET"
        case .headsUp: return "HEADS-UP"
        case .critical: return "CRITICAL"
        }
    }

    private var affectedNames: String {
        let names = trigger.affectsMemberIds.compactMap { familyStore.member($0)?.displayName }
        return names.isEmpty ? "anyone" : names.joined(separator: ", ")
    }

    private var conditionSummary: String {
        trigger.condition.summary(
            resolvingHub: { hubId in hubStore.hubs.first(where: { $0.id == hubId })?.name },
            resolvingCorridor: { _ in nil }
        )
    }

    /// Live auto-name resolved against current stores — used as a subtitle
    /// when the user has set a custom title, so the actual behavior is
    /// always visible.
    private var autoName: String {
        trigger.autoName(
            memberDisplayName: { familyStore.member($0)?.displayName },
            hubName: { id in hubStore.hubs.first(where: { $0.id == id })?.name },
            corridorName: { _ in nil },
            allWatchedMemberIds: familyStore.watchedMembers.map(\.id)
        )
    }
    private var displayTitle: String {
        trigger.displayTitle(
            memberDisplayName: { familyStore.member($0)?.displayName },
            hubName: { id in hubStore.hubs.first(where: { $0.id == id })?.name },
            corridorName: { _ in nil },
            allWatchedMemberIds: familyStore.watchedMembers.map(\.id)
        )
    }
    private var hasCustomName: Bool {
        !trigger.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Use .center so the toggle aligns vertically with the title.
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(displayTitle)
                        .font(theme.typography.font(.handTight, size: 15, weight: .bold))
                    if hasCustomName {
                        // Custom label is set — show the actual condition
                        // truth as a subtitle so users always see what the
                        // trigger really does.
                        Text(autoName)
                            .font(theme.typography.font(.handFlow, size: 11))
                            .foregroundColor(theme.palette.ink3)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { trigger.enabled },
                    set: { _ in triggerStore.toggle(trigger.id) }
                ))
                .labelsHidden()
                .tint(modeColor)
            }
            HStack(spacing: 6) {
                Tag(text: modeLabel, fill: modeColor, foreground: theme.palette.paper)
                Text("when \(affectedNames)")
                    .font(theme.typography.font(.handFlow, size: 13))
                    .foregroundColor(theme.palette.ink2)
            }
            Text(humanCondition)
                .font(theme.typography.font(.handFlow, size: 13))
                .foregroundColor(theme.palette.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .sketchBorder(seed: triggerIndex, padding: 0)
        .opacity(trigger.enabled ? 1.0 : 0.55)
    }

    private var humanCondition: String {
        switch trigger.condition {
        case .leavesHub(let hubId):
            let h = hubStore.hubs.first(where: { $0.id == hubId })?.name ?? "a hub"
            return "leaves \(h)"
        case .entersHub(let hubId):
            let h = hubStore.hubs.first(where: { $0.id == hubId })?.name ?? "a hub"
            return "enters \(h)"
        case .lateArrivingAtHub(let hubId, let mins, _):
            let h = hubStore.hubs.first(where: { $0.id == hubId })?.name ?? "destination"
            return "doesn't reach \(h) within \(mins) min"
        case .awayFromAllHubs(let mins):
            return "is away from all hubs for \(mins)+ min"
        case .offCorridor:
            return "leaves the safe corridor"
        case .noPing(let mins):
            return "doesn't ping for \(mins) min"
        case .batteryUnder(let pct):
            return "watch battery drops below \(pct)%"
        case .extendedHalo:
            return "extends their halo"
        case .sosTapped:
            return "taps SOS on the watch"
        case .devicesDiverged(let m):
            return "phone and watch are \(m)+ m apart"
        }
    }
}
