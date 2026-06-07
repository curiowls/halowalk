import SwiftUI

/// Pop-up menu surfaced when the user taps the "···" tab. Each entry pushes
/// its own page within the sheet's NavigationStack so the user can drill in
/// and back out without losing the tab they were on.
struct MoreMenuSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        MenuRow(icon: "person.circle.fill", title: "You",
                                subtitle: "Profile, sign-in, account")
                    }
                    NavigationLink {
                        FamilyManagementView()
                    } label: {
                        MenuRow(icon: "person.2.fill", title: "Family members",
                                subtitle: "Add, edit, assign roles")
                    }
                }
                Section("Behavior") {
                    NavigationLink {
                        LocationBatterySettingsView()
                    } label: {
                        MenuRow(icon: "battery.75", title: "Location & battery",
                                subtitle: "How closely to track, with battery estimates")
                    }
                    NavigationLink {
                        TriggersListView()
                    } label: {
                        MenuRow(icon: "bell.badge", title: "Triggers",
                                subtitle: "Set & forget rules")
                    }
                    NavigationLink {
                        QuietHoursView()
                    } label: {
                        MenuRow(icon: "moon.stars", title: "Quiet hours",
                                subtitle: "When to suppress non-critical alerts")
                    }
                }
                Section("Look") {
                    NavigationLink {
                        ThemePickerView()
                    } label: {
                        MenuRow(icon: "paintpalette", title: "Theme",
                                subtitle: "Sketch · Senior · Playful")
                    }
                }
                Section("App") {
                    NavigationLink {
                        PrivacyPermissionsView()
                    } label: {
                        MenuRow(icon: "lock.shield", title: "Privacy & permissions",
                                subtitle: "Location, notifications, sharing")
                    }
                    NavigationLink {
                        CloudSyncDiagnosticsView()
                    } label: {
                        MenuRow(icon: "icloud", title: "CloudKit sync",
                                subtitle: "Sync status & live event log")
                    }
                    NavigationLink {
                        AboutView()
                    } label: {
                        MenuRow(icon: "info.circle", title: "About HaloWalk",
                                subtitle: "Version, support, licenses")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(theme.palette.paper.ignoresSafeArea())
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(theme.palette.ink)
                }
            }
        }
    }
}

private struct MenuRow: View {
    @Environment(\.theme) var theme
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(theme.palette.ink2)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.font(.handTight, size: 15, weight: .bold))
                    .foregroundColor(theme.palette.ink)
                Text(subtitle)
                    .font(theme.typography.font(.handFlow, size: 13))
                    .foregroundColor(theme.palette.ink3)
            }
        }
        .padding(.vertical, 4)
    }
}
