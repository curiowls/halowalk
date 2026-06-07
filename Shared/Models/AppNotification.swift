import Foundation

/// What lands in the Guardian's Notifications tab. Includes light "♡" pings
/// alongside heads-ups and critical alerts.
struct AppNotification: Identifiable, Codable, Hashable {
    let id: UUID
    var severity: Severity
    var category: Category
    var title: String
    var body: String
    var timestamp: Date

    /// The Member this notification is about (e.g. Maya wandered).
    var aboutMemberId: UUID?
    /// The Trigger that caused this, if any (system messages have nil).
    var triggeredByTriggerId: UUID?
    /// What respond action this notification suggests as the primary CTA.
    var suggestedRespond: RespondKind?

    var read: Bool
    var dismissed: Bool

    enum Severity: String, Codable, CaseIterable {
        case quiet      // ♡ low-priority, no urgency
        case headsUp    // attention-worthy but not alarming
        case critical   // immediate attention required
    }

    enum Category: String, Codable {
        case enteredHalo
        case leftHalo
        case extendedHalo
        case wanderingTooLong
        case lateArriving
        case offCorridor
        case noPingFromWatch
        case watchBatteryLow
        case wearerResponded
        case wearerHeadingTowardGuardian
        case devicesDiverged       // new in Build 12a
        case sos
        case system
    }

    enum RespondKind: String, Codable, CaseIterable {
        case quickReply
        case nudgeHome
        case headOut
    }

    static func == (lhs: AppNotification, rhs: AppNotification) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
