#if DEBUG
#if canImport(ActivityKit)
import ActivityKit
import SwiftUI

struct LiveActivityRenderPreviewView: View {
    @Environment(\.theme) var theme

    private let attributes = HaloWalkLiveActivityAttributes.previewAndrew
    private let states: [(String, HaloWalkLiveActivityAttributes.ContentState)] = [
        ("At hub", .previewAtHub),
        ("Moving", .previewMoving),
        ("Away", .previewAway),
        ("Stale", .previewStale)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(states, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.0)
                            .font(theme.typography.font(.handTight, size: 13, weight: .bold))
                            .foregroundColor(theme.palette.ink3)
                        HaloWalkLiveActivityLockScreenCard(
                            attributes: attributes,
                            state: item.1
                        )
                        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
                    }
                }
            }
            .padding(20)
        }
        .background(theme.palette.paper.ignoresSafeArea())
        .navigationTitle("Live Activity")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
#endif
