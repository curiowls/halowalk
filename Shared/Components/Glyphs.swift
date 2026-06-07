import SwiftUI

/// The little arrow that points "this way home" — solid kite with an outline,
/// rotatable to any heading.
struct ArrowGlyph: View {
    @Environment(\.theme) var theme
    var size: CGFloat = 60
    var direction: Double = 0
    var color: Color? = nil

    var body: some View {
        let c = color ?? theme.palette.haloYellow
        ArrowGlyphShape()
            .fill(c)
            .overlay(
                ArrowGlyphShape().stroke(theme.palette.ink, lineWidth: 1.6)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(direction))
    }
}

private struct ArrowGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        // 4-point kite, mirroring the prototype's M30 8 L48 38 L30 30 L12 38 Z
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.13))
        p.addLine(to: CGPoint(x: w * 0.8, y: h * 0.63))
        p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.5))
        p.addLine(to: CGPoint(x: w * 0.2, y: h * 0.63))
        p.closeSubpath()
        return p
    }
}

struct StatusDot: View {
    @Environment(\.theme) var theme
    enum Status { case green, yellow, red, blue, neutral }
    var status: Status
    var size: CGFloat = 10

    var body: some View {
        let fill: Color = {
            switch status {
            case .green: return theme.palette.haloGreen
            case .yellow: return theme.palette.haloYellow
            case .red: return theme.palette.haloRed
            case .blue: return theme.palette.haloBlue
            case .neutral: return theme.palette.paper
            }
        }()
        return Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .overlay(Circle().stroke(theme.palette.line, lineWidth: 1.5))
    }
}

struct Chip: View {
    @Environment(\.theme) var theme
    let text: String
    var fill: Color? = nil
    var foreground: Color? = nil
    var border: Color? = nil

    var body: some View {
        Text(text)
            .font(theme.typography.font(.handTight, size: 11))
            .tracking(0.6)
            .foregroundColor(foreground ?? theme.palette.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(fill ?? theme.palette.paper)
            )
            .overlay(
                Capsule().stroke(border ?? theme.palette.line, lineWidth: 1.2)
            )
    }
}

struct Tag: View {
    @Environment(\.theme) var theme
    let text: String
    var fill: Color? = nil
    var foreground: Color? = nil

    var body: some View {
        Text(text.uppercased())
            .font(theme.typography.font(.handTight, size: 10))
            .tracking(1.0)
            .foregroundColor(foreground ?? theme.palette.ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(fill ?? theme.palette.paper))
            .overlay(Capsule().stroke(theme.palette.line, lineWidth: 1.2))
    }
}

/// Yellow-highlighted "post-it" speech bubble.
struct Bubble<Content: View>: View {
    @Environment(\.theme) var theme
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .font(theme.typography.font(.hand, size: 13))
            .sketchBorder(fill: theme.palette.highlightSoft, padding: 8)
    }
}

/// Squiggle decoration — the wavy underline used between sections.
struct Squiggle: View {
    @Environment(\.theme) var theme
    var width: CGFloat = 80
    var height: CGFloat = 8
    var body: some View {
        SquigglePath()
            .stroke(theme.palette.ink, lineWidth: 1.2)
            .frame(width: width, height: height)
    }
}

private struct SquigglePath: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height / 2
        p.move(to: CGPoint(x: 0, y: h))
        let segments = 8
        for i in 0..<segments {
            let x1 = w * CGFloat(i) / CGFloat(segments)
            let x2 = w * CGFloat(i + 1) / CGFloat(segments)
            let cy = i.isMultiple(of: 2) ? rect.minY : rect.maxY
            p.addQuadCurve(
                to: CGPoint(x: x2, y: h),
                control: CGPoint(x: (x1 + x2) / 2, y: cy)
            )
        }
        return p
    }
}

/// Sketchy underline-highlight for a word inside a sentence.
struct Underlined<Content: View>: View {
    @Environment(\.theme) var theme
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .padding(.horizontal, 4)
            .background(theme.palette.highlightSoft)
            .overlay(
                Rectangle()
                    .frame(height: 1.5)
                    .foregroundColor(theme.palette.ink),
                alignment: .bottom
            )
    }
}
