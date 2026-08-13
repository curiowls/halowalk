#if canImport(ActivityKit)
import ActivityKit
import WidgetKit
import SwiftUI

@main
struct HaloWalkLiveActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        HaloWalkLiveActivityWidget()
    }
}

struct HaloWalkLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HaloWalkLiveActivityAttributes.self) { context in
            HaloWalkLockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color.white)
                .activitySystemActionForegroundColor(Color.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    IdentityView(context: context, compact: true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StatePill(stateKind: context.state.stateKind)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(context.state.locationLine)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Text(context.state.conditionLine)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if let progress = context.state.progress {
                            ProgressView(value: progress)
                                .tint(haloAccentColor(context.attributes.accentHex))
                        }
                    }
                }
            } compactLeading: {
                InitialBadge(
                    initial: context.attributes.watchedInitial,
                    accent: haloAccentColor(context.attributes.accentHex),
                    size: 22
                )
            } compactTrailing: {
                Image(systemName: iconName(for: context.state.stateKind))
                    .foregroundStyle(color(for: context.state.stateKind))
            } minimal: {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(color(for: context.state.stateKind))
            }
        }
    }
}

private struct HaloWalkLockScreenLiveActivityView: View {
    let context: ActivityViewContext<HaloWalkLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                IdentityView(context: context, compact: false)
                Spacer()
                StatePill(stateKind: context.state.stateKind)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.statusLine)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                Text(context.state.locationLine)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.72))
                    .lineLimit(2)
            }

            if let progress = context.state.progress {
                ProgressView(value: progress)
                    .tint(haloAccentColor(context.attributes.accentHex))
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(context.state.freshnessLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.black.opacity(0.56))
                Spacer(minLength: 8)
                Text(context.state.conditionLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.black.opacity(0.56))
                    .lineLimit(1)
            }
        }
        .padding(16)
    }
}

private struct IdentityView: View {
    let context: ActivityViewContext<HaloWalkLiveActivityAttributes>
    let compact: Bool

    var body: some View {
        HStack(spacing: 8) {
            InitialBadge(
                initial: context.attributes.watchedInitial,
                accent: haloAccentColor(context.attributes.accentHex),
                size: compact ? 30 : 36
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(context.attributes.watchedName)
                    .font(.system(size: compact ? 14 : 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("Live watch")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct InitialBadge: View {
    let initial: String
    let accent: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(accent)
            Text(initial)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

private struct StatePill: View {
    let stateKind: TrackingStateKind

    var body: some View {
        Label(label(for: stateKind), systemImage: iconName(for: stateKind))
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(color(for: stateKind))
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(color(for: stateKind).opacity(0.12), in: Capsule())
            .lineLimit(1)
    }
}

private func label(for state: TrackingStateKind) -> String {
    switch state {
    case .live: return "Live"
    case .atHub: return "At hub"
    case .moving: return "Moving"
    case .away: return "Away"
    case .stale: return "Stale"
    case .unknown: return "Waiting"
    }
}

private func iconName(for state: TrackingStateKind) -> String {
    switch state {
    case .live: return "dot.radiowaves.left.and.right"
    case .atHub: return "house"
    case .moving: return "figure.walk"
    case .away: return "exclamationmark.triangle"
    case .stale: return "clock"
    case .unknown: return "location.slash"
    }
}

private func color(for state: TrackingStateKind) -> Color {
    switch state {
    case .live, .atHub: return Color(hex: 0x0A7D3C)
    case .moving: return Color(hex: 0x1C39BB)
    case .away: return Color(hex: 0xC8261D)
    case .stale, .unknown: return Color(hex: 0x5B6370)
    }
}

private func haloAccentColor(_ hex: UInt32) -> Color {
    Color(hex: hex)
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}
#endif
