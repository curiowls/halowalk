import Foundation

/// A family is the unit of sharing. One family shares a set of hubs, corridors,
/// and triggers across all guardians' devices. In Build 7 this maps to a
/// CloudKit shared zone.
struct Family: Identifiable, Codable {
    let id: UUID
    var name: String
    var organizerId: UUID            // the Member who set up the family
    var memberIds: [UUID]            // all guardians + wearers
    var createdAt: Date
}

/// The currently signed-in account on this device. The Member referenced by
/// this account is who the app "represents" when reading/writing locations,
/// sending messages, etc.
struct Account: Codable {
    var memberId: UUID               // links to a Member in the family
    var email: String?               // populated by Sign in with Apple
    var deviceKind: DeviceKind
    /// Stable Sign in with Apple user identifier. Same value across all of
    /// this user's devices for this app — the durable key we'll use to
    /// match a CloudKit family-share participant in Build B. Optional so
    /// pre-Build-A stored accounts decode cleanly.
    var appleUserId: String?

    /// Members this local account has chosen not to show in family views.
    /// This is intentionally account-local, not shared through CloudKit.
    var hiddenMemberIds: [UUID]

    enum DeviceKind: String, Codable {
        case iPhone        // Guardian device
        case appleWatch    // Wearer device
    }

    init(
        memberId: UUID,
        email: String?,
        deviceKind: DeviceKind,
        appleUserId: String? = nil,
        hiddenMemberIds: [UUID] = []
    ) {
        self.memberId = memberId
        self.email = email
        self.deviceKind = deviceKind
        self.appleUserId = appleUserId
        self.hiddenMemberIds = hiddenMemberIds
    }

    private enum CodingKeys: String, CodingKey {
        case memberId, email, deviceKind, appleUserId, hiddenMemberIds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        memberId = try c.decode(UUID.self, forKey: .memberId)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        deviceKind = try c.decode(DeviceKind.self, forKey: .deviceKind)
        appleUserId = try c.decodeIfPresent(String.self, forKey: .appleUserId)
        hiddenMemberIds = try c.decodeIfPresent([UUID].self, forKey: .hiddenMemberIds) ?? []
    }
}
