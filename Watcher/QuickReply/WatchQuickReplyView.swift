import SwiftUI

/// Pick a guardian to reply to. Lists every guardian the watch knows
/// about (not just those currently sharing — the wearer might want to
/// ping a parent who isn't actively tracking right now). Tapping a row
/// pushes the composer.
struct WatchQuickReplyView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var familyStore: FamilyStore

    private var guardians: [Member] { familyStore.watcherMembers }

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                Text("Reply to…")
                    .font(theme.typography.font(.handTight, size: 12, weight: .bold))
                    .foregroundColor(theme.palette.watchForeground)
                    .padding(.top, 4)

                if guardians.isEmpty {
                    Text("No guardians yet.")
                        .font(theme.typography.font(.handFlow, size: 11))
                        .foregroundColor(theme.palette.watchMuted)
                        .padding(.top, 12)
                } else {
                    ForEach(guardians) { guardian in
                        NavigationLink(value: WatchRoute.quickReplyTo(guardian.id)) {
                            GuardianRow(member: guardian)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .navigationTitle("Quick reply")
        .background(theme.palette.watchBackground.ignoresSafeArea())
    }
}

private struct GuardianRow: View {
    @Environment(\.theme) var theme
    let member: Member
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(member.accentColor)
                Circle().stroke(theme.palette.watchSurfaceBorder, lineWidth: 1)
                Text(member.initial)
                    .font(theme.typography.font(.handTight, size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 24, height: 24)
            Text(member.displayName)
                .font(theme.typography.font(.handTight, size: 12, weight: .bold))
                .foregroundColor(theme.palette.watchForeground)
                .lineLimit(1)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(theme.palette.watchMuted)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8).fill(theme.palette.watchSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(theme.palette.watchSurfaceBorder, lineWidth: 1)
        )
    }
}
