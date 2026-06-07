import Foundation
import Combine

/// Holds the notification feed. Computed urgency drives the morphing tab icon.
@MainActor
final class NotificationStore: ObservableObject {
    static let shared = NotificationStore()

    @Published var notifications: [AppNotification] = []

    private static let key = "halowalk.notifications.v1"

    init() { load() }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: Self.key),
           let parsed = try? JSONDecoder().decode([AppNotification].self, from: d) {
            notifications = parsed
        } else {
            notifications = MockData.allNotifications
            save()
        }
    }

    private func save() {
        if let d = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(d, forKey: Self.key)
        }
    }

    // MARK: - Read

    var unread: [AppNotification] {
        notifications.filter { !$0.read && !$0.dismissed }
    }
    var visible: [AppNotification] {
        notifications.filter { !$0.dismissed }.sorted { $0.timestamp > $1.timestamp }
    }
    func count(of severity: AppNotification.Severity) -> Int {
        unread.filter { $0.severity == severity }.count
    }

    /// Highest unread severity right now — drives the tab icon morph.
    var dominantSeverity: AppNotification.Severity? {
        if count(of: .critical) > 0 { return .critical }
        if count(of: .headsUp) > 0 { return .headsUp }
        if count(of: .quiet) > 0 { return .quiet }
        return nil
    }

    // MARK: - Mutations

    func add(_ n: AppNotification) {
        notifications.insert(n, at: 0)
        save()
    }
    func markRead(_ id: UUID) {
        if let i = notifications.firstIndex(where: { $0.id == id }) {
            notifications[i].read = true
            save()
        }
    }
    func markAllRead() {
        for i in notifications.indices { notifications[i].read = true }
        save()
    }
    func dismiss(_ id: UUID) {
        if let i = notifications.firstIndex(where: { $0.id == id }) {
            notifications[i].dismissed = true
            save()
        }
    }
}
