import SwiftUI

/// Push destination for editing a trigger. Pushed from TriggersListView when
/// the user taps a trigger row. Supports renaming, changing the condition
/// type + parameters, picking severity, and choosing affected wearers +
/// notified guardians.
struct TriggerEditView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var triggerStore = TriggerStore.shared
    @ObservedObject private var familyStore = FamilyStore.shared
    @ObservedObject private var hubStore = HubStore.shared

    @State private var draft: Trigger
    @State private var conditionKind: ConditionKind
    @State private var hubId: UUID
    @State private var byMinutes: Int
    @State private var batteryPct: Int
    @State private var noPingMins: Int
    @State private var awayMins: Int

    enum ConditionKind: String, CaseIterable {
        case leavesHub = "Leaves a hub"
        case entersHub = "Enters a hub"
        case lateArriving = "Late arriving at a hub"
        case awayFromAll = "Away from all hubs"
        case noPing = "No ping from watch"
        case batteryUnder = "Watch battery low"
        case extendedHalo = "Extends their halo"
        case sosTapped = "Taps SOS"
    }

    init(triggerId: UUID) {
        let initial = TriggerStore.shared.triggers.first(where: { $0.id == triggerId })
            ?? Trigger(id: triggerId, name: "", affectsMemberIds: [],
                       condition: .awayFromAllHubs(forMinutes: 20),
                       notifyMode: .headsUp, notifyMemberIds: [],
                       deviceSource: .primary,
                       enabled: true, createdAt: Date())
        _draft = State(initialValue: initial)
        let firstHubId = HubStore.shared.hubs.first?.id ?? UUID()

        switch initial.condition {
        case .leavesHub(let id):
            _conditionKind = State(initialValue: .leavesHub)
            _hubId = State(initialValue: id)
            _byMinutes = State(initialValue: 15)
            _batteryPct = State(initialValue: 20)
            _noPingMins = State(initialValue: 30)
            _awayMins = State(initialValue: 20)
        case .entersHub(let id):
            _conditionKind = State(initialValue: .entersHub)
            _hubId = State(initialValue: id)
            _byMinutes = State(initialValue: 15)
            _batteryPct = State(initialValue: 20)
            _noPingMins = State(initialValue: 30)
            _awayMins = State(initialValue: 20)
        case .lateArrivingAtHub(let id, let mins, _):
            _conditionKind = State(initialValue: .lateArriving)
            _hubId = State(initialValue: id)
            _byMinutes = State(initialValue: mins)
            _batteryPct = State(initialValue: 20)
            _noPingMins = State(initialValue: 30)
            _awayMins = State(initialValue: 20)
        case .awayFromAllHubs(let mins):
            _conditionKind = State(initialValue: .awayFromAll)
            _hubId = State(initialValue: firstHubId)
            _byMinutes = State(initialValue: 15)
            _batteryPct = State(initialValue: 20)
            _noPingMins = State(initialValue: 30)
            _awayMins = State(initialValue: mins)
        case .offCorridor:
            _conditionKind = State(initialValue: .awayFromAll)
            _hubId = State(initialValue: firstHubId)
            _byMinutes = State(initialValue: 15)
            _batteryPct = State(initialValue: 20)
            _noPingMins = State(initialValue: 30)
            _awayMins = State(initialValue: 20)
        case .noPing(let mins):
            _conditionKind = State(initialValue: .noPing)
            _hubId = State(initialValue: firstHubId)
            _byMinutes = State(initialValue: 15)
            _batteryPct = State(initialValue: 20)
            _noPingMins = State(initialValue: mins)
            _awayMins = State(initialValue: 20)
        case .batteryUnder(let pct):
            _conditionKind = State(initialValue: .batteryUnder)
            _hubId = State(initialValue: firstHubId)
            _byMinutes = State(initialValue: 15)
            _batteryPct = State(initialValue: pct)
            _noPingMins = State(initialValue: 30)
            _awayMins = State(initialValue: 20)
        case .extendedHalo:
            _conditionKind = State(initialValue: .extendedHalo)
            _hubId = State(initialValue: firstHubId)
            _byMinutes = State(initialValue: 15)
            _batteryPct = State(initialValue: 20)
            _noPingMins = State(initialValue: 30)
            _awayMins = State(initialValue: 20)
        case .sosTapped:
            _conditionKind = State(initialValue: .sosTapped)
            _hubId = State(initialValue: firstHubId)
            _byMinutes = State(initialValue: 15)
            _batteryPct = State(initialValue: 20)
            _noPingMins = State(initialValue: 30)
            _awayMins = State(initialValue: 20)
        case .devicesDiverged:
            // Editor doesn't expose this in the kind picker yet — fall through
            // to "away from all" as a sensible default if encountered.
            _conditionKind = State(initialValue: .awayFromAll)
            _hubId = State(initialValue: firstHubId)
            _byMinutes = State(initialValue: 15)
            _batteryPct = State(initialValue: 20)
            _noPingMins = State(initialValue: 30)
            _awayMins = State(initialValue: 20)
        }
    }

    /// Auto-name resolved against the *current draft* so the placeholder
    /// updates live as the user changes condition / members.
    private var liveAutoName: String {
        // Use the draft's intended condition (which may not yet be saved
        // back into draft.condition when conditionKind etc. have been
        // edited but the user hasn't tapped Save yet). Approximate by
        // re-deriving as save() does.
        let pendingCondition = composedCondition()
        var preview = draft
        preview.condition = pendingCondition
        return preview.autoName(
            memberDisplayName: { familyStore.member($0)?.displayName },
            hubName: { id in hubStore.hubs.first(where: { $0.id == id })?.name },
            corridorName: { _ in nil },
            allWatchedMemberIds: familyStore.watchedMembers.map(\.id)
        )
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField(liveAutoName, text: $draft.name)
                Text("Leave blank to use the auto-generated name. If you set a custom title, the actual behavior is shown beneath it in the trigger list so it's never hidden.")
                    .font(theme.typography.font(.handFlow, size: 12))
                    .foregroundColor(theme.palette.ink3)
            }

            Section("When this happens") {
                Picker("Condition", selection: $conditionKind) {
                    ForEach(ConditionKind.allCases, id: \.self) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                conditionParameters
            }

            Section("Affects which wearers") {
                if familyStore.watchedMembers.isEmpty {
                    Text("Add a wearer first.")
                        .font(theme.typography.font(.handFlow, size: 13))
                        .foregroundColor(theme.palette.ink3)
                } else {
                    ForEach(familyStore.watchedMembers) { wearer in
                        toggleRow(
                            label: wearer.displayName,
                            color: wearer.accentColor,
                            isSelected: draft.affectsMemberIds.contains(wearer.id),
                            toggle: { toggle($0, in: &draft.affectsMemberIds) },
                            id: wearer.id
                        )
                    }
                }
            }

            Section("Notify which guardians") {
                ForEach(familyStore.watcherMembers) { guardian in
                    toggleRow(
                        label: guardian.displayName,
                        color: guardian.accentColor,
                        isSelected: draft.notifyMemberIds.contains(guardian.id),
                        toggle: { toggle($0, in: &draft.notifyMemberIds) },
                        id: guardian.id
                    )
                }
            }

            Section("How loudly") {
                Picker("Mode", selection: $draft.notifyMode) {
                    Text("Quiet ♡").tag(Trigger.NotifyMode.quiet)
                    Text("Heads-up").tag(Trigger.NotifyMode.headsUp)
                    Text("Critical").tag(Trigger.NotifyMode.critical)
                }
                .pickerStyle(.segmented)
                Text(modeExplanation)
                    .font(theme.typography.font(.handFlow, size: 12))
                    .foregroundColor(theme.palette.ink3)
            }

            Section {
                Toggle("Enabled", isOn: $draft.enabled)
            }

            Section {
                Button(role: .destructive) {
                    triggerStore.remove(draft.id)
                    dismiss()
                } label: {
                    Label("Delete this trigger", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Edit trigger")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .disabled(!canSave)
                    .fontWeight(.bold)
            }
        }
    }

    @ViewBuilder
    private var conditionParameters: some View {
        switch conditionKind {
        case .leavesHub, .entersHub:
            hubPicker
        case .lateArriving:
            hubPicker
            Stepper("Within \(byMinutes) min", value: $byMinutes, in: 1...120, step: 1)
        case .awayFromAll:
            Stepper("For \(awayMins) min", value: $awayMins, in: 1...240, step: 1)
        case .noPing:
            Stepper("After \(noPingMins) min", value: $noPingMins, in: 5...240, step: 5)
        case .batteryUnder:
            Stepper("Below \(batteryPct)%", value: $batteryPct, in: 5...50, step: 5)
        case .extendedHalo, .sosTapped:
            Text("No additional settings.")
                .font(theme.typography.font(.handFlow, size: 12))
                .foregroundColor(theme.palette.ink3)
        }
    }

    @ViewBuilder
    private var hubPicker: some View {
        if hubStore.hubs.isEmpty {
            Text("Add a hub first.")
                .foregroundColor(theme.palette.ink3)
        } else {
            Picker("Hub", selection: $hubId) {
                ForEach(hubStore.hubs) { hub in
                    Text(hub.name).tag(hub.id)
                }
            }
        }
    }

    private func toggleRow(label: String, color: Color, isSelected: Bool,
                            toggle: @escaping (UUID) -> Void, id: UUID) -> some View {
        HStack {
            Circle().fill(color).frame(width: 12, height: 12)
            Text(label)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill").foregroundColor(theme.palette.haloGreen)
            } else {
                Image(systemName: "circle").foregroundColor(theme.palette.ink3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { toggle(id) }
    }

    private func toggle(_ id: UUID, in set: inout [UUID]) {
        if let i = set.firstIndex(of: id) { set.remove(at: i) }
        else { set.append(id) }
    }

    private var modeExplanation: String {
        switch draft.notifyMode {
        case .quiet: return "♡ Status update only — appears in the feed, no buzz."
        case .headsUp: return "Soft haptic on the watch and a banner on the iPhone."
        case .critical: return "Breakthrough — alarm haptic, wakes the screen even with Do Not Disturb on."
        }
    }

    /// Empty name is fine — the trigger falls back to the live auto-name.
    /// Only require at least one affected Member.
    private var canSave: Bool {
        !draft.affectsMemberIds.isEmpty
    }

    /// Compose the live TriggerCondition from the editor's `conditionKind`
    /// + parameter state. Used both at save time and to compute the live
    /// auto-name placeholder.
    private func composedCondition() -> TriggerCondition {
        switch conditionKind {
        case .leavesHub:    return .leavesHub(hubId: hubId)
        case .entersHub:    return .entersHub(hubId: hubId)
        case .lateArriving: return .lateArrivingAtHub(hubId: hubId, byMinutes: byMinutes, expectedFromHubId: nil)
        case .awayFromAll:  return .awayFromAllHubs(forMinutes: awayMins)
        case .noPing:       return .noPing(forMinutes: noPingMins)
        case .batteryUnder: return .batteryUnder(percent: batteryPct)
        case .extendedHalo: return .extendedHalo
        case .sosTapped:    return .sosTapped
        }
    }

    private func save() {
        var updated = draft
        updated.condition = composedCondition()
        // Normalize: if the user-typed name exactly matches the freshly-
        // computed auto-name, store empty so the trigger keeps tracking
        // future content edits automatically.
        let trimmed = updated.name.trimmingCharacters(in: .whitespaces)
        let auto = updated.autoName(
            memberDisplayName: { familyStore.member($0)?.displayName },
            hubName: { id in hubStore.hubs.first(where: { $0.id == id })?.name },
            corridorName: { _ in nil },
            allWatchedMemberIds: familyStore.watchedMembers.map(\.id)
        )
        if trimmed == auto.trimmingCharacters(in: .whitespaces) {
            updated.name = ""
        }
        if triggerStore.triggers.contains(where: { $0.id == updated.id }) {
            triggerStore.update(updated)
        } else {
            triggerStore.add(updated)
        }
        dismiss()
    }
}
