import SwiftUI

/// A ring with a dashed track and a solid arc for progress.
/// Used on the watch faces, the wandering countdown, and as the "halo motif"
/// throughout the app.
struct HaloRing<Content: View>: View {
    @Environment(\.theme) var theme

    let size: CGFloat
    let progress: Double
    let color: Color?
    let lineWidth: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        size: CGFloat = 140,
        progress: Double = 0.66,
        color: Color? = nil,
        lineWidth: CGFloat = 4,
        @ViewBuilder content: @escaping () -> Content = { EmptyView() }
    ) {
        self.size = size
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
        self.content = content
    }

    var body: some View {
        let arcColor = color ?? theme.palette.haloGreen
        ZStack {
            Circle()
                .stroke(
                    theme.palette.ink.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1.2, dash: [2, 3])
                )
                .frame(width: size - 12, height: size - 12)

            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    arcColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size - 12, height: size - 12)

            content()
        }
        .frame(width: size, height: size)
    }
}

/// Soft dashed circle, no arc — the classic halo motif around a hub.
struct HaloRingDashed: View {
    @Environment(\.theme) var theme
    var color: Color? = nil
    var size: CGFloat = 60
    var dash: [CGFloat] = [3, 3]
    var fillOpacity: Double = 0.18

    var body: some View {
        let c = color ?? theme.palette.haloGreen
        ZStack {
            Circle()
                .fill(c.opacity(fillOpacity))
            Circle()
                .stroke(c, style: StrokeStyle(lineWidth: theme.strokes.regular, dash: dash))
        }
        .frame(width: size, height: size)
    }
}
