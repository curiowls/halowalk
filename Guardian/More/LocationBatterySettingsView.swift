import SwiftUI

/// Location & battery settings — picks the per-device monitoring profile
/// and toggles quiet-hours pause. The three profile rows show realistic
/// daily-drain estimates so users can make an informed trade-off rather
/// than discovering "wait, why is HaloWalk eating my battery?" later.
struct LocationBatterySettingsView: View {
    @Environment(\.theme) var theme
    @ObservedObject private var prefs = MonitoringPrefs.shared
    @State private var quiet: QuietHoursPrefs = .load()

    var body: some View {
        Form {
            Section {
                ForEach(MonitoringProfile.allCases) { profile in
                    Button {
                        prefs.profile = profile
                    } label: {
                        ProfileRow(
                            profile: profile,
                            selected: prefs.profile == profile
                        )
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("How HaloWalk uses your location")
            } footer: {
                Text("Estimates are based on typical use. Actual battery life varies with how often you're moving and how many family members are nearby.")
                    .font(theme.typography.font(.handFlow, size: 12))
            }

            Section {
                Toggle(
                    "Pause non-essential location during quiet hours",
                    isOn: Binding(
                        get: { quiet.pauseNonEssentialLocation },
                        set: { newVal in
                            quiet.pauseNonEssentialLocation = newVal
                            quiet.save()
                        }
                    )
                )
            } footer: {
                Text(quietFooter)
                    .font(theme.typography.font(.handFlow, size: 12))
            }

            Section {
                NavigationLink("Quiet hours window") {
                    QuietHoursView()
                }
            }
        }
        .navigationTitle("Location & battery")
        .navigationBarTitleDisplayMode(.inline)
        .background(theme.palette.paper.ignoresSafeArea())
        .onAppear { quiet = .load() }
    }

    private var quietFooter: String {
        let s = format(minutes: quiet.startMinute)
        let e = format(minutes: quiet.endMinute)
        return "Active 'Watching…' sessions still run during quiet hours. Window: \(s)–\(e)."
    }
    private func format(minutes: Int) -> String {
        let h = (minutes / 60) % 24
        let m = minutes % 60
        let d = Calendar.current.date(from: DateComponents(hour: h, minute: m))!
        return d.formatted(date: .omitted, time: .shortened)
    }
}

private struct ProfileRow: View {
    @Environment(\.theme) var theme
    let profile: MonitoringProfile
    let selected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: selected
                  ? "largecircle.fill.circle"
                  : "circle")
                .font(.system(size: 20))
                .foregroundColor(selected ? theme.palette.haloGreen : theme.palette.ink3)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(profile.label)
                        .font(theme.typography.font(.handTight, size: 15, weight: .bold))
                        .foregroundColor(theme.palette.ink)
                    if profile == .smart {
                        Text("RECOMMENDED")
                            .font(theme.typography.font(.handTight, size: 9, weight: .bold))
                            .tracking(0.6)
                            .foregroundColor(theme.palette.paper)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(theme.palette.haloGreen))
                    }
                    Spacer()
                    Text(profile.batteryEstimate)
                        .font(theme.typography.font(.handTight, size: 11, weight: .bold))
                        .foregroundColor(batteryColor)
                }
                Text(profile.headline)
                    .font(theme.typography.font(.handFlow, size: 13))
                    .foregroundColor(theme.palette.ink2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 4)
    }

    private var batteryColor: Color {
        switch profile {
        case .minimal: return theme.palette.haloGreen
        case .smart:   return theme.palette.ink2
        case .live:    return theme.palette.haloYellow
        }
    }
}
