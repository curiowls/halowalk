import SwiftUI

/// Watch settings — theme picker + per-screen variant defaults.
/// Reachable via the gear icon in the top-right of the launch screen.
struct WatchSettingsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Theme")
                    .font(theme.typography.font(.handTight, size: 13, weight: .bold))
                    .foregroundColor(theme.palette.watchForeground)
                    .padding(.top, 4)

                ForEach(Theme.allRegistered) { t in
                    Button {
                        themeManager.setTheme(t.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.name)
                                    .font(theme.typography.font(.handTight, size: 12, weight: .bold))
                                    .foregroundColor(theme.palette.watchForeground)
                                Text(t.summary)
                                    .font(theme.typography.font(.handFlow, size: 10))
                                    .foregroundColor(theme.palette.watchMuted)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Circle()
                                .fill(themeManager.theme.id == t.id ? theme.palette.watchForeground : .clear)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(theme.palette.watchSurfaceBorder, lineWidth: 1.2))
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8).fill(theme.palette.watchSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8).stroke(theme.palette.watchSurfaceBorder, lineWidth: 1.2)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Divider().background(theme.palette.watchSurfaceBorder)

                Text("Battery")
                    .font(theme.typography.font(.handTight, size: 13, weight: .bold))
                    .foregroundColor(theme.palette.watchForeground)

                ForEach(MonitoringProfile.allCases) { p in
                    Button {
                        MonitoringPrefs.shared.profile = p
                    } label: {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: MonitoringPrefs.shared.profile == p
                                  ? "largecircle.fill.circle"
                                  : "circle")
                                .font(.system(size: 14))
                                .foregroundColor(theme.palette.watchForeground)
                            VStack(alignment: .leading, spacing: 1) {
                                HStack {
                                    Text(p.label)
                                        .font(theme.typography.font(.handTight, size: 12, weight: .bold))
                                        .foregroundColor(theme.palette.watchForeground)
                                    Spacer()
                                    Text(p.batteryEstimate)
                                        .font(theme.typography.font(.handTight, size: 9, weight: .bold))
                                        .foregroundColor(theme.palette.watchMuted)
                                }
                                Text(p.headline)
                                    .font(theme.typography.font(.handFlow, size: 9))
                                    .foregroundColor(theme.palette.watchMuted)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(3)
                            }
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8).fill(theme.palette.watchSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8).stroke(theme.palette.watchSurfaceBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Divider().background(theme.palette.watchSurfaceBorder)

                Text("Default variants")
                    .font(theme.typography.font(.handTight, size: 13, weight: .bold))
                    .foregroundColor(theme.palette.watchForeground)
                Text("Pick the default screen we boot into when each surface fires.")
                    .font(theme.typography.font(.handFlow, size: 10))
                    .foregroundColor(theme.palette.watchMuted)

                VariantStepper(
                    label: "Glance",
                    options: ["Map", "Arrow"],
                    index: $themeManager.variantPrefs.glance
                )
                VariantStepper(
                    label: "Hubs",
                    options: ["List", "Petals"],
                    index: $themeManager.variantPrefs.hubs
                )
                VariantStepper(
                    label: "Wandering",
                    options: ["+1 mi halo", "Three choices", "Countdown"],
                    index: $themeManager.variantPrefs.wander
                )
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .navigationTitle("Settings")
        .background(theme.palette.watchBackground.ignoresSafeArea())
    }
}

private struct VariantStepper: View {
    @Environment(\.theme) var theme
    let label: String
    let options: [String]
    @Binding var index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(theme.typography.font(.handTight, size: 11))
                .foregroundColor(theme.palette.watchForeground.opacity(0.85))
            HStack(spacing: 3) {
                ForEach(0..<options.count, id: \.self) { i in
                    Button {
                        // Clamp to valid range; the variant pref store may
                        // hold a stale value from a previous build that had
                        // more options ("Friendly", "Suggested" etc.).
                        index = min(max(0, i), options.count - 1)
                    } label: {
                        Text(options[i])
                            .font(theme.typography.font(.handTight, size: 9))
                            .foregroundColor(index == i ? theme.palette.watchBackground : theme.palette.watchForeground)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(index == i ? theme.palette.watchForeground : theme.palette.watchSurface)
                            )
                            .overlay(Capsule().stroke(theme.palette.watchSurfaceBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
