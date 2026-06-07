import SwiftUI

/// Asymmetric rounded rectangle — corners have different radii to mimic
/// the hand-drawn `border-radius: 14px 18px 16px 20px / 18px 14px 20px 16px`
/// trick from the prototype's CSS.
struct WobbleShape: Shape {
    var topLeft: CGFloat
    var topRight: CGFloat
    var bottomRight: CGFloat
    var bottomLeft: CGFloat

    init(corners: [CGFloat] = [14, 18, 16, 20], seed: Int = 0) {
        // Tiny per-instance variance so consecutive cards don't look identical.
        // Callers pass arbitrary Int hashes — clamp before any arithmetic so
        // we never trip Swift's overflow trap when the seed happens to be a
        // large hashValue.
        let safeSeed = seed & 0xFFFF
        let jitter: (Int) -> CGFloat = { i in
            let v = sin(Double(safeSeed &* 7 &+ i &* 13)) * 1.6
            return CGFloat(v)
        }
        let trimmed = corners + Array(repeating: CGFloat(16), count: max(0, 4 - corners.count))
        self.topLeft     = max(2, trimmed[0] + jitter(0))
        self.topRight    = max(2, trimmed[1] + jitter(1))
        self.bottomRight = max(2, trimmed[2] + jitter(2))
        self.bottomLeft  = max(2, trimmed[3] + jitter(3))
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        // Clamp so we never overshoot a tiny rect
        let tl = min(topLeft, w/2, h/2)
        let tr = min(topRight, w/2, h/2)
        let br = min(bottomRight, w/2, h/2)
        let bl = min(bottomLeft, w/2, h/2)

        p.move(to: CGPoint(x: tl, y: 0))
        p.addLine(to: CGPoint(x: w - tr, y: 0))
        p.addQuadCurve(to: CGPoint(x: w, y: tr), control: CGPoint(x: w, y: 0))
        p.addLine(to: CGPoint(x: w, y: h - br))
        p.addQuadCurve(to: CGPoint(x: w - br, y: h), control: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: bl, y: h))
        p.addQuadCurve(to: CGPoint(x: 0, y: h - bl), control: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: 0, y: tl))
        p.addQuadCurve(to: CGPoint(x: tl, y: 0), control: CGPoint(x: 0, y: 0))
        p.closeSubpath()
        return p
    }
}
