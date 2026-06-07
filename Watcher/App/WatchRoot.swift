import SwiftUI

/// Watch launch surface = Quick-Tap Hubs (per the design conversation:
/// "QuickTapHub is the launch screen, settings cog top-right").
/// From there, the user navigates to Halo Glance (when actively walking)
/// or I'm Wandering (when off-halo). Each of those screens is itself
/// a swipeable TabView so the user can swipe between variants.
struct WatchRoot: View {
    @State private var path: [WatchRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            QuickTapHubsRoot()
                .navigationDestination(for: WatchRoute.self) { route in
                    switch route {
                    case .glanceToHub(let id):
                        GlanceRoot(targetHubId: id, targetGuardianId: nil)
                    case .glanceToGuardian(let id):
                        GlanceRoot(targetHubId: nil, targetGuardianId: id)
                    case .glanceNearest:
                        GlanceRoot()
                    case .wander:
                        WanderRoot()
                    case .settings:
                        WatchSettingsView()
                    case .quickReply:
                        WatchQuickReplyView()
                    case .quickReplyTo(let id):
                        WatchQuickReplyComposer(toMemberId: id)
                    }
                }
        }
    }
}

/// All possible navigation destinations on the watch. Associated values
/// carry the *specific* target so that, e.g., tapping "Mom" on the hubs
/// list opens a Glance pointed at Mom — not just at the nearest hub.
enum WatchRoute: Hashable {
    case glanceToHub(UUID)
    case glanceToGuardian(UUID)
    case glanceNearest
    case wander
    case settings
    case quickReply
    case quickReplyTo(UUID)
}
