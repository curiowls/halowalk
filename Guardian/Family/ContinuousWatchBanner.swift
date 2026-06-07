import SwiftUI

/// Active "Watching X until ___" banner. Shown on member detail when the
/// guardian has an active continuous-watch on this member.
struct ContinuousWatchBanner: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var familyStore: FamilyStore
    @EnvironmentObject var hubStore: HubStore
    @ObservedObject var store: ContinuousWatchStore

    let watchedMemberId: UUID

    private var myWatch: ContinuousWatch? {
        store.active.first {
            $0.watcherId == familyStore.account.memberId &&
            $0.watchedId == watchedMemberId
        }
    }

    var body: some View {
        if let watch = myWatch,
           let watched = familyStore.member(watchedMemberId) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(theme.palette.haloGreen.opacity(0.18))
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 16))
                        .foregroundColor(theme.palette.haloGreen)
                }
                .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Watching \(watched.displayName) live")
                        .font(theme.typography.font(.handTight, size: 13, weight: .bold))
                    Text(watch.describeUntil(
                        memberDisplayName: watched.displayName,
                        hubName: { id in hubStore.hubs.first(where: { $0.id == id })?.name }
                    ))
                        .font(theme.typography.font(.handFlow, size: 12))
                        .foregroundColor(theme.palette.ink2)
                }
                Spacer()
                Button("Stop") {
                    store.stop(watch.id)
                }
                .font(theme.typography.font(.handTight, size: 12, weight: .bold))
                .foregroundColor(theme.palette.haloRed)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sketchBorder(fill: theme.palette.highlightSoft, padding: 0)
        }
    }
}
