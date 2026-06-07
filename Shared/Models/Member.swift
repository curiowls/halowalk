import Foundation
import SwiftUI

/// A person in the family. Roles are now derived from `Relationship` edges
/// (who-watches-whom), not stored on the Member. A single Member can both
/// watch others and be watched themselves (e.g. an older sibling).
struct Member: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var displayName: String
    var birthday: Date?
    var pronouns: String?

    var initial: String
    var accentColorHex: UInt32
    var avatarSystemImage: String?
    /// Build 25: id of a bundled illustration in the Avatars asset catalog
    /// (e.g. "avatar-03"). When set, the UI shows the image instead of the
    /// initial-in-circle. Falls back to `initial` if nil or asset missing.
    var avatarId: String?

    /// Each Member picks their own preferred theme. Stored as Theme.id.
    var preferredThemeId: String

    var accentColor: Color { Color(hex: accentColorHex) }

    var ageYears: Int? {
        guard let bd = birthday else { return nil }
        return Calendar.current.dateComponents([.year], from: bd, to: Date()).year
    }

    /// Resolved theme, falls back to artisan if id is missing.
    var preferredTheme: Theme {
        Theme.allRegistered.first { $0.id == preferredThemeId } ?? .artisan
    }
}
