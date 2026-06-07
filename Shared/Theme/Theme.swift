import SwiftUI

/// All visual tokens for a HaloWalk theme. New themes plug in by creating
/// another instance of this struct.
struct Theme: Identifiable, Equatable {
    let id: String
    let name: String
    let summary: String

    let palette: Palette
    let typography: Typography
    let geometry: Geometry
    let strokes: Strokes
    let map: MapStyle

    struct Palette: Equatable {
        let ink: Color
        let ink2: Color
        let ink3: Color
        let paper: Color
        let paper2: Color
        let line: Color
        let lineSoft: Color

        let haloGreen: Color
        let haloYellow: Color
        let haloRed: Color
        let haloBlue: Color
        let haloPink: Color

        let accentJunior: Color
        let accentSenior: Color

        let highlightSoft: Color
    }
}

extension Theme.Palette {
    /// Watch-side colors. OLED watch screens look better with dark
    /// backgrounds (better battery, better readability), so we invert
    /// the iPhone palette for the watch surfaces.
    var watchBackground: Color { ink }
    var watchForeground: Color { paper }
    var watchSurface: Color { ink2 }
    var watchSurfaceBorder: Color { lineSoft }
    var watchMuted: Color { Color(.sRGB, red: 0.65, green: 0.62, blue: 0.58, opacity: 1) }
}

extension Theme {

    struct Typography: Equatable {
        /// Body / general purpose
        let hand: String
        /// Display / titles — slightly tighter
        let handTight: String
        /// Flowing script — captions, annotations
        let handFlow: String
        let mono: String

        let scale: CGFloat
    }

    struct Geometry: Equatable {
        /// Asymmetric corner radii for the wobble border, normalized 0-1
        let wobbleCorners: [CGFloat]
        /// How much to randomize per-instance (0 = uniform, 1 = chaotic)
        let wobbleVariance: CGFloat
        let cardCornerBase: CGFloat
        /// Slight rotation utilities applied to artboard cards
        let allowTilt: Bool
        let shadowOffset: CGSize
        let shadowBlur: CGFloat
    }

    struct Strokes: Equatable {
        let thin: CGFloat
        let regular: CGFloat
        let thick: CGFloat
        let dashed: [CGFloat]
        let dashedSoft: [CGFloat]
    }

    enum MapStyle: String, Equatable {
        /// Hand-drawn SVG-style fake map (Sketch theme)
        case sketch
        /// Real MapKit, theme only the controls/overlays
        case kit
        /// MapKit with custom overlay textures
        case kitTextured
    }
}

extension Theme.Typography {
    func font(_ family: FontFamily, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch family {
        case .hand: name = hand
        case .handTight: name = handTight
        case .handFlow: name = handFlow
        case .mono: name = mono
        }
        // SwiftUI falls back to the system font if the named font isn't bundled,
        // so the app still runs without the .ttf assets — typography just won't
        // match the sketch aesthetic until fonts are installed.
        return Font.custom(name, size: size * scale).weight(weight)
    }

    enum FontFamily { case hand, handTight, handFlow, mono }
}
