import SwiftUI

/// A · primary action = grow the halo. Single big tap target, dashed
/// expanded halo behind it.
struct WanderEnlargeHaloVariant: View {
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 4) {
            Text("You stepped out\nof your halo")
                .multilineTextAlignment(.center)
                .font(theme.typography.font(.handFlow, size: 11))
                .foregroundColor(theme.palette.ink2)
                .padding(.top, 4)

            ZStack {
                Circle()
                    .fill(theme.palette.haloGreen.opacity(0.10))
                    .overlay(
                        Circle().stroke(
                            theme.palette.haloGreen,
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                        )
                    )
                    .frame(width: 138, height: 138)

                Button {} label: {
                    VStack(spacing: 1) {
                        Text("+1 mi")
                            .font(theme.typography.font(.handTight, size: 22, weight: .bold))
                        Text("BIGGER HALO")
                            .font(theme.typography.font(.handTight, size: 9, weight: .bold))
                            .tracking(0.6)
                    }
                    .foregroundColor(theme.palette.paper)
                    .frame(width: 104, height: 104)
                    .background(Circle().fill(theme.palette.haloGreen))
                    .overlay(Circle().stroke(theme.palette.line, lineWidth: 1.5))
                    .shadow(color: theme.palette.line, radius: 0, x: 2, y: 2)
                }
                .buttonStyle(.plain)
            }

            Text("tap · gives you more room\nto keep exploring")
                .multilineTextAlignment(.center)
                .font(theme.typography.font(.handFlow, size: 10))
                .foregroundColor(theme.palette.ink3)
                .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.paper.ignoresSafeArea())
    }
}
