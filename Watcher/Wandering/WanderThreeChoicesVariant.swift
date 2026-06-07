import SwiftUI

/// B · three options — primary "Halo +1 mi", then "take me home" and "need help".
struct WanderThreeChoicesVariant: View {
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 4) {
            Text("HALOWALK")
                .font(theme.typography.font(.handTight, size: 10))
                .foregroundColor(theme.palette.ink3)
                .padding(.top, 4)
            Text("Just\nwandering?")
                .multilineTextAlignment(.center)
                .font(theme.typography.font(.handTight, size: 13, weight: .bold))
            Text("0.4mi from Library")
                .font(theme.typography.font(.handFlow, size: 11))
                .foregroundColor(theme.palette.ink2)

            Spacer()

            VStack(spacing: 4) {
                Button {} label: {
                    Text("+ HALO +1 MI")
                        .font(theme.typography.font(.handTight, size: 11, weight: .bold))
                        .foregroundColor(theme.palette.paper)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(Capsule().fill(theme.palette.haloGreen))
                        .overlay(Capsule().stroke(theme.palette.line, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                Button {} label: {
                    Text("take me home")
                        .font(theme.typography.font(.handTight, size: 10))
                        .foregroundColor(theme.palette.ink)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(Capsule().fill(theme.palette.haloYellow))
                        .overlay(Capsule().stroke(theme.palette.line, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                Button {} label: {
                    Text("need help")
                        .font(theme.typography.font(.handTight, size: 10))
                        .foregroundColor(theme.palette.ink)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(Capsule().fill(theme.palette.paper))
                        .overlay(Capsule().stroke(theme.palette.line, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 6)
        .background(theme.palette.paper.ignoresSafeArea())
    }
}
