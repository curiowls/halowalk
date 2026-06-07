import Foundation
import CoreLocation

/// Seed dataset for the pilot. The Wong family lives in Belmont, CA.
///
/// Build 12a notes:
///  • Roles are now derived from `Relationship` edges, not `Member.role`.
///  • Devices are first-class: a Member can have phone + watch, with each
///    publishing its own LocationReading.
///  • The mock family covers every interesting permutation:
///     – Tiger:   guardian only · iPhone + Watch (paired, not separate cellular)
///     – Audrey:  guardian only · iPhone only
///     – Andrew:  wearer only · Apple Watch only (Family Setup)
///     – Maya:    HYBRID — watched by parents AND watches Andrew · iPhone + Watch
///     – Lou:     wearer only · iPhone only (no watch) — senior with phone
enum MockData {

    // MARK: - Members

    static let tigerId = UUID(uuidString: "11111111-1111-1111-1111-000000000001")!
    static let audreyId = UUID(uuidString: "11111111-1111-1111-1111-000000000002")!
    static let andrewId = UUID(uuidString: "11111111-1111-1111-1111-000000000003")!
    static let mayaId = UUID(uuidString: "11111111-1111-1111-1111-000000000004")!
    static let louId = UUID(uuidString: "11111111-1111-1111-1111-000000000005")!

    static let tiger = Member(
        id: tigerId, name: "Chelsea Huang", displayName: "Chelsea",
        birthday: nil, pronouns: "she/her", initial: "C",
        accentColorHex: 0x6A8DB3, avatarSystemImage: "person.fill",
        avatarId: "avatar-02",
        preferredThemeId: "artisan"
    )
    static let audrey = Member(
        id: audreyId, name: "Audrey Wong", displayName: "Audrey",
        birthday: nil, pronouns: "she/her", initial: "A",
        accentColorHex: 0xD99FB1, avatarSystemImage: "person.fill",
        avatarId: "avatar-16",
        preferredThemeId: "artisan"
    )
    static let andrew = Member(
        id: andrewId, name: "Andrew Wong", displayName: "Andrew",
        birthday: birthday(yearsAgo: 7), pronouns: "he/him", initial: "A",
        accentColorHex: 0x5A9D6E, avatarSystemImage: "figure.child",
        avatarId: "avatar-08",
        preferredThemeId: "playful"
    )
    static let maya = Member(
        id: mayaId, name: "Maya Wong", displayName: "Maya",
        birthday: birthday(yearsAgo: 12), pronouns: "she/her", initial: "M",
        accentColorHex: 0xD99FB1, avatarSystemImage: "figure.child",
        avatarId: "avatar-37",
        preferredThemeId: "playful"
    )
    static let lou = Member(
        id: louId, name: "Grandpa Lou", displayName: "Lou",
        birthday: birthday(yearsAgo: 78), pronouns: "he/him", initial: "L",
        accentColorHex: 0xE8B94A, avatarSystemImage: "figure.older",
        avatarId: "avatar-09",
        preferredThemeId: "modern"
    )

    static let allMembers: [Member] = [tiger, audrey, andrew, maya, lou]

    // MARK: - Relationships
    // Tiger watches Andrew, Maya, Lou.
    // Audrey watches Andrew, Maya, Lou.
    // Maya watches Andrew (older sibling watching younger).
    // No one watches Tiger or Audrey.

    static let allRelationships: [Relationship] = [
        Relationship(id: UUID(), watcherId: tigerId, watchedId: andrewId, label: "Dad watches Andrew", createdAt: daysAgo(60)),
        Relationship(id: UUID(), watcherId: tigerId, watchedId: mayaId,   label: "Dad watches Maya",   createdAt: daysAgo(60)),
        Relationship(id: UUID(), watcherId: tigerId, watchedId: louId,    label: "Tiger watches Lou",  createdAt: daysAgo(60)),
        Relationship(id: UUID(), watcherId: audreyId, watchedId: andrewId, label: "Mom watches Andrew", createdAt: daysAgo(60)),
        Relationship(id: UUID(), watcherId: audreyId, watchedId: mayaId,   label: "Mom watches Maya",   createdAt: daysAgo(60)),
        Relationship(id: UUID(), watcherId: audreyId, watchedId: louId,    label: "Audrey watches Lou", createdAt: daysAgo(60)),
        Relationship(id: UUID(), watcherId: mayaId,   watchedId: andrewId, label: "Maya watches Andrew",createdAt: daysAgo(30)),
    ]

    // MARK: - Devices

    static let tigerPhoneId = UUID(uuidString: "22222222-3333-1111-1111-000000000001")!
    static let tigerWatchId = UUID(uuidString: "22222222-3333-1111-1111-000000000002")!
    static let audreyPhoneId = UUID(uuidString: "22222222-3333-1111-1111-000000000003")!
    static let andrewWatchId = UUID(uuidString: "22222222-3333-1111-1111-000000000004")!
    static let mayaPhoneId = UUID(uuidString: "22222222-3333-1111-1111-000000000005")!
    static let mayaWatchId = UUID(uuidString: "22222222-3333-1111-1111-000000000006")!
    static let louPhoneId = UUID(uuidString: "22222222-3333-1111-1111-000000000007")!

    static let allDevices: [Device] = [
        Device(id: tigerPhoneId, memberId: tigerId, kind: .iPhone, displayName: "Chelsea's iPhone", hasCellularData: true, isOnWrist: nil, lastSeenAt: minsAgo(1), batteryPercent: 92),
        Device(id: tigerWatchId, memberId: tigerId, kind: .appleWatch, displayName: "Chelsea's Apple Watch", hasCellularData: false, isOnWrist: true, lastSeenAt: minsAgo(2), batteryPercent: 71),
        Device(id: audreyPhoneId, memberId: audreyId, kind: .iPhone, displayName: "Audrey's iPhone", hasCellularData: true, isOnWrist: nil, lastSeenAt: minsAgo(6), batteryPercent: 64),
        Device(id: andrewWatchId, memberId: andrewId, kind: .appleWatch, displayName: "Andrew's Apple Watch", hasCellularData: true, isOnWrist: true, lastSeenAt: minsAgo(35), batteryPercent: 78),
        Device(id: mayaPhoneId, memberId: mayaId, kind: .iPhone, displayName: "Maya's iPhone", hasCellularData: true, isOnWrist: nil, lastSeenAt: minsAgo(2), batteryPercent: 64),
        Device(id: mayaWatchId, memberId: mayaId, kind: .appleWatch, displayName: "Maya's Apple Watch", hasCellularData: false, isOnWrist: false, lastSeenAt: minsAgo(120), batteryPercent: 23),
        Device(id: louPhoneId, memberId: louId, kind: .iPhone, displayName: "Lou's iPhone", hasCellularData: true, isOnWrist: nil, lastSeenAt: minsAgo(4), batteryPercent: 41),
    ]

    // MARK: - Family

    static let familyId = UUID(uuidString: "44444444-2222-2222-2222-000000000001")!
    static let family = Family(
        id: familyId,
        name: "The Wong Family",
        organizerId: tigerId,
        memberIds: allMembers.map(\.id),
        createdAt: Date()
    )

    static let myAccount = Account(
        memberId: tigerId,
        email: "chelsea@example.com",
        deviceKind: .iPhone
    )

    // MARK: - Hubs (Belmont, CA)

    static let homeId = UUID(uuidString: "33333333-3333-3333-3333-000000000001")!
    static let ciprianiId = UUID(uuidString: "33333333-3333-3333-3333-000000000002")!
    static let ralstonId = UUID(uuidString: "33333333-3333-3333-3333-000000000003")!
    static let carlmontId = UUID(uuidString: "33333333-3333-3333-3333-000000000004")!
    static let libraryId = UUID(uuidString: "33333333-3333-3333-3333-000000000005")!
    static let communityCenterId = UUID(uuidString: "33333333-3333-3333-3333-000000000006")!
    static let grandmaId = UUID(uuidString: "33333333-3333-3333-3333-000000000007")!

    // Coordinates correspond to the actual Belmont, CA addresses.
    // (Mock data only — real hubs come from MKLocalSearch / current GPS,
    // which always returns coords matching the address.)
    static let allHubs: [Hub] = [
        // Mid-Reposo Way (between the 3602 and 3612 blocks). The 3608
        // address gives CLGeocoder a precise mid-block point so the pin
        // lands on the actual house cluster, not at the street's end.
        Hub(id: homeId, name: "Home", icon: "house.fill",
            address: "3608 Reposo Way, Belmont, CA 94002",
            latitude: 37.5142, longitude: -122.2929,
            haloRadiusMeters: 80, colorHex: 0x5A9D6E,
            assignedMemberIds: [andrewId, mayaId, louId],
            createdById: tigerId, createdAt: daysAgo(60),
            notes: "All three watched-Members' base."),
        Hub(id: ciprianiId, name: "Cipriani Elementary", icon: "graduationcap.fill",
            address: "2525 Buena Vista Ave, Belmont, CA",
            latitude: 37.5197, longitude: -122.2996,
            haloRadiusMeters: 90, colorHex: 0x6A8DB3,
            assignedMemberIds: [andrewId],
            createdById: tigerId, createdAt: daysAgo(60), notes: nil),
        Hub(id: ralstonId, name: "Ralston Middle", icon: "graduationcap.fill",
            address: "2675 Ralston Ave, Belmont, CA",
            latitude: 37.5176, longitude: -122.2978,
            haloRadiusMeters: 90, colorHex: 0x6A8DB3,
            assignedMemberIds: [mayaId],
            createdById: audreyId, createdAt: daysAgo(45), notes: nil),
        Hub(id: carlmontId, name: "Carlmont High", icon: "graduationcap.fill",
            address: "1400 Alameda de las Pulgas, Belmont, CA",
            latitude: 37.5082, longitude: -122.2942,
            haloRadiusMeters: 90, colorHex: 0x6A8DB3,
            assignedMemberIds: [],
            createdById: tigerId, createdAt: daysAgo(30),
            notes: "Saved for when Maya starts high school."),
        Hub(id: libraryId, name: "Belmont Library", icon: "books.vertical.fill",
            address: "1110 Alameda de las Pulgas, Belmont, CA",
            latitude: 37.5136, longitude: -122.2939,
            haloRadiusMeters: 60, colorHex: 0xD99FB1,
            assignedMemberIds: [andrewId, mayaId],
            createdById: tigerId, createdAt: daysAgo(40), notes: nil),
        Hub(id: communityCenterId, name: "Belmont Community Ctr", icon: "music.note.house.fill",
            address: "1225 Ralston Ave, Belmont, CA",
            latitude: 37.5177, longitude: -122.2929,
            haloRadiusMeters: 90, colorHex: 0xE8B94A,
            assignedMemberIds: [andrewId, mayaId, louId],
            createdById: audreyId, createdAt: daysAgo(20),
            notes: "Community programs for all ages."),
        Hub(id: grandmaId, name: "Grandma's House", icon: "heart.fill",
            address: "Belmont, CA", latitude: 37.5230, longitude: -122.2890,
            haloRadiusMeters: 70, colorHex: 0xE8B94A,
            assignedMemberIds: [andrewId, mayaId, louId],
            createdById: tigerId, createdAt: daysAgo(50),
            notes: "Lou stops by every Wednesday."),
    ]

    // MARK: - Corridors

    static let homeToCipriani = Corridor(
        id: UUID(), name: "Home ↔ Cipriani",
        fromHubId: homeId, toHubId: ciprianiId,
        assignedMemberIds: [andrewId],
        maxDurationMinutes: 12,
        pathLatitudes: [], pathLongitudes: []
    )
    static let homeToRalston = Corridor(
        id: UUID(), name: "Home ↔ Ralston",
        fromHubId: homeId, toHubId: ralstonId,
        assignedMemberIds: [mayaId],
        maxDurationMinutes: 15,
        pathLatitudes: [], pathLongitudes: []
    )
    static let homeToLibrary = Corridor(
        id: UUID(), name: "Home ↔ Library",
        fromHubId: homeId, toHubId: libraryId,
        assignedMemberIds: [andrewId, mayaId],
        maxDurationMinutes: 10,
        pathLatitudes: [], pathLongitudes: []
    )
    static let allCorridors: [Corridor] = [homeToCipriani, homeToRalston, homeToLibrary]

    // MARK: - Triggers

    static let allTriggers: [Trigger] = [
        Trigger(id: UUID(), name: "Andrew late from Cipriani",
                affectsMemberIds: [andrewId],
                condition: .lateArrivingAtHub(hubId: homeId, byMinutes: 15, expectedFromHubId: ciprianiId),
                notifyMode: .headsUp, notifyMemberIds: [tigerId, audreyId],
                deviceSource: .primary, enabled: true, createdAt: daysAgo(45)),
        Trigger(id: UUID(), name: "Maya wandering 20+ min",
                affectsMemberIds: [mayaId],
                condition: .awayFromAllHubs(forMinutes: 20),
                notifyMode: .headsUp, notifyMemberIds: [tigerId, audreyId],
                deviceSource: .primary, enabled: true, createdAt: daysAgo(40)),
        Trigger(id: UUID(), name: "Lou leaves all halos",
                affectsMemberIds: [louId],
                condition: .awayFromAllHubs(forMinutes: 5),
                notifyMode: .critical, notifyMemberIds: [tigerId, audreyId],
                deviceSource: .primary, enabled: true, createdAt: daysAgo(50)),
        Trigger(id: UUID(), name: "Andrew's watch low battery",
                affectsMemberIds: [andrewId],
                condition: .batteryUnder(percent: 20),
                notifyMode: .quiet, notifyMemberIds: [tigerId],
                deviceSource: .onlyAppleWatch, enabled: true, createdAt: daysAgo(30)),
        Trigger(id: UUID(), name: "Anyone arrives Home",
                affectsMemberIds: [andrewId, mayaId, louId],
                condition: .entersHub(hubId: homeId),
                notifyMode: .quiet, notifyMemberIds: [tigerId, audreyId],
                deviceSource: .primary, enabled: true, createdAt: daysAgo(20)),
        Trigger(id: UUID(), name: "SOS — anyone",
                affectsMemberIds: [andrewId, mayaId, louId],
                condition: .sosTapped,
                notifyMode: .critical, notifyMemberIds: [tigerId, audreyId],
                deviceSource: .anyDevice, enabled: true, createdAt: daysAgo(60)),
        Trigger(id: UUID(), name: "Maya's devices diverged",
                affectsMemberIds: [mayaId],
                condition: .devicesDiverged(meters: 100),
                notifyMode: .headsUp, notifyMemberIds: [tigerId, audreyId],
                deviceSource: .anyDevice, enabled: true, createdAt: daysAgo(10)),
    ]

    // MARK: - Notifications

    static let allNotifications: [AppNotification] = [
        AppNotification(id: UUID(), severity: .critical, category: .leftHalo,
                        title: "Lou left all halos",
                        body: "0.4 mi from Grandma's house. Last ping 4 min ago.",
                        timestamp: minsAgo(4),
                        aboutMemberId: louId, triggeredByTriggerId: nil,
                        suggestedRespond: .headOut, read: false, dismissed: false),
        AppNotification(id: UUID(), severity: .headsUp, category: .extendedHalo,
                        title: "Andrew enlarged his halo",
                        body: "+1 mi · still exploring near Belmont Library ♡",
                        timestamp: minsAgo(8),
                        aboutMemberId: andrewId, triggeredByTriggerId: nil,
                        suggestedRespond: .quickReply, read: false, dismissed: false),
        AppNotification(id: UUID(), severity: .headsUp, category: .devicesDiverged,
                        title: "Maya's phone and watch are apart",
                        body: "Phone at home, watch at Belmont Park (320 m).",
                        timestamp: minsAgo(11),
                        aboutMemberId: mayaId, triggeredByTriggerId: nil,
                        suggestedRespond: .quickReply, read: false, dismissed: false),
        AppNotification(id: UUID(), severity: .headsUp, category: .lateArriving,
                        title: "Maya late from Ralston",
                        body: "Home expected 15 min ago — currently 0.3 mi out.",
                        timestamp: minsAgo(12),
                        aboutMemberId: mayaId, triggeredByTriggerId: nil,
                        suggestedRespond: .nudgeHome, read: false, dismissed: false),
        AppNotification(id: UUID(), severity: .quiet, category: .enteredHalo,
                        title: "Andrew arrived Home",
                        body: "Safe at base ♡",
                        timestamp: minsAgo(35),
                        aboutMemberId: andrewId, triggeredByTriggerId: nil,
                        suggestedRespond: nil, read: true, dismissed: false),
        AppNotification(id: UUID(), severity: .quiet, category: .watchBatteryLow,
                        title: "Maya's watch is at 23%",
                        body: "Charging suggested.",
                        timestamp: minsAgo(95),
                        aboutMemberId: mayaId, triggeredByTriggerId: nil,
                        suggestedRespond: nil, read: true, dismissed: false),
        AppNotification(id: UUID(), severity: .quiet, category: .wearerHeadingTowardGuardian,
                        title: "Lou is heading toward you",
                        body: "0.6 mi away · about 12 min walking.",
                        timestamp: minsAgo(140),
                        aboutMemberId: louId, triggeredByTriggerId: nil,
                        suggestedRespond: .quickReply, read: true, dismissed: false),
        AppNotification(id: UUID(), severity: .quiet, category: .system,
                        title: "Welcome to HaloWalk",
                        body: "Your first hub is set. The family is connected.",
                        timestamp: hoursAgo(48),
                        aboutMemberId: nil, triggeredByTriggerId: nil,
                        suggestedRespond: nil, read: true, dismissed: false),
    ]

    // MARK: - Live readings (per device)
    // Maya's phone is at home (she stayed in) but her watch is at Belmont
    // Park (someone took it for a walk?) — illustrates divergence detection.

    static let initialReadings: [LocationReading] = [
        // Chelsea (the local user) is intentionally NOT seeded here.
        // The iPhone's real CLLocationManager updates are the canonical
        // source of truth for "me" — once IPhoneLocationReporter ingests
        // its first fix, Chelsea's pin appears at the actual location.
        // Seeding her at a fake coord made the pin look stuck even when
        // GPS was working ("Tiger's location never moved").
        // Audrey — out running an errand
        LocationReading(memberId: audreyId, deviceId: audreyPhoneId,
                        latitude: 37.5165, longitude: -122.2925,
                        horizontalAccuracy: 10, timestamp: minsAgo(6),
                        inHubId: nil, state: .wandering,
                        batteryPercent: 64, isOnWrist: nil, isMoving: true),
        // Andrew — at Home (just arrived)
        LocationReading(memberId: andrewId, deviceId: andrewWatchId,
                        latitude: 37.5180, longitude: -122.2960,
                        horizontalAccuracy: 8, timestamp: minsAgo(35),
                        inHubId: homeId, state: .inHalo,
                        batteryPercent: 78, isOnWrist: true, isMoving: false),
        // Maya — phone at home, watch at the park (DIVERGED)
        LocationReading(memberId: mayaId, deviceId: mayaPhoneId,
                        latitude: 37.5180, longitude: -122.2960,
                        horizontalAccuracy: 8, timestamp: minsAgo(2),
                        inHubId: homeId, state: .inHalo,
                        batteryPercent: 64, isOnWrist: nil, isMoving: false),
        LocationReading(memberId: mayaId, deviceId: mayaWatchId,
                        latitude: 37.5125, longitude: -122.2895,  // ~320 m away
                        horizontalAccuracy: 12, timestamp: minsAgo(11),
                        inHubId: nil, state: .wandering,
                        batteryPercent: 23, isOnWrist: false, isMoving: false),
        // Lou — out for a walk near Grandma's
        LocationReading(memberId: louId, deviceId: louPhoneId,
                        latitude: 37.5215, longitude: -122.2870,
                        horizontalAccuracy: 15, timestamp: minsAgo(4),
                        inHubId: nil, state: .leftOrbit,
                        batteryPercent: 41, isOnWrist: nil, isMoving: true),
    ]

    static let belmontRegion = CLLocationCoordinate2D(latitude: 37.5180, longitude: -122.2950)

    // MARK: - Helpers

    private static func daysAgo(_ d: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -d, to: Date()) ?? Date()
    }
    private static func hoursAgo(_ h: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: -h, to: Date()) ?? Date()
    }
    private static func minsAgo(_ m: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: -m, to: Date()) ?? Date()
    }
    private static func birthday(yearsAgo: Int) -> Date {
        Calendar.current.date(byAdding: .year, value: -yearsAgo, to: Date()) ?? Date()
    }
}
