import SwiftUI

/// C · countdown ring — "checking in soon" with a halo arc that drains.
struct WanderCountdownVariant: View {
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 4) {
            Text("checking in soon")
                .font(theme.typography.font(.handFlow, size: 11))
                .foregroundColor(theme.palette.ink2)
                .padding(.top, 6)

            Spacer()
            HaloRing(size: 110, progress: 0.35, color: theme.palette.haloYellow) {
                VStack(spacing: 0) {
                    Text("2:14")
                        .font(theme.typography.font(.handTight, size: 26, weight: .bold))
                    Text("UNTIL PING")
                        .font(theme.typography.font(.handTight, size: 9))
                        .foregroundColor(theme.palette.ink3)
                }
            }
            Spacer()

            Button {} label: {
                Text("+ 15 min · I'm good")
                    .font(theme.typography.font(.handTight, size: 10))
                    .foregroundColor(theme.palette.ink)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(Capsule().fill(theme.palette.haloYellow))
                    .overlay(Capsule().stroke(theme.palette.line, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .background(theme.palette.paper.ignoresSafeArea())
    }
}
