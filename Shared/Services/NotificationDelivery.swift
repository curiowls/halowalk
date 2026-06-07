import Foundation
import UserNotifications
import UIKit

/// Wraps UNUserNotificationCenter for HaloWalk's local notifications. The
/// TriggerEngine calls `deliver(_:)` whenever a trigger fires; this class
/// handles permission state and severity-appropriate delivery.
@MainActor
final class NotificationDelivery: NSObject, ObservableObject {
    static let shared = NotificationDelivery()

    @Published var authorization: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
        refresh()
    }

    func refresh() {
        center.getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.authorization = settings.authorizationStatus
            }
        }
    }

    /// Ask once. iOS shows the system prompt if state is .notDetermined.
    func requestPermission() async {
        do {
            // Request critical alerts too — the design's "set & forget"
            // promise relies on critical alerts breaking through silent mode.
            // Apple gates this entitlement; for the pilot we request without
            // criticalAlert so it works without the entitlement.
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refresh()
            _ = granted
        } catch {
            // Ignored — refresh() will reflect the resulting state.
            await refresh()
        }
    }

    /// Deliver a local notification corresponding to an AppNotification that
    /// was just appended to the feed. Severity drives how disruptive it is.
    /// Suppressed during quiet hours per the user's preference, except for
    /// critical alerts which always break through.
    func deliver(_ notification: AppNotification) {
        guard authorization == .authorized || authorization == .provisional else { return }
        if isSuppressedByQuietHours(notification.severity) { return }

        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.userInfo = ["notificationId": notification.id.uuidString]

        switch notification.severity {
        case .critical:
            content.interruptionLevel = .timeSensitive
            content.sound = .defaultCritical
        case .headsUp:
            content.interruptionLevel = .active
            content.sound = .default
        case .quiet:
            content.interruptionLevel = .passive
            content.sound = nil
        }

        // Categorize so iOS can present a system action set if we add one
        // later (e.g. "Reply", "Nudge home", "Head out" buttons).
        switch notification.suggestedRespond {
        case .quickReply: content.categoryIdentifier = "halowalk.respond.quickReply"
        case .nudgeHome:  content.categoryIdentifier = "halowalk.respond.nudgeHome"
        case .headOut:    content.categoryIdentifier = "halowalk.respond.headOut"
        case .none:       break
        }

        // Fire immediately.
        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: nil
        )
        center.add(request) { _ in /* errors silent for pilot */ }
    }

    /// Returns true if the given severity should be suppressed right now
    /// per the user's QuietHoursPrefs.
    private func isSuppressedByQuietHours(_ severity: AppNotification.Severity) -> Bool {
        let prefs = QuietHoursPrefs.load()
        guard prefs.enabled else { return false }
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let nowMin = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        let inWindow: Bool
        if prefs.startMinute <= prefs.endMinute {
            inWindow = nowMin >= prefs.startMinute && nowMin < prefs.endMinute
        } else {
            // Overnight window (e.g. 9pm → 7am)
            inWindow = nowMin >= prefs.startMinute || nowMin < prefs.endMinute
        }
        guard inWindow else { return false }

        switch prefs.allowDuringQuiet {
        case .all:                return false
        case .headsUpAndCritical: return severity == .quiet
        case .criticalOnly:       return severity != .critical
        }
    }
}

extension NotificationDelivery: UNUserNotificationCenterDelegate {
    /// Show notification banners even while the app is foregrounded — useful
    /// during pilot testing to verify trigger fires.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Tapping the banner opens HaloWalk. Build 12 will route deep-links
        // to the relevant Notification Detail / Respond view.
        completionHandler()
    }
}
