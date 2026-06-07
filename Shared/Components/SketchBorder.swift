import SwiftUI

/// View modifier — wraps content in the sketchy paper-like border. Themes that
/// don't want a wobbly hand-drawn look can override the shape via a different
/// theme's `geometry.wobbleCorners` (or a future theme can replace this with
/// a flat `RoundedRectangle`).
struct SketchBorderStyle: ViewModifier {
    @Environment(\.theme) var theme

    var seed: Int = 0
    var dashed: Bool = false
    var thick: Bool = false
    var fill: Color? = nil
    var padding: CGFloat = 10
    var dropShadow: Bool = false

    func body(content: Content) -> some View {
        let shape = WobbleShape(corners: theme.geometry.wobbleCorners, seed: seed)
        let stroke = thick ? theme.strokes.thick : theme.strokes.regular
        return content
            .padding(padding)
            .background(
                shape.fill(fill ?? theme.palette.paper)
            )
            .overlay(
                shape.stroke(
                    dashed ? theme.palette.lineSoft : theme.palette.line,
                    style: StrokeStyle(
                        lineWidth: stroke,
                        dash: dashed ? theme.strokes.dashed : []
                    )
                )
            )
            .compositingGroup()
            .shadow(
                color: dropShadow ? theme.palette.line.opacity(0.95) : .clear,
                radius: theme.geometry.shadowBlur,
                x: dropShadow ? theme.geometry.shadowOffset.width : 0,
                y: dropShadow ? theme.geometry.shadowOffset.height : 0
            )
    }
}

extension View {
    func sketchBorder(
        seed: Int = 0,
        dashed: Bool = false,
        thick: Bool = false,
        fill: Color? = nil,
        padding: CGFloat = 10,
        shadow: Bool = false
    ) -> some View {
        modifier(SketchBorderStyle(
            seed: seed, dashed: dashed, thick: thick, fill: fill,
            padding: padding, dropShadow: shadow
        ))
    }

    /// Slight rotation utility — only applied when the theme allows it.
    func sketchTilt(_ degrees: Double) -> some View {
        modifier(SketchTilt(degrees: degrees))
    }
}

struct SketchTilt: ViewModifier {
    @Environment(\.theme) var theme
    let degrees: Double
    func body(content: Content) -> some View {
        content.rotationEffect(.degrees(theme.geometry.allowTilt ? degrees : 0))
    }
}
