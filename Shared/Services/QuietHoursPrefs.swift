import Foundation

/// Quiet hours suppress non-critical notifications during a recurring window.
/// Critical alerts always break through. Stored in UserDefaults so it
/// persists across launches and is accessible from both iOS and watchOS.
struct QuietHoursPrefs: Codable, Equatable {
    var enabled: Bool
    var startMinute: Int   // minutes from midnight, 0..1439
    var endMinute: Int

    /// Notifications below this severity are suppressed during quiet hours.
    /// Default: heads-up and quiet are suppressed; critical always breaks through.
    var allowDuringQuiet: AllowLevel

    /// Build 23: when true, the LocationFidelityCoordinator caps fidelity
    /// at `.background` during the quiet window — UNLESS an explicit
    /// ContinuousWatch is active for someone watched by/of this user.
    /// Default on; the user's example "9pm–7am most likely everyone is
    /// going to bed" matches this.
    var pauseNonEssentialLocation: Bool

    enum AllowLevel: String, Codable, CaseIterable {
        case criticalOnly       // strictest — only critical
        case headsUpAndCritical // suppress only quiet ♡
        case all                // disabled in effect
    }

    static let `default` = QuietHoursPrefs(
        enabled: true,
        startMinute: 21 * 60,    // 9pm
        endMinute: 7 * 60,       // 7am
        allowDuringQuiet: .criticalOnly,
        pauseNonEssentialLocation: true
    )

    /// Custom decode so pre-Build-23 stored payloads (which don't include
    /// `pauseNonEssentialLocation`) still decode cleanly with the default
    /// applied for the missing key.
    init(enabled: Bool, startMinute: Int, endMinute: Int,
         allowDuringQuiet: AllowLevel, pauseNonEssentialLocation: Bool) {
        self.enabled = enabled
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.allowDuringQuiet = allowDuringQuiet
        self.pauseNonEssentialLocation = pauseNonEssentialLocation
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try c.decode(Bool.self, forKey: .enabled)
        self.startMinute = try c.decode(Int.self, forKey: .startMinute)
        self.endMinute = try c.decode(Int.self, forKey: .endMinute)
        self.allowDuringQuiet = try c.decode(AllowLevel.self, forKey: .allowDuringQuiet)
        self.pauseNonEssentialLocation =
            (try c.decodeIfPresent(Bool.self, forKey: .pauseNonEssentialLocation)) ?? true
    }
    private enum CodingKeys: String, CodingKey {
        case enabled, startMinute, endMinute, allowDuringQuiet, pauseNonEssentialLocation
    }

    static let key = "halowalk.quiet_hours.v1"

    static func load() -> QuietHoursPrefs {
        if let d = UserDefaults.standard.data(forKey: key),
           let p = try? JSONDecoder().decode(QuietHoursPrefs.self, from: d) {
            return p
        }
        return .default
    }
    func save() {
        if let d = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(d, forKey: Self.key)
        }
    }

    /// Returns true if `now` falls within the quiet-hours window.
    func isInQuietHours(now: Date = Date()) -> Bool {
        guard enabled else { return false }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: now)
        let nowMin = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        if startMinute <= endMinute {
            return nowMin >= startMinute && nowMin < endMinute
        }
        // Overnight window (e.g. 9pm → 7am).
        return nowMin >= startMinute || nowMin < endMinute
    }
}
