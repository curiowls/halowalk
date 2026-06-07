# Fonts

Run `../../Scripts/fetch-fonts.sh` to populate this directory with the
sketch theme's typography:

- Kalam (Light, Regular, Bold) — body / general purpose
- Caveat (Regular, Bold) — flowing-script captions
- Architects Daughter (Regular) — display / titles

All three are SIL Open Font License (free for commercial use). They are
listed in `project.yml`'s `UIAppFonts` so iOS/watchOS register them at
launch — no additional code needed.

If a .ttf is missing the app still runs; SwiftUI falls back to a system
rounded font and the sketch aesthetic degrades gracefully.
