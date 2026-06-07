import Foundation
import Combine

/// Computes the *desired* location-services fidelity for this device,
/// from a small set of inputs:
///   • The user's monitoring profile (Minimal / Smart / Live)
///   • How many location-aware screens are currently foregrounded
///   • Whether any continuous-watch sessions are active for this user
///   • Boost requests received from paired devices
///   • Quiet hours
///
/// Pushes the resulting `LocationFidelity` into the `LocationManager`,
/// which knows how to map a tier into actual CLLocationManager state.
@MainActor
final class LocationFidelityCoordinator: ObservableObject {
    static let shared = LocationFidelityCoordinator()

    /// Requested fidelity, after collapsing all inputs. Read-only.
    @Published private(set) var currentFidelity: LocationFidelity = .background

    /// Number of foreground "I need at least foregroundCoarse" requesters
    /// (location-aware screens currently visible). When > 0, fidelity is
    /// at least foregroundCoarse.
    @Published private(set) var coarseScreenBoostCount: Int = 0
    /// Same, but for foregroundFine (active watch Glance navigation).
    @Published private(set) var fineScreenBoostCount: Int = 0

    private var cancellables = Set<AnyCancellable>()
    private var quietRecheckTimer: Timer?

    /// Tracks the last fidelity we asked our paired devices to honor, so
    /// we don't spam transferUserInfo on every screen tick.
    private var lastBroadcastBoost: LocationFidelity = .background
    private var lastBoostSentAt: Date = .distantPast

    private init() {}

    /// Wire up subscriptions. Call once at app launch from each app's
    /// deferredActivations.
    func start() {
        // Recompute on any input change.
        MonitoringPrefs.shared.$profile
            .sink { [weak self] _ in self?.recompute() }
            .store(in: &cancellables)
        ContinuousWatchStore.shared.$active
            .sink { [weak self] _ in self?.recompute() }
            .store(in: &cancellables)
        ContinuousWatchStore.shared.$incomingBoosts
            .sink { [weak self] _ in self?.recompute() }
            .store(in: &cancellables)
        // Quiet-hours window crosses time boundaries, so re-evaluate
        // every minute. Cheap.
        quietRecheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.recompute() }
        }
        recompute()
    }

    // MARK: - Screen boost API
    // Wired by the .locationAware() view modifier. Counter-based so two
    // overlapping screens don't fight each other on dismiss.

    func acquireScreenBoost(_ fidelity: LocationFidelity) {
        switch fidelity {
        case .foregroundFine: fineScreenBoostCount += 1
        case .foregroundCoarse: coarseScreenBoostCount += 1
        case .off, .background: break
        }
        recompute()
    }
    func releaseScreenBoost(_ fidelity: LocationFidelity) {
        switch fidelity {
        case .foregroundFine: fineScreenBoostCount = max(0, fineScreenBoostCount - 1)
        case .foregroundCoarse: coarseScreenBoostCount = max(0, coarseScreenBoostCount - 1)
        case .off, .background: break
        }
        recompute()
    }

    // MARK: - Compute

    /// Single-source-of-truth fidelity calculation. Pure function of
    /// (profile, screenBoosts, watches, incomingBoosts, quietHours).
    private func recompute() {
        let profile = MonitoringPrefs.shared.profile
        let prefs = QuietHoursPrefs.load()
        let inQuiet = prefs.isInQuietHours()
        let myMemberId = FamilyStore.shared.account.memberId

        // Active continuous-watches initiated by this user — explicit
        // intent that overrides quiet hours.
        let myWatches = ContinuousWatchStore.shared.watches(by: myMemberId)
        let hasActiveOutgoingWatch = !myWatches.isEmpty

        // Highest incoming boost targeting this user (i.e. someone else
        // is asking us to broadcast more frequently).
        let incomingFidelity = ContinuousWatchStore.shared
            .incomingBoostFidelity(forMemberId: myMemberId) ?? .background

        // Start at the profile's background floor.
        var desired: LocationFidelity = profile.backgroundFidelity

        // Foreground screen boosts.
        if fineScreenBoostCount > 0 {
            desired = max(desired, .foregroundFine)
        } else if coarseScreenBoostCount > 0 {
            desired = max(desired, profile.foregroundFidelity)
        }

        // Active outgoing watches always push to at least foregroundCoarse
        // for the watcher's own device (so the map stays fresh while the
        // watch is on).
        if hasActiveOutgoingWatch {
            desired = max(desired, .foregroundCoarse)
        }

        // Incoming boost from a paired device.
        desired = max(desired, incomingFidelity)

        // Quiet-hours cap. Active outgoing watches and incoming boosts
        // both override (explicit intent + cross-device requests both
        // reflect a real "I need to know" signal).
        if inQuiet, prefs.pauseNonEssentialLocation,
           !hasActiveOutgoingWatch,
           incomingFidelity == .background {
            desired = min(desired, .background)
        }

        // Apply.
        if desired != currentFidelity {
            currentFidelity = desired
            LocationManager.shared.applyFidelity(desired, profile: profile)
        }

        // Cross-device boost broadcast. When *this* device wants
        // foreground fidelity (e.g. user is on the family map, or has
        // active continuous-watches), ask paired devices to bump their
        // outbound fidelity for the watched members. Build 23: only
        // iPhone↔Watch over WCSession; iPhone↔iPhone in Build 24.
        broadcastBoostIfNeeded()
    }

    /// Throttled broadcast: only re-send when the desired boost level
    /// changes OR more than 4 minutes have elapsed (TTL is 5 min).
    private func broadcastBoostIfNeeded() {
        let myId = FamilyStore.shared.account.memberId
        // Members this user is currently watching (the "interesting set").
        let watched = FamilyStore.shared.watches(by: myId).map(\.id)
        guard !watched.isEmpty else {
            // No one to boost. Cancel any prior boost.
            if lastBroadcastBoost != .background {
                WatchSync.shared.sendBoostCancel()
                lastBroadcastBoost = .background
            }
            return
        }

        // Decide what to ask paired devices for.
        let needed: LocationFidelity = {
            if fineScreenBoostCount > 0 { return .foregroundFine }
            if coarseScreenBoostCount > 0 || !ContinuousWatchStore.shared.watches(by: myId).isEmpty {
                return .foregroundCoarse
            }
            return .background
        }()

        if needed == .background {
            if lastBroadcastBoost != .background {
                WatchSync.shared.sendBoostCancel()
                lastBroadcastBoost = .background
            }
            return
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(lastBoostSentAt)
        let levelChanged = needed != lastBroadcastBoost
        guard levelChanged || elapsed > 240 else { return }

        WatchSync.shared.sendBoostRequest(
            forMemberIds: watched,
            fidelity: needed,
            ttl: 5 * 60
        )
        lastBroadcastBoost = needed
        lastBoostSentAt = now
    }
}

