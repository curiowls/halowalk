import SwiftUI

extension Theme {
    /// Playful — high-energy, social, rewarding. The kids/youth choice.
    /// Visual language: neubrutalism — chunky 2.5px black borders, 4px
    /// hard offset shadows, vibrant gradients. Fredoka One for headers,
    /// Nunito for body — both bouncy, both friendly, both very readable.
    ///
    /// Per the design chat: pink as the primary accent was replaced with
    /// **tangerine** (#FF8A3D) for gender neutrality. Pink is still in the
    /// palette but isn't the lead.
    ///
    /// Spec source: docs/assets/HaloWalk Themes.html → ENERGETIC constants
    /// in themes.jsx.
    static let playful = Theme(
        id: "playful",
        name: "Playful",
        summary: "Vivid, dynamic, expressive. Built for kids and youth.",
        palette: Palette(
            ink: Color(hex: 0x1A1A1A),          // hard black, neubrutal
            ink2: Color(hex: 0x3B3B3B),
            ink3: Color(hex: 0x7A7A7A),
            paper: Color(hex: 0xFFF8E7),        // cream
            paper2: Color(hex: 0xFFFFFF),
            line: Color(hex: 0x1A1A1A),         // hard black borders
            lineSoft: Color(hex: 0xC8C8C8),
            haloGreen: Color(hex: 0x7CD87C),    // lime
            haloYellow: Color(hex: 0xFFD23F),   // sun yellow
            haloRed: Color(hex: 0xFF8A3D),      // tangerine (primary accent)
            haloBlue: Color(hex: 0x5CE1E6),     // cyan
            haloPink: Color(hex: 0xFF79C6),     // hot pink (secondary, watch band)
            accentJunior: Color(hex: 0xFF8A3D), // tangerine
            accentSenior: Color(hex: 0xB07CFF), // purple
            highlightSoft: Color(hex: 0xFFD23F)
        ),
        typography: Typography(
            // Fredoka One for "bouncy" display headers.
            hand: "FredokaOne-Regular",
            handTight: "FredokaOne-Regular",
            // Nunito for body — rounded, friendly, readable.
            handFlow: "Nunito-Regular",
            mono: "Menlo",
            scale: 1.05
        ),
        geometry: Geometry(
            // Neubrutal cards: chunky rounded rectangles, no asymmetry.
            // The "personality" comes from the borders + offset shadow,
            // not from wobble.
            wobbleCorners: [18, 18, 18, 18],
            wobbleVariance: 0,
            cardCornerBase: 18,
            allowTilt: true,                    // playful tilt still on
            shadowOffset: CGSize(width: 4, height: 4),
            shadowBlur: 0                       // hard shadow, no blur
        ),
        strokes: Strokes(
            // Heavier strokes — neubrutalist 2.5px borders.
            thin: 1.5,
            regular: 2.5,
            thick: 3.5,
            dashed: [5, 4],
            dashedSoft: [3, 3]
        ),
        map: .sketch
    )
}
