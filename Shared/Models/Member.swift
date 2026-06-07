import Foundation
import SwiftUI

/// A person in the family. Roles are now derived from `Relationship` edges
/// (who-watches-whom), not stored on the Member. A single Member can both
/// watch others and be watched themselves (e.g. an older sibling).
struct Member: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var displayName: String
    var birthday: Date? = nil
    var pronouns: String? = nil

    var initial: String
    var accentColorHex: UInt32
    var avatarSystemImage: String? = nil
    /// Build 25: id of a bundled illustration in the Avatars asset catalog
    /// (e.g. "avatar-03"). When set, the UI shows the image instead of the
    /// initial-in-circle. Falls back to `initial` if nil or asset missing.
    var avatarId: String? = nil

    /// Each Member picks their own preferred theme. Stored as Theme.id.
    var preferredThemeId: String

    /// Stable Sign in with Apple subject for this person, when they have
    /// joined the family from their own Apple ID.
    var appleUserId: String? = nil

    /// Explicit location-sharing choice for this person's own devices.
    /// nil means legacy/default-on for pre-Build-C members.
    var locationSharingEnabled: Bool? = nil

    var accentColor: Color { Color(hex: accentColorHex) }
    var sharesLocation: Bool { locationSharingEnabled ?? true }

    var ageYears: Int? {
        guard let bd = birthday else { return nil }
        return Calendar.current.dateComponents([.year], from: bd, to: Date()).year
    }

    /// Resolved theme, falls back to artisan if id is missing.
    var preferredTheme: Theme {
        Theme.allRegistered.first { $0.id == preferredThemeId } ?? .artisan
    }
}
