import SwiftUI

extension Theme {
    /// Artisan / Craft — the default theme. Personal, nostalgic, warm.
    /// Visual language: washi-taped paper cards, hand-drawn marks,
    /// terracotta + sage + mustard on cream. Patrick Hand for headers,
    /// Quicksand for body text (handwriting is reserved for short
    /// strings — Quicksand keeps long copy readable).
    ///
    /// Spec source: docs/assets/HaloWalk Themes.html → ARTISAN constants
    /// in themes.jsx.
    static let artisan = Theme(
        id: "artisan",
        name: "Artisan",
        summary: "Heartfelt, keepsake, storybook. Like a note on the fridge.",
        palette: Palette(
            ink: Color(hex: 0x2B231D),          // warm dark ink (was 0x1A1714)
            ink2: Color(hex: 0x5B554C),
            ink3: Color(hex: 0x7A6F5E),
            paper: Color(hex: 0xFAF3E3),        // cream paper (was 0xFBF8F2)
            paper2: Color(hex: 0xFFFDF6),       // brighter card paper
            line: Color(hex: 0x3A322A),         // dark wash for borders
            lineSoft: Color(hex: 0xC8C2B3),
            haloGreen: Color(hex: 0x6F9A5E),    // sage
            haloYellow: Color(hex: 0xE8B15A),   // mustard
            haloRed: Color(hex: 0xC47B4A),      // terracotta (primary accent)
            haloBlue: Color(hex: 0x7A99B3),
            haloPink: Color(hex: 0xD99FB1),     // rosé
            accentJunior: Color(hex: 0xD99FB1),
            accentSenior: Color(hex: 0xE8B15A),
            highlightSoft: Color(hex: 0xFDF7E3)
        ),
        typography: Typography(
            // Patrick Hand for headers (legible script per spec).
            hand: "PatrickHand-Regular",
            handTight: "PatrickHand-Regular",
            // Caveat for flowing handwritten captions ("safe at base ♡").
            handFlow: "Caveat-Regular",
            mono: "Menlo",
            scale: 1.0
        ),
        geometry: Geometry(
            // Asymmetric "wobble" corners — the artisan signature.
            // Mirrors the prototype's CSS:
            //   border-radius: 10px 14px 12px 16px / 14px 10px 16px 12px
            wobbleCorners: [14, 18, 16, 20],
            wobbleVariance: 0.4,
            cardCornerBase: 16,
            allowTilt: true,
            shadowOffset: CGSize(width: 3, height: 3),
            shadowBlur: 0
        ),
        strokes: Strokes(
            thin: 1.0,
            regular: 1.5,
            thick: 2.5,
            dashed: [4, 4],
            dashedSoft: [3, 3]
        ),
        map: .sketch
    )
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

extension Theme {
    /// All shipping themes, surfaced in the Theme picker. Order matters —
    /// Artisan is first because it's the default.
    static var allRegistered: [Theme] {
        [.artisan, .modern, .playful]
    }
}
