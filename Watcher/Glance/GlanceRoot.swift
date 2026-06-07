import SwiftUI

/// Halo Glance — for "on the move." Two swipeable views:
///   • Turn-by-turn map  (default)
///   • Minimalist arrow   (theme-aware appearance)
///
/// The optional target ids let the launcher tell Glance which destination
/// the user actually picked from the Hubs list. When both are nil, Glance
/// falls back to the nearest assigned hub.
struct GlanceRoot: View {
    @EnvironmentObject var themeManager: ThemeManager

    let targetHubId: UUID?
    let targetGuardianId: UUID?

    init(targetHubId: UUID? = nil, targetGuardianId: UUID? = nil) {
        self.targetHubId = targetHubId
        self.targetGuardianId = targetGuardianId
    }

    var body: some View {
        TabView(selection: $themeManager.variantPrefs.glance) {
            GlanceTurnByTurnVariant(targetHubId: targetHubId, targetGuardianId: targetGuardianId).tag(0)
            GlanceArrowVariant(targetHubId: targetHubId, targetGuardianId: targetGuardianId).tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
    }
}
