#if canImport(ActivityKit)
import ActivityKit
import SwiftUI

struct HaloWalkLiveActivityLockScreenCard: View {
    let attributes: HaloWalkLiveActivityAttributes
    let state: HaloWalkLiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                HaloWalkLiveActivityIdentityView(
                    initial: attributes.watchedInitial,
                    name: attributes.watchedName,
                    accentHex: attributes.accentHex,
                    compact: false
                )
                Spacer()
                HaloWalkLiveActivityStatePill(stateKind: state.stateKind)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(state.statusLine)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(state.locationLine)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.72))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let progress = state.progress {
                ProgressView(value: progress)
                    .tint(haloLiveActivityAccentColor(attributes.accentHex))
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(haloLiveActivityDetailLine(for: state))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.black.opacity(0.56))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(state.conditionLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.black.opacity(0.56))
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct HaloWalkLiveActivityIdentityView: View {
    let initial: String
    let name: String
    let accentHex: UInt32
    let compact: Bool

    var body: some View {
        HStack(spacing: 8) {
            HaloWalkLiveActivityInitialBadge(
                initial: initial,
                accent: haloLiveActivityAccentColor(accentHex),
                size: compact ? 30 : 36
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
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

struct HaloWalkLiveActivityInitialBadge: View {
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

struct HaloWalkLiveActivityStatePill: View {
    let stateKind: TrackingStateKind

    var body: some View {
        Label(haloLiveActivityLabel(for: stateKind), systemImage: haloLiveActivityIconName(for: stateKind))
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(haloLiveActivityColor(for: stateKind))
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(haloLiveActivityColor(for: stateKind).opacity(0.12), in: Capsule())
            .lineLimit(1)
    }
}

func haloLiveActivityLabel(for state: TrackingStateKind) -> String {
    switch state {
    case .live: return "Live"
    case .atHub: return "At hub"
    case .moving: return "Moving"
    case .away: return "Away"
    case .stale: return "Stale"
    case .unknown: return "Waiting"
    }
}

func haloLiveActivityIconName(for state: TrackingStateKind) -> String {
    switch state {
    case .live: return "dot.radiowaves.left.and.right"
    case .atHub: return "house"
    case .moving: return "figure.walk"
    case .away: return "exclamationmark.triangle"
    case .stale: return "clock"
    case .unknown: return "location.slash"
    }
}

func haloLiveActivityColor(for state: TrackingStateKind) -> Color {
    switch state {
    case .live, .atHub: return Color(haloLiveActivityHex: 0x0A7D3C)
    case .moving: return Color(haloLiveActivityHex: 0x1C39BB)
    case .away: return Color(haloLiveActivityHex: 0xC8261D)
    case .stale, .unknown: return Color(haloLiveActivityHex: 0x5B6370)
    }
}

func haloLiveActivityAccentColor(_ hex: UInt32) -> Color {
    Color(haloLiveActivityHex: hex)
}

func haloLiveActivityDetailLine(for state: HaloWalkLiveActivityAttributes.ContentState) -> String {
    [state.freshnessLine, state.accuracyLine]
        .compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        .joined(separator: " · ")
}

extension Color {
    init(haloLiveActivityHex hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

#if DEBUG
extension HaloWalkLiveActivityAttributes {
    static var previewAndrew: HaloWalkLiveActivityAttributes {
        HaloWalkLiveActivityAttributes(
            watchId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            watchedMemberId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            watcherId: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            watchedName: "Andrew",
            watchedInitial: "A",
            accentHex: 0x11A36A,
            startedAt: .now.addingTimeInterval(-8 * 60)
        )
    }
}

extension HaloWalkLiveActivityAttributes.ContentState {
    static var previewAtHub: HaloWalkLiveActivityAttributes.ContentState {
        HaloWalkLiveActivityAttributes.ContentState(
            statusLine: "Andrew is at Home",
            locationLine: "Inside Home's halo",
            freshnessLine: "now",
            conditionLine: "until you stop",
            accuracyLine: "65 ft",
            stateKind: .atHub,
            progress: nil,
            updatedAt: .now,
            endsAt: nil
        )
    }

    static var previewMoving: HaloWalkLiveActivityAttributes.ContentState {
        HaloWalkLiveActivityAttributes.ContentState(
            statusLine: "Andrew is moving",
            locationLine: "0.4 mi from School",
            freshnessLine: "2 min ago",
            conditionLine: "for 18 min",
            accuracyLine: "120 ft",
            stateKind: .moving,
            progress: 0.42,
            updatedAt: .now,
            endsAt: .now.addingTimeInterval(18 * 60)
        )
    }

    static var previewAway: HaloWalkLiveActivityAttributes.ContentState {
        HaloWalkLiveActivityAttributes.ContentState(
            statusLine: "Andrew is away",
            locationLine: "1.2 mi from Home",
            freshnessLine: "1 min ago",
            conditionLine: "until Andrew arrives at Home",
            accuracyLine: "95 ft",
            stateKind: .away,
            progress: nil,
            updatedAt: .now,
            endsAt: nil
        )
    }

    static var previewStale: HaloWalkLiveActivityAttributes.ContentState {
        HaloWalkLiveActivityAttributes.ContentState(
            statusLine: "Andrew was last seen",
            locationLine: "Near Home",
            freshnessLine: "14 min ago",
            conditionLine: "Open HaloWalk for details",
            accuracyLine: nil,
            stateKind: .stale,
            progress: nil,
            updatedAt: .now.addingTimeInterval(-14 * 60),
            endsAt: nil
        )
    }
}
#endif
#endif
