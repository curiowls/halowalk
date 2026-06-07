import SwiftUI

/// Tabs are dynamic per signed-in Member:
///   • Family — visible when this Member watches anyone
///   • Me     — visible when this Member is watched by anyone
///   • Hubs · Notifications · ··· — always visible
///
/// Default selected tab:
///   • If Me is visible and the Member watches no one → Me
///   • Otherwise → Family (or Hubs if neither Family nor Me is visible)
struct RootTabView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var notificationStore: NotificationStore
    @EnvironmentObject var familyStore: FamilyStore

    enum Tab: Hashable { case me, family, hubs, notifications, more }

    @State private var selectedTab: Tab = .family
    @State private var previousTab: Tab = .family
    @State private var showMoreMenu = false

    private var isWatcher: Bool { familyStore.isGuardian(familyStore.account.memberId) }
    private var isWatched: Bool { familyStore.isWatched(familyStore.account.memberId) }

    private func defaultTab() -> Tab {
        if isWatcher && isWatched {
            // Hybrid — default to Family (their primary daily concern is the
            // family they watch over, but Me is still one tap away).
            return .family
        }
        if isWatcher { return .family }
        if isWatched { return .me }
        return .hubs
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            if isWatched {
                MeTabView()
                    .tabItem { Label("Me", systemImage: "person.crop.circle") }
                    .tag(Tab.me)
            }
            if isWatcher {
                FamilyTabView()
                    .tabItem { Label("Family", systemImage: "heart.fill") }
                    .tag(Tab.family)
            }
            HubsTabView()
                .tabItem { Label("Hubs", systemImage: "mappin.and.ellipse") }
                .tag(Tab.hubs)

            NotificationsTabView()
                .tabItem {
                    Label("Notifications", systemImage: notificationIcon)
                }
                .tag(Tab.notifications)

            MoreTabPlaceholder()
                .tabItem { Label("More", systemImage: "ellipsis") }
                .tag(Tab.more)
        }
        .tint(theme.palette.ink)
        .onAppear {
            // Pick the default tab based on the signed-in Member's roles.
            selectedTab = defaultTab()
            previousTab = selectedTab
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == .more {
                previousTab = (oldValue == .more) ? defaultTab() : oldValue
                showMoreMenu = true
            }
        }
        .sheet(isPresented: $showMoreMenu, onDismiss: {
            if selectedTab == .more { selectedTab = previousTab }
        }) {
            MoreMenuSheet()
                // Single .large detent — opens to full height so all menu
                // items are visible at a glance, no extra drag needed.
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var notificationIcon: String {
        switch notificationStore.dominantSeverity {
        case .critical: return "exclamationmark.triangle.fill"
        case .headsUp:  return "bell.badge.fill"
        case .quiet:    return "message.badge.fill"
        case .none:     return "message"
        }
    }
}

private struct MoreTabPlaceholder: View {
    @Environment(\.theme) var theme
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 56))
                .foregroundColor(theme.palette.ink3)
            Text("Tap ··· in the tab bar to open the menu.")
                .font(theme.typography.font(.handFlow, size: 16))
                .foregroundColor(theme.palette.ink3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.paper.ignoresSafeArea())
    }
}
