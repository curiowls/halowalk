import SwiftUI

extension Theme {
    /// Essential — calm, confident, effortless. The senior-friendly choice.
    /// Removes noise to focus on tracking data: high contrast, large touch
    /// targets, generous whitespace, persian blue accent. Inter for
    /// everything — humanist sans-serif designed for screen readability.
    ///
    /// We keep the internal id `"modern"` for back-compat with stored user
    /// prefs (UserDefaults entries that point at "modern"); the display
    /// name is what users see in the picker.
    ///
    /// Spec source: docs/assets/HaloWalk Themes.html → PRECISION constants
    /// in themes.jsx.
    static let modern = Theme(
        id: "modern",
        name: "Essential",
        summary: "High contrast, clear, direct. Built for clarity.",
        palette: Palette(
            ink: Color(hex: 0x0A0A0A),
            ink2: Color(hex: 0x5B6370),
            ink3: Color(hex: 0x8A93A0),
            paper: Color(hex: 0xFFFFFF),
            paper2: Color(hex: 0xF4F5F7),       // surface for cards
            line: Color(hex: 0x0D0D0D),
            lineSoft: Color(hex: 0xD8DDE5),
            haloGreen: Color(hex: 0x0A7D3C),    // semantic green
            haloYellow: Color(hex: 0xB88A00),   // semantic amber
            haloRed: Color(hex: 0xC8261D),      // semantic red
            haloBlue: Color(hex: 0x1C39BB),     // persian blue (primary accent)
            haloPink: Color(hex: 0xB85A8B),
            accentJunior: Color(hex: 0x1C39BB),
            accentSenior: Color(hex: 0x1C39BB),
            highlightSoft: Color(hex: 0xEEF1F6)
        ),
        typography: Typography(
            // Inter for everything per spec — different weights distinguish
            // headers from body. Resolved at runtime via Font.weight().
            hand: "Inter-Regular",
            handTight: "Inter-Bold",
            handFlow: "Inter-Regular",
            mono: "SFMono-Regular",
            // 10% larger than baseline — readability lever for seniors.
            scale: 1.1
        ),
        geometry: Geometry(
            // 4px corner radius — "tiny softness," not rounded.
            // Per user feedback in chat2.md: "use 4 pixels."
            wobbleCorners: [4, 4, 4, 4],
            wobbleVariance: 0,
            cardCornerBase: 4,
            // No tilt — everything stays orthogonal.
            allowTilt: false,
            shadowOffset: .zero,
            shadowBlur: 0
        ),
        strokes: Strokes(
            // Thicker strokes — visible at a glance.
            thin: 1.0,
            regular: 2.0,
            thick: 3.0,
            // Solid lines only.
            dashed: [],
            dashedSoft: []
        ),
        // Real MapKit — no sketchy overlay.
        map: .kit
    )
}
