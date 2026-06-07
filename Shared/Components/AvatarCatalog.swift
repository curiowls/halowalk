import SwiftUI

/// 50 flat-style avatars bundled in `Assets.xcassets/Avatars/`. Members
/// pick one via `Member.avatarId`. We keep the catalog as a static list
/// so the picker UI can iterate in a stable order and SwiftUI previews
/// don't churn.
///
/// Attribution: "Designed by Flaticon" (free license with attribution).
/// Surfaced on the About screen.
enum AvatarCatalog {
    /// All 50 avatar ids, in catalog order (matches the source set's
    /// numbering 01–50).
    static let all: [String] = (1...50).map { String(format: "avatar-%02d", $0) }

    /// A reasonable default if no avatar has been picked yet.
    /// Returns a stable choice keyed off the member id so the same member
    /// always gets the same default avatar across re-renders.
    static func defaultAvatarId(for memberId: UUID) -> String {
        // hash the UUID into a stable 0–49 index
        let hash = abs(memberId.uuidString.hashValue)
        let index = hash % all.count
        return all[index]
    }

    /// Returns an Image if the asset exists, else nil. Callers fall back
    /// to the initial-in-circle when this returns nil (e.g. the asset
    /// catalog hasn't shipped yet in older builds).
    static func image(for avatarId: String?) -> Image? {
        guard let id = avatarId, all.contains(id) else { return nil }
        return Image(id)
    }
}
