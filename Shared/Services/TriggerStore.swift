import Foundation
import Combine

/// Triggers configured by the family. Lives under the ··· menu, not a tab,
/// because users edit these rarely (typically during onboarding).
@MainActor
final class TriggerStore: ObservableObject {
    static let shared = TriggerStore()

    @Published var triggers: [Trigger] = []

    private static let key = "halowalk.triggers.v1"

    init() { load() }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: Self.key),
           let parsed = try? JSONDecoder().decode([Trigger].self, from: d) {
            triggers = Self.recover(from: parsed)
        } else {
            triggers = MockData.allTriggers
            save()
        }
    }

    /// Self-heal corrupted state from previous Build 11–13 crash loop.
    /// Build 11/12/13 had a bug where TriggersListView's "+ New trigger"
    /// NavigationLink mutated the store inside its destination closure,
    /// causing an infinite-add loop until the watchdog fired. The result:
    /// some users' UserDefaults contains hundreds or thousands of empty
    /// triggers. Detect that here and reset to seed.
    private static func recover(from raw: [Trigger]) -> [Trigger] {
        // Dedupe by id (defensive — shouldn't happen but doesn't hurt).
        var seen: Set<UUID> = []
        let unique = raw.filter { seen.insert($0.id).inserted }

        // If the count is unreasonable for a real family, the array is
        // certainly corrupt from the crash loop. Reset to seed.
        if unique.count > 100 {
            let resurrected = MockData.allTriggers
            UserDefaults.standard.set(
                try? JSONEncoder().encode(resurrected),
                forKey: TriggerStore.key
            )
            return resurrected
        }

        // Drop any obviously-junk triggers (empty name + default condition).
        let filtered = unique.filter { trigger in
            !(trigger.name.trimmingCharacters(in: .whitespaces).isEmpty
              && trigger.affectsMemberIds.isEmpty
              && !trigger.enabled)
        }
        return filtered
    }

    private func save() {
        if let d = try? JSONEncoder().encode(triggers) {
            UserDefaults.standard.set(d, forKey: Self.key)
        }
    }

    func add(_ t: Trigger) { triggers.append(t); save() }
    func update(_ t: Trigger) {
        if let i = triggers.firstIndex(where: { $0.id == t.id }) {
            triggers[i] = t; save()
        }
    }
    func remove(_ id: UUID) {
        triggers.removeAll { $0.id == id }
        save()
    }
    func toggle(_ id: UUID) {
        if let i = triggers.firstIndex(where: { $0.id == id }) {
            triggers[i].enabled.toggle()
            save()
        }
    }
}
