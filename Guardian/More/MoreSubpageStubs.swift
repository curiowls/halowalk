import SwiftUI
import UIKit
import CoreLocation
import UserNotifications

// MARK: - Profile

struct ProfileView: View {
    @Environment(\.theme) var theme
    @ObservedObject private var familyStore = FamilyStore.shared
    @ObservedObject private var auth = AppleAuthManager.shared

    @State private var name: String = ""
    @State private var displayName: String = ""
    @State private var pronouns: String = ""
    @State private var didLoad = false
    @State private var showingAvatarPicker = false

    private var accountLabel: String {
        if let email = familyStore.account.email, !email.isEmpty { return email }
        if auth.isSignedIn { return "Signed in with Apple" }
        return "Not signed in"
    }
    private var appleIdentityLabel: String {
        if let name = auth.identity?.fullName, !name.isEmpty { return name }
        if let email = auth.identity?.email, !email.isEmpty { return email }
        return "Signed in with Apple"
    }

    var body: some View {
        Form {
            Section {
                if let me = familyStore.me {
                    HStack(spacing: 12) {
                        Button { showingAvatarPicker = true } label: {
                            MemberAvatar(me, size: 64)
                        }
                        .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(familyStore.isGuardian(me.id) ? "Guardian" : "Wearer")
                                .font(theme.typography.font(.handTight, size: 11))
                                .tracking(0.6)
                                .foregroundColor(theme.palette.ink3)
                            Text(accountLabel)
                                .font(theme.typography.font(.handFlow, size: 13))
                                .foregroundColor(theme.palette.ink2)
                            Button("Change avatar") { showingAvatarPicker = true }
                                .font(theme.typography.font(.handTight, size: 12, weight: .bold))
                                .foregroundColor(theme.palette.haloBlue)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Apple ID") {
                if auth.isSignedIn {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(theme.palette.haloGreen)
                        Text(appleIdentityLabel)
                            .font(theme.typography.font(.handFlow, size: 14))
                            .foregroundColor(theme.palette.ink2)
                    }
                    Button("Sign out", role: .destructive) {
                        auth.signOutLocally()
                    }
                } else {
                    Button {
                        auth.signIn()
                    } label: {
                        HStack {
                            Image(systemName: "applelogo")
                            Text("Sign in with Apple")
                                .fontWeight(.bold)
                        }
                    }
                    if let err = auth.lastError {
                        Text(err)
                            .font(theme.typography.font(.handFlow, size: 12))
                            .foregroundColor(theme.palette.haloRed)
                    }
                }
            }
            Section("Your name") {
                TextField("Name", text: $name)
                TextField("Display name (shown on cards)", text: $displayName)
            }
            Section("Pronouns") {
                TextField("e.g. she/her, they/them", text: $pronouns)
            }
            Section {
                Button("Save") {
                    save()
                }
                .fontWeight(.bold)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("You")
        .navigationBarTitleDisplayMode(.inline)
        .background(theme.palette.paper.ignoresSafeArea())
        .onAppear { loadFields() }
        .onChange(of: auth.identity) { _, newValue in
            guard let id = newValue else { return }
            familyStore.linkAppleIdentity(
                userId: id.userId, fullName: id.fullName, email: id.email
            )
        }
        .sheet(isPresented: $showingAvatarPicker) {
            avatarPickerSheet()
        }
    }

    private func loadFields() {
        guard !didLoad, let me = familyStore.me else { return }
        name = me.name
        displayName = me.displayName
        pronouns = me.pronouns ?? ""
        didLoad = true
    }
    private func save() {
        guard var me = familyStore.me else { return }
        me.name = name.trimmingCharacters(in: .whitespaces)
        me.displayName = displayName.isEmpty ? me.name : displayName
        me.pronouns = pronouns.isEmpty ? nil : pronouns
        familyStore.updateMember(me)
    }
}

extension ProfileView {
    /// Sheet binding for the avatar picker — declared in an extension so
    /// the existing body block stays small.
    @ViewBuilder
    fileprivate func avatarPickerSheet() -> some View {
        if let me = familyStore.me {
            AvatarPickerSheet(memberId: me.id)
        }
    }
}

/// Grid of all bundled avatars. Tap to pick. Used by Profile and the
/// per-member edit form on Family management.
struct AvatarPickerSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var familyStore = FamilyStore.shared

    let memberId: UUID

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(AvatarCatalog.all, id: \.self) { id in
                        Button { pick(id) } label: {
                            if let img = AvatarCatalog.image(for: id) {
                                img
                                    .resizable()
                                    .interpolation(.high)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 60)
                                    .padding(4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(currentId == id ? theme.palette.highlightSoft : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(currentId == id ? theme.palette.ink : Color.clear,
                                                    lineWidth: 2)
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                Text("Avatars designed by Flaticon")
                    .font(theme.typography.font(.handFlow, size: 11))
                    .foregroundColor(theme.palette.ink3)
                    .padding(.bottom, 12)
            }
            .navigationTitle("Pick an avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .background(theme.palette.paper.ignoresSafeArea())
        }
    }

    private var currentId: String? {
        familyStore.member(memberId)?.avatarId
    }
    private func pick(_ id: String) {
        guard var m = familyStore.member(memberId) else { return }
        m.avatarId = id
        familyStore.updateMember(m)
    }
}

// MARK: - Quiet hours

struct QuietHoursView: View {
    @Environment(\.theme) var theme
    @State private var prefs: QuietHoursPrefs = .load()

    var body: some View {
        Form {
            Section {
                Toggle("Quiet hours on", isOn: $prefs.enabled)
            } footer: {
                Text("Critical alerts always break through quiet hours.")
                    .font(theme.typography.font(.handFlow, size: 12))
            }

            if prefs.enabled {
                Section("Window") {
                    timePicker(label: "Start", minute: $prefs.startMinute)
                    timePicker(label: "End", minute: $prefs.endMinute)
                    Text(rangeDescription)
                        .font(theme.typography.font(.handFlow, size: 12))
                        .foregroundColor(theme.palette.ink3)
                }

                Section("During quiet hours, allow") {
                    Picker("Allow level", selection: $prefs.allowDuringQuiet) {
                        Text("Critical only").tag(QuietHoursPrefs.AllowLevel.criticalOnly)
                        Text("Heads-up + critical").tag(QuietHoursPrefs.AllowLevel.headsUpAndCritical)
                        Text("Everything").tag(QuietHoursPrefs.AllowLevel.all)
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section {
                Button("Save") {
                    prefs.save()
                }
                .fontWeight(.bold)
            }
        }
        .navigationTitle("Quiet hours")
        .navigationBarTitleDisplayMode(.inline)
        .background(theme.palette.paper.ignoresSafeArea())
    }

    private var rangeDescription: String {
        let s = format(minutes: prefs.startMinute)
        let e = format(minutes: prefs.endMinute)
        if prefs.endMinute < prefs.startMinute {
            return "Quiet from \(s) tonight to \(e) the next morning."
        }
        return "Quiet from \(s) to \(e)."
    }
    private func format(minutes: Int) -> String {
        let h = (minutes / 60) % 24
        let m = minutes % 60
        let d = Calendar.current.date(from: DateComponents(hour: h, minute: m))!
        return d.formatted(date: .omitted, time: .shortened)
    }
    @ViewBuilder
    private func timePicker(label: String, minute: Binding<Int>) -> some View {
        let date = Binding<Date>(
            get: {
                let h = (minute.wrappedValue / 60) % 24
                let m = minute.wrappedValue % 60
                return Calendar.current.date(from: DateComponents(hour: h, minute: m)) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                minute.wrappedValue = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            }
        )
        DatePicker(label, selection: date, displayedComponents: .hourAndMinute)
    }
}

// MARK: - Privacy & permissions

struct PrivacyPermissionsView: View {
    @Environment(\.theme) var theme
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var notificationDelivery = NotificationDelivery.shared
    @ObservedObject private var presenceStore = PresenceStore.shared
    @ObservedObject private var familyStore = FamilyStore.shared

    // Pilot kill-switches — flipped via Diagnostics section.
    @AppStorage("halowalk.safe.locationStart") private var safeLocationStart = true
    @AppStorage("halowalk.safe.regionMonitoring") private var safeRegionMonitoring = true
    @AppStorage("halowalk.safe.notifications") private var safeNotifications = true
    @AppStorage("halowalk.safe.watchConnectivity") private var safeWatchConnectivity = true
    @AppStorage("halowalk.safe.cloudSync") private var safeCloudSync = true
    @State private var showingLog = false

    var body: some View {
        Form {
            Section("Permissions") {
                permissionRow(
                    title: "Location",
                    detail: locationDetail,
                    state: locationState,
                    action: handleLocationTap
                )
                permissionRow(
                    title: "Notifications",
                    detail: notificationDetail,
                    state: notificationState,
                    action: handleNotificationTap
                )
            }

            if let me = familyStore.me, familyStore.isGuardian(me.id) {
                Section("Sharing my location with the family") {
                    Toggle("Share my location", isOn: Binding(
                        get: { me.sharesLocation },
                        set: { newVal in
                            var updated = me
                            updated.locationSharingEnabled = newVal
                            familyStore.updateMember(updated)
                            if newVal {
                                presenceStore.guardiansSharing.insert(me.id)
                            } else {
                                presenceStore.removeReadings(for: me.id)
                                HaloCloudSync.shared.deleteLocationReadings(for: me.id)
                            }
                        }
                    ))
                }
            }

            Section {
                Button("Open System Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } footer: {
                Text("If a permission was denied, change it in System Settings → HaloWalk.")
                    .font(theme.typography.font(.handFlow, size: 12))
            }

            // MARK: - Pilot diagnostics
            Section("Pilot diagnostics — kill switches") {
                Toggle("Start location updates on launch", isOn: $safeLocationStart)
                Toggle("Region monitoring on launch", isOn: $safeRegionMonitoring)
                Toggle("Request notification permission on launch", isOn: $safeNotifications)
                Toggle("Activate WatchConnectivity on launch", isOn: $safeWatchConnectivity)
                Toggle("CloudKit sync on launch", isOn: $safeCloudSync)
            }
            Section {
                Button("View launch log") { showingLog = true }
                Button("Reset launch log") { LaunchLog.reset() }
                    .foregroundColor(theme.palette.haloRed)
            } footer: {
                Text("If the app freezes on launch, force-quit and toggle one of the kill switches off above, then relaunch. The launch log shows the last step before a freeze — share it to identify which subsystem is hanging.")
                    .font(theme.typography.font(.handFlow, size: 12))
            }
        }
        .sheet(isPresented: $showingLog) {
            LaunchLogView()
        }
        .navigationTitle("Privacy & permissions")
        .navigationBarTitleDisplayMode(.inline)
        .background(theme.palette.paper.ignoresSafeArea())
        .onAppear {
            notificationDelivery.refresh()
        }
    }

    private enum PermissionState { case granted, partial, denied, undetermined }
    @ViewBuilder
    private func permissionRow(title: String, detail: String, state: PermissionState, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(theme.typography.font(.handTight, size: 14, weight: .bold))
                        .foregroundColor(theme.palette.ink)
                    Text(detail)
                        .font(theme.typography.font(.handFlow, size: 12))
                        .foregroundColor(theme.palette.ink3)
                }
                Spacer()
                statusBadge(state)
            }
        }
        .buttonStyle(.plain)
    }

    private func statusBadge(_ state: PermissionState) -> some View {
        let (label, color): (String, Color) = {
            switch state {
            case .granted:      return ("Granted", theme.palette.haloGreen)
            case .partial:      return ("Partial",  theme.palette.haloYellow)
            case .denied:       return ("Denied",   theme.palette.haloRed)
            case .undetermined: return ("Not asked", theme.palette.ink3)
            }
        }()
        return Text(label)
            .font(theme.typography.font(.handTight, size: 10, weight: .bold))
            .foregroundColor(theme.palette.paper)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color))
    }

    // MARK: Location

    private var locationState: PermissionState {
        switch locationManager.authorization {
        case .authorizedAlways:    return .granted
        case .authorizedWhenInUse: return .partial
        case .denied, .restricted: return .denied
        case .notDetermined:       return .undetermined
        @unknown default:          return .undetermined
        }
    }
    private var locationDetail: String {
        switch locationManager.authorization {
        case .authorizedAlways:
            return "Background updates enabled — triggers fire even when the app is closed."
        case .authorizedWhenInUse:
            return "Foreground only. Tap to upgrade to Always so background triggers fire."
        case .denied, .restricted:
            return "Location is required for halos. Open System Settings to enable."
        case .notDetermined:
            return "Tap to grant location access."
        @unknown default:
            return "Unknown state."
        }
    }
    private func handleLocationTap() {
        switch locationManager.authorization {
        case .notDetermined:
            locationManager.requestPermission()
        case .authorizedWhenInUse:
            locationManager.requestAlwaysPermission()
        default:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }

    // MARK: Notifications

    private var notificationState: PermissionState {
        switch notificationDelivery.authorization {
        case .authorized, .provisional, .ephemeral: return .granted
        case .denied:        return .denied
        case .notDetermined: return .undetermined
        @unknown default:    return .undetermined
        }
    }
    private var notificationDetail: String {
        switch notificationDelivery.authorization {
        case .authorized, .provisional, .ephemeral:
            return "HaloWalk can buzz when triggers fire."
        case .denied:
            return "Notifications denied. Open System Settings to re-enable."
        case .notDetermined:
            return "Tap to allow notifications."
        @unknown default:
            return "Unknown state."
        }
    }
    private func handleNotificationTap() {
        switch notificationDelivery.authorization {
        case .notDetermined:
            Task { await notificationDelivery.requestPermission() }
        default:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }
}

// MARK: - About (still here)

struct AboutView: View {
    @Environment(\.theme) var theme
    @AppStorage("halowalk.onboarding.complete") private var onboardingComplete = false
    @State private var showResetConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 8) {
                Image("HaloWalkMark")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.bottom, 4)
                Image("HaloWalkWordmark")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 28)
                Text("0.1.0 · pilot")
                    .font(theme.typography.font(.handFlow, size: 14))
                    .foregroundColor(theme.palette.ink3)
                Text("for the families we love ♡")
                    .font(theme.typography.font(.handFlow, size: 14))
                    .foregroundColor(theme.palette.ink3)
                    .padding(.top, 16)

                Divider().padding(.vertical, 24)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Pilot diagnostics")
                        .font(theme.typography.font(.handTight, size: 11))
                        .tracking(0.6)
                        .foregroundColor(theme.palette.ink3)

                    Button {
                        showResetConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Re-run onboarding")
                                .font(theme.typography.font(.handTight, size: 13, weight: .bold))
                        }
                        .foregroundColor(theme.palette.ink)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity)
                        .sketchBorder(padding: 0)
                    }
                    .buttonStyle(.plain)

                    Text("Re-launches the welcome flow. Hubs and family stay where they are.")
                        .font(theme.typography.font(.handFlow, size: 12))
                        .foregroundColor(theme.palette.ink3)
                }
                .padding(.horizontal, 8)

                Divider().padding(.vertical, 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Credits")
                        .font(theme.typography.font(.handTight, size: 11))
                        .tracking(0.6)
                        .foregroundColor(theme.palette.ink3)
                    Text("Avatars designed by Flaticon (Free License with attribution).")
                        .font(theme.typography.font(.handFlow, size: 12))
                        .foregroundColor(theme.palette.ink2)
                    Text("Fonts: Patrick Hand, Quicksand, Inter, Fredoka One, Nunito, Caveat, Kalam, Architects Daughter — Google Fonts (SIL Open Font License).")
                        .font(theme.typography.font(.handFlow, size: 12))
                        .foregroundColor(theme.palette.ink2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .background(theme.palette.paper.ignoresSafeArea())
        .confirmationDialog(
            "Re-run onboarding?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Re-run") {
                onboardingComplete = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The welcome flow will appear next time you launch HaloWalk. Your hubs and family stay.")
        }
    }
}
