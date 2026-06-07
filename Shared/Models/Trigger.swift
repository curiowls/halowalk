import Foundation

/// A "set & forget" rule the family configures.
struct Trigger: Identifiable, Codable {
    let id: UUID
    var name: String
    /// Members whose location triggers this rule. Renamed from
    /// `affectsWearerIds` — a Member of any role may be the subject.
    var affectsMemberIds: [UUID]
    var condition: TriggerCondition
    var notifyMode: NotifyMode
    /// Members who get pinged when this rule fires. Renamed from
    /// `notifyGuardianIds` — anyone in a watcher relationship can receive.
    var notifyMemberIds: [UUID]
    /// Per-trigger override for which device's reading to evaluate. Default
    /// is `.primary` (resolver picks one); the rare power-user override is
    /// to lock to a specific device kind.
    var deviceSource: DeviceSource
    var enabled: Bool
    var createdAt: Date

    enum NotifyMode: String, Codable {
        case quiet
        case headsUp
        case critical
    }

    enum DeviceSource: Codable, Hashable {
        case primary               // resolver picks the most-likely-on-person device
        case anyDevice             // fires on any device crossing
        case onlyiPhone            // power user: only iPhone reading triggers
        case onlyAppleWatch        // power user: only watch reading triggers
    }
}

extension Trigger {
    /// Live human-readable name derived from the condition + member list.
    /// Used as the placeholder in the editor and as the displayed title
    /// when the user-typed `name` is empty. When the user has set a custom
    /// `name`, this auto-name still surfaces as a subtitle so the trigger's
    /// actual behavior is never hidden by a stale custom label.
    func autoName(
        memberDisplayName: (UUID) -> String?,
        hubName: (UUID) -> String?,
        corridorName: (UUID) -> String?,
        allWatchedMemberIds: [UUID]
    ) -> String {
        // Subject label
        let allWatchedSet = Set(allWatchedMemberIds)
        let affectedSet = Set(affectsMemberIds)
        let subject: String
        if affectsMemberIds.isEmpty || (affectedSet == allWatchedSet && !allWatchedSet.isEmpty) {
            subject = "Anyone"
        } else {
            let names = affectsMemberIds.compactMap(memberDisplayName)
            subject = names.isEmpty ? "Anyone" : names.joined(separator: ", ")
        }
        // Action / condition phrase
        let action = condition.summary(
            resolvingHub: hubName,
            resolvingCorridor: corridorName
        )
        return "\(subject) — \(action)"
    }

    /// What to show as the title in lists. Falls back to the auto-name when
    /// the user hasn't customized.
    func displayTitle(
        memberDisplayName: (UUID) -> String?,
        hubName: (UUID) -> String?,
        corridorName: (UUID) -> String?,
        allWatchedMemberIds: [UUID]
    ) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        return autoName(
            memberDisplayName: memberDisplayName,
            hubName: hubName,
            corridorName: corridorName,
            allWatchedMemberIds: allWatchedMemberIds
        )
    }
}

enum TriggerCondition: Codable, Hashable {
    case leavesHub(hubId: UUID)
    case entersHub(hubId: UUID)
    case lateArrivingAtHub(hubId: UUID, byMinutes: Int, expectedFromHubId: UUID?)
    case awayFromAllHubs(forMinutes: Int)
    case offCorridor(corridorId: UUID)
    case noPing(forMinutes: Int)
    case batteryUnder(percent: Int)
    case extendedHalo
    case sosTapped
    /// New in Build 12a: fires when a Member's devices diverge by >100m.
    case devicesDiverged(meters: Int)

    func summary(resolvingHub: (UUID) -> String?, resolvingCorridor: (UUID) -> String?) -> String {
        switch self {
        case .leavesHub(let id):
            return "leaves \(resolvingHub(id) ?? "a hub")"
        case .entersHub(let id):
            return "enters \(resolvingHub(id) ?? "a hub")"
        case .lateArrivingAtHub(let id, let mins, _):
            return "doesn't reach \(resolvingHub(id) ?? "destination") within \(mins) min"
        case .awayFromAllHubs(let mins):
            return "away from all hubs for \(mins) min"
        case .offCorridor(let id):
            return "leaves \(resolvingCorridor(id) ?? "the corridor")"
        case .noPing(let mins):
            return "no ping for \(mins) min"
        case .batteryUnder(let pct):
            return "watch battery under \(pct)%"
        case .extendedHalo:
            return "extends their halo"
        case .sosTapped:
            return "taps SOS"
        case .devicesDiverged(let m):
            return "phone and watch are \(m)+ m apart"
        }
    }
}
