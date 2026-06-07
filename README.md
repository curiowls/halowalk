# HaloWalk

SwiftUI implementation of the HaloWalk wireframes. Two targets in one Xcode
project: an iOS Guardian app for parents/family, and a watchOS Watcher app for
the kid or senior wearing the watch.

The visual language is **theme-driven**. The first theme — `Sketch` — matches
the heartwarming hand-drawn wireframes. The architecture supports up to 5
themes; pickers in both apps surface them once registered.

## Setup

```bash
brew install xcodegen           # one-time
./Scripts/setup.sh              # fetch fonts + generate HaloWalk.xcodeproj
open HaloWalk.xcodeproj
```

Then in Xcode:

1. Select the **HaloWalk** target → Signing & Capabilities → set your Apple Developer team.
2. Repeat for the **HaloWalk Watch App** target.
3. Build & run. Selecting an iPhone with a paired Apple Watch will install both apps; on a real iPhone+Watch pair, the Watcher installs to the Watch automatically.

## Project layout

```
HaloWalk/
├── project.yml                  # XcodeGen config — defines both targets
├── Scripts/
│   ├── setup.sh                 # one-shot setup
│   └── fetch-fonts.sh           # downloads Kalam, Caveat, Architects Daughter
├── Resources/Fonts/             # populated by fetch-fonts.sh
├── Shared/                      # compiled into both targets
│   ├── Theme/
│   │   ├── Theme.swift          # Theme struct (the design-token contract)
│   │   ├── SketchTheme.swift    # the heartwarming sketch theme
│   │   └── ThemeManager.swift   # @Published active theme + variant prefs
│   ├── Components/              # WobbleShape, HaloRing, ArrowGlyph, etc.
│   ├── Models/                  # Person, Hub, Trigger, AppNotification
│   └── Mock/                    # MockData for the pilot
├── Guardian/                    # iOS-only target
│   ├── App/                     # HaloWalkApp, RootTabView, SectionHeader
│   ├── HubCreator/              # Map-first / List+sliders / Constellation
│   ├── StatusBoard/             # Family cards / Shared map / Today's timeline
│   ├── Triggers/                # Sentence / Recipes / Quiet toggles
│   ├── Notifications/           # Lock-screen / Severity feed / Single focused
│   ├── Respond/                 # Quick reply / Nudge home / Head out (panic)
│   └── Settings/                # SettingsSheet (theme picker)
└── Watcher/                     # watchOS-only target
    ├── App/                     # HaloWalkWatchApp, WatchRoot
    ├── QuickTapHubs/            # LAUNCH SCREEN — 3 swipe variants + ⚙ icon
    ├── Glance/                  # Turn-by-turn / Hi-contrast / Friendly
    ├── Wandering/               # +1 mi halo / Three choices / Countdown
    └── Settings/                # WatchSettingsView (theme + variant defaults)
```

## Theme system

A theme is a single `Theme` value (see `Shared/Theme/Theme.swift`) that bundles:

- `palette` — ink, paper, halo colors, accents
- `typography` — four font roles (body / display / flow script / mono) + scale
- `geometry` — wobble corner radii, drop-shadow offsets, tilt allowance
- `strokes` — line widths and dash patterns
- `map` — `.sketch` (hand-drawn fake map), `.kit` (real MapKit), or `.kitTextured`

To add a new theme:

1. Define a new `Theme` instance (e.g. `Theme.modernFlat`) in
   `Shared/Theme/<Name>Theme.swift`.
2. Add it to `Theme.allRegistered` in `SketchTheme.swift`.
3. Both the watch ⚙ menu and the Guardian settings sheet pick it up automatically.

The design conversation suggested 3–5 total themes targeting both senior and
youth aesthetics — the registration list reserves slots for four more, with
"Coming soon" placeholder rows in the Guardian picker.

### Theming maps

- `.sketch` → renders our hand-drawn `SketchMapView` with squiggle roads, halo rings, and pin glyphs. No real geodata.
- `.kit` → real MapKit (iOS only). Per the design conversation, only the *controls and overlays* are themed; the map tiles themselves stay native.
- `.kitTextured` → MapKit with a multiply-blend overlay layer for a softer, more sketch-like feel.

watchOS (currently) always renders the sketch map regardless of theme — the
`MapContent` builder API is iOS 17+ only. This is documented at the
`#if os(watchOS)` branch in `Shared/Components/SketchMap.swift`.

## Variants

Every screen ships **all three variants** from the design exploration. Per the
chat transcript:

> "Instead of picking one out of ABC version and implementing it, I'm
> considering implementing three screens for each state that the user can
> choose to interact with. Over time, we will learn which one is the
> preferred mode."

- **Watch**: 3 swipe variants per screen via `TabView(.page)`. Selected page
  is persisted in `VariantPrefs` so the app reopens to your preferred surface.
- **iOS**: same pattern — each tab wraps its 3 variants in a paged TabView,
  with a small variant label + dot indicator at the top so you always know
  which sketch you're looking at.

`Settings → Default variants` (watch) and the variant indicator (iOS) let you
pick the default. Pilot telemetry on which variant gets used most should
inform the eventual default.

## Where the design came from

- `chats/chat1.md` — the design conversation, including the Watch v2 changes
  (Glance A → turn-by-turn, Hubs C → time-aware Suggested, Wander A →
  enlarge halo) and the Notifications/Respond expansion.
- `HaloWalk Wireframes.html` and the `*.jsx` files were the React/Babel
  prototype the user iterated against. Visual decisions in this Swift
  implementation match those files; the behaviors there were prototype-only,
  this is the real app.

## Pilot caveats

- The app now has real local location reporting, WatchConnectivity, local
  notifications, and CloudKit sync paths. `Shared/Mock/MockData.swift` is still
  the bootstrap/demo family until a real family share is accepted.
- Custom fonts gracefully fall back to system rounded if the .ttf files are
  missing — but for the heartwarming feel, run `Scripts/fetch-fonts.sh` first.
- WatchConnectivity is wired for iPhone↔Watch family/app context, watch
  location readings, quick replies, and fidelity boost requests. iPhone↔iPhone
  boost requests remain a CloudKit backlog item.
- CloudKit owner solo sync and Build C family sharing use the
  `iCloud.com.halowalk.guardian` container. TestFlight requires Development
  schema changes to be deployed to Production after any schema change.
