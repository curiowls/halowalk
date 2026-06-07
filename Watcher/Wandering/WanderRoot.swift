import SwiftUI

struct WanderRoot: View {
    @EnvironmentObject var themeManager: ThemeManager
    var body: some View {
        TabView(selection: $themeManager.variantPrefs.wander) {
            WanderEnlargeHaloVariant().tag(0)
            WanderThreeChoicesVariant().tag(1)
            WanderCountdownVariant().tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
    }
}
