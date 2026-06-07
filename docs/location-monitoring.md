# HaloWalk Location Monitoring Architecture

**Status:** shipped in Build 23.
**Owner:** anyone touching `LocationManager`, `LocationFidelityCoordinator`, `MonitoringPrefs`, `ContinuousWatchStore`, or any of the location-aware SwiftUI screens.

This document is the canonical reference for *why* HaloWalk's location subsystem is built the way it is. Read it before changing CL knobs, adding new monitoring services, or moving location calls between background and foreground.

---

## Why this exists

Build 22 used a single, naive configuration:

```swift
manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
manager.distanceFilter = 5
manager.pausesLocationUpdatesAutomatically = false
manager.allowsBackgroundLocationUpdates = true
manager.startUpdatingLocation()
```

Result: **~9% battery drain per day with zero foreground time.** That's worst-case Core Location: maximum precision + minimum distance filter + Apple's biggest auto-saver explicitly disabled. We were broadcasting "track me at maximum fidelity 24/7" when the product only needs that during active use.

Build 23 splits "what fidelity is needed right now?" from "how to make Core Location match." A central coordinator decides; the manager applies.

---

## The four tiers

```swift
enum LocationFidelity {
    case off                // app off / location denied
    case background         // visits + SLC + regions; ~near-zero battery
    case foregroundCoarse   // continuous, 100 m / 50 m, paused-when-stationary
    case foregroundFine     // continuous, 10 m / 10 m, paused-when-stationary
}
```

**Mapping to Core Location:**

| Tier | desiredAccuracy | distanceFilter | pausesAutomatically | What's running |
|---|---|---|---|---|
| `off` | — | — | — | nothing |
| `background` | irrelevant | irrelevant | true | visits + SLC + regions only |
| `foregroundCoarse` | 100 m | 50 m | true | continuous + visits + SLC + regions |
| `foregroundFine` | 10 m | 10 m | true | continuous + visits + SLC + regions |

**Critical invariant:** `pausesLocationUpdatesAutomatically = true` on every continuous tier. Apple's auto-pause is the single biggest battery saver Core Location offers. The reverse — turning it off — is what blew through 9% per day.

---

## The "always-on" backbone

Three CL services run whenever the tier is ≥ `background`. All three survive app termination via `UIApplicationLaunchOptionsLocationKey`, all three are near-zero battery, all three are event-driven so they don't poll.

### 1. Region monitoring (`startMonitoring(for: CLCircularRegion)`)

Per-hub geofence. Fires `didEnterRegion` / `didExitRegion` after the user crosses the boundary and stays on the other side for ~20 seconds. Drives:
- The "Andrew arrived at school" notification
- Continuous-watch `arrivesAtHub` / `leavesHub` resolution
- `LocationManager.insideHubIds` set

Updated on `HubStore` change via `MonitoringCoordinator`. iOS limit: 20 active regions per app.

### 2. Visit monitoring (`startMonitoringVisits`)

Apple's "most power-efficient way of gathering location data" (their words). Fires `didVisit` when the system detects an arrival or departure event with a built-in dwell threshold. Drives:
- Coarse "they got somewhere" pin updates
- A `recomputeContainment` pass against known hubs

iOS-only — watchOS doesn't expose visits. Watch relies on continuous updates while the watch app is foreground.

### 3. Significant location changes (`startMonitoringSignificantLocationChanges`)

Cell-tower-based breadcrumb. Fires every ~500 m of movement or ~5 min, no GPS involvement. Used by the Smart and Live profiles only — Minimal skips it because visits + regions cover the meaningful events without the modest extra drain.

iOS-only.

---

## The Coordinator

`LocationFidelityCoordinator` is the brain. It computes desired fidelity from five inputs:

1. **`MonitoringPrefs.profile`** — user choice of Minimal / Smart / Live. Sets the floor.
2. **Screen-boost counter** — incremented by `.locationAware()` view modifier on appear, decremented on disappear. Counter-based so overlapping screens don't fight on dismiss.
3. **Active outgoing continuous-watches** — `ContinuousWatchStore.watches(by: myMemberId)`. If non-empty, floor goes to `foregroundCoarse`.
4. **Incoming remote boosts** — `RemoteBoost` records received via `WatchSync` from paired devices. Each carries an expiry; pruned every 30 s.
5. **Quiet hours** — `QuietHoursPrefs.isInQuietHours()` + `pauseNonEssentialLocation`. Caps fidelity at `background` *unless* an outgoing watch or incoming boost is active (explicit intent overrides).

Pure-function compute. Re-runs whenever any input changes (Combine `$publisher` subscriptions) plus every 60 s for the quiet-hours minute boundary.

Output goes to `LocationManager.applyFidelity(_:profile:)`, which is idempotent.

---

## The two-layer design

```
┌─────────────────────────────────────────────────┐
│  SwiftUI views (.locationAware modifier)        │
│  Settings (MonitoringPrefs UI)                  │
│  ContinuousWatchSheet / ContinuousWatchBanner   │
└──────────────────┬──────────────────────────────┘
                   │ "I want at least foregroundCoarse"
                   │ "I started a watch on Andrew"
                   ▼
┌─────────────────────────────────────────────────┐
│  LocationFidelityCoordinator                    │
│   inputs:                                       │
│     • MonitoringPrefs.profile                   │
│     • screen-boost counter                      │
│     • ContinuousWatchStore.active               │
│     • ContinuousWatchStore.incomingBoosts       │
│     • QuietHoursPrefs                           │
│   output:                                       │
│     • currentFidelity (Published)               │
└──────────────────┬──────────────────────────────┘
                   │ applyFidelity(.foregroundCoarse, profile: .smart)
                   ▼
┌─────────────────────────────────────────────────┐
│  LocationManager                                │
│   • configures desiredAccuracy / distanceFilter │
│   • starts/stops continuous updates             │
│   • starts/stops visits + SLC                   │
│   • region monitoring (driven by HubStore)      │
│   • CLLocationManagerDelegate callbacks         │
└──────────────────┬──────────────────────────────┘
                   │ didUpdateLocations / didVisit / didEnter
                   ▼
┌─────────────────────────────────────────────────┐
│  PresenceStore (ingestion)                      │
│  TriggerEngine (hub entry/exit)                 │
│  ContinuousWatchStore.tick (resolution)         │
└─────────────────────────────────────────────────┘
```

**Rule:** views never touch `LocationManager` directly. They use `.locationAware()`. Likewise, nothing outside `LocationFidelityCoordinator` calls `applyFidelity` — the coordinator owns intent, the manager owns hardware.

---

## User-visible profiles

The `MonitoringProfile` enum is what shows up in **Settings → Behavior → Location & battery**:

| Profile | Background tier | Foreground tier | SLC? | Estimated drain |
|---|---|---|---|---|
| Minimal | `background` (visits + regions) | `foregroundCoarse` | no | ~1% / day |
| **Smart** *(default)* | `background` (visits + SLC + regions) | `foregroundCoarse` | yes | ~2–4% / day |
| Live | `foregroundCoarse` (continuous always) | `foregroundFine` | yes | ~8–12% / day |

Estimates are based on Apple's Energy Efficiency Guide and Life360's self-reported numbers (~10% with always-on). Replace with measured HaloWalk numbers once we have a few weeks of data across testers.

**Default for new + existing installs: Smart.** No migration banner — wearers being monitored is a given for the product; how aggressively isn't user-facing news.

---

## Screen-driven foreground bumps

The `.locationAware(_:)` SwiftUI modifier wraps any view that displays live location info:

```swift
struct FamilyTabView: View {
    var body: some View {
        ...
        .locationAware()                  // foregroundCoarse default
    }
}

struct GlanceTurnByTurnVariant: View {
    var body: some View {
        ...
        .locationAware(.foregroundFine)   // active navigation needs 10 m
    }
}
```

Screens currently wearing the modifier:

| Screen | Tier |
|---|---|
| `FamilyTabView` (list + map) | coarse |
| `HubsTabView` (list + map) | coarse |
| `MemberDetailView` | coarse |
| `HubsListVariant` (watch) | coarse |
| `GlanceTurnByTurnVariant` (watch) | fine |
| `GlanceArrowVariant` (watch) | fine |

**Not wearing it (intentional):** Notifications, More, Settings, Onboarding, watch QuickReply.

When adding new screens:
- Shows a map → `.locationAware()`
- Shows live distance / bearing to a person or place → `.locationAware()`
- Active turn-by-turn navigation → `.locationAware(.foregroundFine)`
- Static text with no live position info → don't add it

---

## Continuous Watching

User-initiated, time-bound fidelity boost on a specific watched member. Distinct from the profile (which is "how I broadcast my own location").

**Model:**

```swift
struct ContinuousWatch {
    let id: UUID
    let watcherId: UUID    // who initiated
    let watchedId: UUID    // whose location they want
    let until: UntilCondition
    let startedAt: Date
}

enum UntilCondition {
    case arrivesAtHub(hubId: UUID)
    case leavesHub(hubId: UUID)
    case untilTime(date: Date)
    case forDuration(seconds: TimeInterval)
    case manualStop
}
```

**UX:** Member detail → "Watch live" button → `ContinuousWatchSheet` picker → active `ContinuousWatchBanner` on member detail until resolved.

**Resolution:**
- `untilTime` / `forDuration` — checked by the 30 s `ContinuousWatchStore` prune timer.
- `arrivesAtHub` / `leavesHub` — checked when `LocationManager` receives `didEnterRegion` / `didExitRegion`.
- `manualStop` — never resolves automatically; user taps Stop on the banner.

**On resolution:** `LocationManager.notifyResolved` files a quiet `AppNotification` ("Andrew arrived at Home — your watch ended.").

**Effect on fidelity:**
1. Watcher's local device → fidelity goes to at least `foregroundCoarse` even with the app backgrounded.
2. Watched member's paired devices → `WatchSync.sendBoostRequest` queues a `boostRequest` userInfo payload. Receiving device honors it for `ttl` seconds.

**Quiet-hours interaction:** active continuous-watches override the quiet-hours cap. Explicit user intent (a guardian deliberately said "watch them now") wins over the policy default.

---

## Cross-device boost passing

When a guardian opens a location-aware screen, their device wants the watched members' devices to broadcast more frequently — otherwise the live pin is fresh on the guardian's side but the wearer's device hasn't sent anything new.

**Flow:**

1. `LocationFidelityCoordinator.recompute()` → `broadcastBoostIfNeeded()`
2. Compute the desired boost level: `foregroundFine` if any fine screen is up, `foregroundCoarse` if any coarse screen is up or an outgoing watch is active.
3. Throttle: re-send only when the level changes or > 4 min since last send (TTL is 5 min, so we re-up just before expiry).
4. `WatchSync.sendBoostRequest(forMemberIds: watched, fidelity: needed, ttl: 300)` → `transferUserInfo` payload `{ type: "boostRequest", forMemberIds, fidelity, expiresAt, ... }`
5. Receiving device's `WatchSync.session(_:didReceiveUserInfo:)` → `ingestBoostRequest` → `ContinuousWatchStore.addIncomingBoost`.
6. The receiver's coordinator picks up the change via `$incomingBoosts` subscription, recomputes, calls `applyFidelity`.

**What works in Build 23:**
- iPhone (paired) → Watch (Family Setup): **yes**, via WCSession.
- Watch → paired iPhone: **yes**, via WCSession.

**What doesn't work yet:**
- iPhone → another iPhone (e.g. Mom's phone watching Maya's phone): **no**, requires CloudKit family-shared zone. Hooks are in place; flip in Build 24.

**Boost cancellation:** when the local need drops to `background`, `sendBoostCancel` posts a `boostCancel` userInfo. Receivers drop boosts from that sender immediately rather than waiting for TTL.

---

## Quiet hours interaction

`QuietHoursPrefs.pauseNonEssentialLocation` (default on) gates the coordinator's fidelity ceiling during the configured window (default 9 pm – 7 am):

```
if inQuietHours
   && pauseNonEssentialLocation
   && no active outgoing continuous-watch
   && no active incoming boost
{
    desired = min(desired, .background)
}
```

Both the outgoing watch and the incoming boost are explicit signals — they override the policy. Region monitoring + visits still fire normally during quiet hours (they don't run continuous GPS, just react to events).

---

## Battery accounting

The numbers are estimates, not measurements. To validate them in production:

1. Pick a tester with a stable daily routine.
2. Lock them on one profile for 3+ days.
3. Read iOS Settings → Battery → HaloWalk for "Activity by Hour" — split between active and background.
4. Compare across testers / profiles.

Once we have data, update the labels in `MonitoringProfile.batteryEstimate` with measured ranges and add a footer note like "Measured across N pilot installs over X days."

---

## What to read next

- `Shared/Models/LocationFidelity.swift` — tier enum + CL config mapping.
- `Shared/Models/MonitoringProfile.swift` — the user-facing profile + tier mapping.
- `Shared/Models/ContinuousWatch.swift` — watch session model + resolution logic.
- `Shared/Services/LocationFidelityCoordinator.swift` — the brain.
- `Shared/Services/LocationManager.swift` — the hardware adapter.
- `Shared/Services/ContinuousWatchStore.swift` — persistence + tick.
- `Shared/Services/MonitoringPrefs.swift` — profile prefs + Combine publisher.
- `Shared/Services/QuietHoursPrefs.swift` — window + flags.
- `Shared/Services/WatchSync.swift` — search for `sendBoostRequest` / `ingestBoostRequest`.
- `Shared/Components/LocationAwareModifier.swift` — the SwiftUI modifier.
- `Guardian/More/LocationBatterySettingsView.swift` — the settings UI.
- `Guardian/Family/ContinuousWatchSheet.swift` / `ContinuousWatchBanner.swift` / `MemberDetailMap.swift` — the watch-live UX.

---

## Pitfalls and gotchas

- **Don't re-enable `pausesLocationUpdatesAutomatically = false`.** That single line was most of Build 22's drain.
- **Don't call `LocationManager.applyFidelity` outside the coordinator.** It will fight the coordinator on the next recompute.
- **Don't add `.locationAware()` to screens that don't show live position.** Drains battery for no benefit.
- **`pausesLocationUpdatesAutomatically` is iOS-only** — guard with `#if os(iOS)` if you copy the snippet to a watch path.
- **Visit monitoring is iOS-only** too. Watch backbone is region monitoring + (when foreground) continuous updates.
- **Region monitoring has a 20-region-per-app iOS limit.** If hub count exceeds that, `MonitoringCoordinator` needs a windowing strategy (currently hubs ≤ 20 in mock data; revisit when CloudKit family sync ships).
- **`transferUserInfo` is queued, not realtime.** A boost request can take seconds to arrive on a sleeping paired device. That's by design — boosts are best-effort, the local fidelity decision still works without them.
- **`CLBackgroundActivitySession` (iOS 17+)** is not yet wired. Build 24 candidate — would let foreground continuous updates persist for ~3 minutes after backgrounding (useful for "wearer puts wrist down briefly mid-walk").
- **Live Activity** is also Build 24 — that's where Dynamic Island / lock-screen "Watching Andrew · 0.4 mi from Home · Stop" lives.

---

## Future work (Build 24+)

- **CloudKit family-shared zone** so iPhone→iPhone boost broadcasts work. Today only iPhone↔Watch via WCSession.
- **Live Activity for active continuous-watches.** Lock-screen presence + Dynamic Island.
- **`CLBackgroundActivitySession`** for short post-background continuous-update extensions.
- **Per-hub quiet-hours exemption.** "Even at 11 pm, fire region updates for Grandma's house — Mom may need to go." Currently global only.
- **Measured battery numbers** to replace the estimates.
- **Adaptive profile.** "Auto" option that uses Smart most of the time but bumps to Live when the wearer is detected as moving (via SLC) and a guardian is on the family map.
