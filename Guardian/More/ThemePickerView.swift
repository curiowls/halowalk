import SwiftUI

/// Theme picker for the device-level look. Each family member also has a
/// preferred theme that's set under Family Management — that one is
/// per-member; this one is for the iPhone Guardian.
struct ThemePickerView: View {
    @Environment(\.theme) var theme
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Each family member can also pick their own theme — this changes the look of this iPhone.")
                    .font(theme.typography.font(.handFlow, size: 13))
                    .foregroundColor(theme.palette.ink2)

                VStack(spacing: 8) {
                    ForEach(Theme.allRegistered) { t in
                        ShippingThemeRow(theme: t, selected: themeManager.theme.id == t.id) {
                            themeManager.setTheme(t.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.paper.ignoresSafeArea())
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ShippingThemeRow: View {
    @Environment(\.theme) var envTheme
    let theme: Theme
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ThemeSwatch(
                    paper: theme.palette.paper,
                    ink: theme.palette.ink,
                    accent1: theme.palette.haloGreen,
                    accent2: theme.palette.haloYellow,
                    accent3: theme.palette.haloRed,
                    accent4: theme.palette.haloPink
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name)
                        .font(envTheme.typography.font(.handTight, size: 15, weight: .bold))
                        .foregroundColor(envTheme.palette.ink)
                    Text(theme.summary)
                        .font(envTheme.typography.font(.handFlow, size: 13))
                        .foregroundColor(envTheme.palette.ink2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(envTheme.palette.haloGreen)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .sketchBorder(seed: theme.id.hashValue, padding: 0)
        }
        .buttonStyle(.plain)
    }
}

/// Mini preview swatch — shows paper background + ink + 4 accents so the
/// user can see the contrast the theme uses.
struct ThemeSwatch: View {
    @Environment(\.theme) var envTheme
    let paper: Color
    let ink: Color
    let accent1: Color
    let accent2: Color
    let accent3: Color
    let accent4: Color

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Circle().fill(accent1).frame(width: 10, height: 10)
                Circle().fill(accent2).frame(width: 10, height: 10)
                Circle().fill(ink).frame(width: 10, height: 10)
            }
            HStack(spacing: 3) {
                Circle().fill(accent3).frame(width: 10, height: 10)
                Circle().fill(accent4).frame(width: 10, height: 10)
                Circle().fill(paper).frame(width: 10, height: 10)
                    .overlay(Circle().stroke(envTheme.palette.lineSoft, lineWidth: 1))
            }
        }
        .padding(8)
        .background(paper)
        .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(envTheme.palette.line, lineWidth: 1.2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
