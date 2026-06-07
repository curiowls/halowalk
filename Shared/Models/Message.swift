import Foundation

/// A small message sent between guardian and wearer — quick replies, nudges,
/// "help is on the way" pings. Distinct from system AppNotifications.
struct Message: Identifiable, Codable {
    let id: UUID
    var fromMemberId: UUID
    var toMemberId: UUID
    var kind: Kind
    var body: String                  // resolved text (template + var subs)
    var sentAt: Date
    var deliveredAt: Date?
    var readAt: Date?

    enum Kind: String, Codable {
        case quickReply        // "Have fun ♡", "be back by 5pm"
        case nudgeHome         // "Ready to head home?" with watch CTA
        case helpOnTheWay      // sent automatically when guardian taps "Head Out"
    }
}
