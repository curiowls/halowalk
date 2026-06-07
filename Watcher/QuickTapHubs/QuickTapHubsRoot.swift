import SwiftUI

/// Watch launch screen. Two swipeable views: list and grid (petals).
/// Settings cog top-right opens the watch settings page. The connection
/// dot next to the cog is grey when the iPhone isn't reachable, green
/// when it is — gives the wearer a quick "are we synced?" confidence
/// signal without burying it in a settings screen.
struct QuickTapHubsRoot: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var watchSync: WatchSync

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $themeManager.variantPrefs.hubs) {
                HubsListVariant().tag(0)
                HubsPetalsVariant().tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            HStack(spacing: 4) {
                ConnectionDot(isConnected: watchSync.isReachable)
                NavigationLink(value: WatchRoute.settings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.palette.watchForeground)
                        .padding(6)
                        .background(Circle().fill(theme.palette.watchSurface))
                        .overlay(Circle().stroke(theme.palette.watchSurfaceBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 6)
            .padding(.top, 2)
        }
        .background(theme.palette.watchBackground.ignoresSafeArea())
    }
}

private struct ConnectionDot: View {
    @Environment(\.theme) var theme
    let isConnected: Bool
    var body: some View {
        Circle()
            .fill(isConnected ? theme.palette.haloGreen : theme.palette.watchMuted)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(theme.palette.watchBackground, lineWidth: 1))
    }
}
