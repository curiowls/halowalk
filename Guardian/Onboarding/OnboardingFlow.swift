import SwiftUI
import AuthenticationServices

/// Onboarding flow that runs the first time HaloWalk launches. Build 5+
/// ships the skeleton — Apple integrations land in Build 7.
struct OnboardingFlow: View {
    @Environment(\.theme) var theme
    @AppStorage("halowalk.onboarding.complete") private var complete = false

    @State private var step: Step = .welcome

    enum Step: Int, CaseIterable {
        case welcome = 0
        case signIn
        case detectFamily
        case watches
        case firstHub
        case done
    }

    /// All sub-views read these as plain `let` parameters — no
    /// @EnvironmentObject / @ObservedObject in the sub-views, because
    /// SwiftUI's animated transitions on iOS 26 have been crashing on
    /// observable-object subscription during step changes.
    private var members: [Member] { FamilyStore.shared.members }
    private var wearers: [Member] { FamilyStore.shared.watchedMembers }
    private var accountId: UUID { FamilyStore.shared.account.memberId }

    var body: some View {
        ZStack {
            theme.palette.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                ProgressDots(current: step.rawValue, total: Step.allCases.count - 1)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            WelcomeStep(onContinue: { step = .signIn })
        case .signIn:
            SignInStep(onContinue: { step = .detectFamily })
        case .detectFamily:
            FamilyDetectStep(
                members: members,
                onContinue: { step = .watches }
            )
        case .watches:
            WatchesStep(
                wearers: wearers,
                onContinue: { step = .firstHub }
            )
        case .firstHub:
            FirstHubStep(
                wearerIds: wearers.map(\.id),
                accountId: accountId,
                onContinue: { step = .done }
            )
        case .done:
            DoneStep(onFinish: { complete = true })
        }
    }
}

// MARK: - Progress dots

private struct ProgressDots: View {
    @Environment(\.theme) var theme
    let current: Int
    let total: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? theme.palette.ink : theme.palette.paper2)
                    .frame(width: i == current ? 16 : 8, height: 4)
                    .overlay(Capsule().stroke(theme.palette.line, lineWidth: 0.8))
            }
        }
    }
}

// MARK: - Welcome

private struct WelcomeStep: View {
    @Environment(\.theme) var theme
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image("HaloWalkMark")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            Image("HaloWalkWordmark")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(height: 44)
                .foregroundColor(theme.palette.ink)
                .padding(.top, 14)
            Text("Let your kids and parents roam.")
                .font(theme.typography.font(.handFlow, size: 22))
                .foregroundColor(theme.palette.ink2)
                .padding(.top, 4)
            Text("With a halo around the people you love.")
                .font(theme.typography.font(.handFlow, size: 18))
                .foregroundColor(theme.palette.ink3)
            Spacer()
            PrimaryButton(title: "Set up my family", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
        }
    }
}

private struct HaloMotif: View {
    @Environment(\.theme) var theme
    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.palette.haloGreen,
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .frame(width: 180, height: 180)
            Circle()
                .stroke(theme.palette.haloPink,
                        style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .frame(width: 130, height: 130)
            Circle()
                .stroke(theme.palette.haloYellow,
                        style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .frame(width: 80, height: 80)
            Text("♡")
                .font(.system(size: 36))
                .foregroundColor(theme.palette.haloPink)
        }
    }
}

// MARK: - Sign in (Build 7: real Sign in with Apple)

private struct SignInStep: View {
    @Environment(\.theme) var theme
    @ObservedObject private var auth = AppleAuthManager.shared
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                Text("Sign in")
                    .font(theme.typography.font(.handTight, size: 32, weight: .bold))
                Text("HaloWalk uses your Apple ID to remember your family across devices. It's also how family invites will find you.")
                    .font(theme.typography.font(.handFlow, size: 16))
                    .foregroundColor(theme.palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            Spacer()
            VStack(spacing: 12) {
                if auth.isSignedIn {
                    // Already signed in (e.g. re-running onboarding) —
                    // confirm + continue.
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(theme.palette.haloGreen)
                        Text(signedInLabel)
                            .font(theme.typography.font(.handTight, size: 14, weight: .bold))
                            .foregroundColor(theme.palette.ink)
                    }
                    PrimaryButton(title: "Continue", action: onContinue)
                } else {
                    // One code path: AppleAuthManager owns the
                    // ASAuthorization flow + Keychain persistence, so we
                    // use a themed button rather than SignInWithAppleButton
                    // (which would run its own parallel flow).
                    Button {
                        auth.signIn()
                    } label: {
                        HStack(spacing: 8) {
                            if auth.isAuthorizing {
                                ProgressView()
                                    .tint(theme.palette.paper)
                            } else {
                                Image(systemName: "applelogo").font(.system(size: 18))
                            }
                            Text("Sign in with Apple")
                                .font(theme.typography.font(.handTight, size: 15, weight: .bold))
                        }
                        .foregroundColor(theme.palette.paper)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Capsule().fill(.black))
                        .overlay(Capsule().stroke(theme.palette.line, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(auth.isAuthorizing)

                    if let err = auth.lastError {
                        Text(err)
                            .font(theme.typography.font(.handFlow, size: 12))
                            .foregroundColor(theme.palette.haloRed)
                            .multilineTextAlignment(.center)
                    }
                    Button("Skip for now") { onContinue() }
                        .font(theme.typography.font(.handTight, size: 13))
                        .foregroundColor(theme.palette.ink3)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .onChange(of: auth.identity) { _, newValue in
            guard let id = newValue else { return }
            FamilyStore.shared.linkAppleIdentity(
                userId: id.userId, fullName: id.fullName, email: id.email
            )
            // Small beat so the success state is visible, then advance.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                onContinue()
            }
        }
    }

    private var signedInLabel: String {
        if let name = auth.identity?.fullName, !name.isEmpty {
            return "Signed in as \(name)"
        }
        if let email = auth.identity?.email, !email.isEmpty {
            return "Signed in as \(email)"
        }
        return "Signed in with Apple"
    }
}

// MARK: - Family detection — receives [Member] as a value parameter so there's
// no observable-object subscription happening inside the sub-view. This is
// the step that was crashing in builds 5/6.

private struct FamilyDetectStep: View {
    @Environment(\.theme) var theme
    let members: [Member]
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your family")
                    .font(theme.typography.font(.handTight, size: 28, weight: .bold))
                Text("Apple Family Sharing detection arrives in Build 7. For now, here's a demo family you can edit.")
                    .font(theme.typography.font(.handFlow, size: 14))
                    .foregroundColor(theme.palette.ink3)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(members) { m in
                        DetectedMemberRow(member: m)
                    }
                    Button {} label: {
                        Text("+ Add someone manually")
                            .font(theme.typography.font(.handFlow, size: 16))
                            .foregroundColor(theme.palette.ink2)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .sketchBorder(dashed: true, padding: 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }

            PrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
        }
    }
}

private struct DetectedMemberRow: View {
    @Environment(\.theme) var theme
    let member: Member

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(member.accentColor.opacity(0.4))
                Circle().stroke(theme.palette.line, lineWidth: 1.5)
                Text(member.initial)
                    .font(theme.typography.font(.handTight, size: 16, weight: .bold))
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(theme.typography.font(.handTight, size: 15, weight: .bold))
                Text(FamilyStore.shared.isGuardian(member.id) ? "guardian · iPhone" : "wearer · Apple Watch")
                    .font(theme.typography.font(.handFlow, size: 12))
                    .foregroundColor(theme.palette.ink3)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(theme.palette.haloGreen)
        }
        .padding(10)
        .sketchBorder(seed: member.id.uuidString.hashValue, padding: 0)
    }
}

// MARK: - Watches

private struct WatchesStep: View {
    @Environment(\.theme) var theme
    let wearers: [Member]
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Watches")
                    .font(theme.typography.font(.handTight, size: 28, weight: .bold))
                Text("HaloWalk installs on each wearer's Apple Watch automatically — no setup on the watch itself.")
                    .font(theme.typography.font(.handFlow, size: 15))
                    .foregroundColor(theme.palette.ink2)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(wearers) { wearer in
                        HStack(spacing: 12) {
                            Image(systemName: "applewatch")
                                .font(.system(size: 28))
                                .foregroundColor(theme.palette.ink2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(wearer.displayName)'s Apple Watch")
                                    .font(theme.typography.font(.handTight, size: 14, weight: .bold))
                                Text("paired · ready to install")
                                    .font(theme.typography.font(.handFlow, size: 12))
                                    .foregroundColor(theme.palette.ink3)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(theme.palette.haloGreen)
                        }
                        .padding(10)
                        .sketchBorder(seed: wearer.id.uuidString.hashValue, padding: 0)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }

            PrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
        }
    }
}

// MARK: - First hub

private struct FirstHubStep: View {
    @Environment(\.theme) var theme
    let wearerIds: [UUID]
    let accountId: UUID
    let onContinue: () -> Void

    @State private var locationLabel: String = "Waiting for GPS fix…"
    @State private var hasFix: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Drop your first halo")
                    .font(theme.typography.font(.handTight, size: 28, weight: .bold))
                Text("A halo is a soft circle around a place that matters — Home is usually the first one. We'll save it where you're standing.")
                    .font(theme.typography.font(.handFlow, size: 15))
                    .foregroundColor(theme.palette.ink2)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: hasFix ? "location.fill" : "location.slash")
                        .font(.system(size: 18))
                        .foregroundColor(hasFix ? theme.palette.haloGreen : theme.palette.ink3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Home")
                            .font(theme.typography.font(.handTight, size: 16, weight: .bold))
                        Text(locationLabel)
                            .font(theme.typography.font(.handFlow, size: 12))
                            .foregroundColor(theme.palette.ink3)
                    }
                    Spacer()
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .sketchBorder(dashed: !hasFix, padding: 0)
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 8) {
                PrimaryButton(title: hasFix ? "Save as Home" : "Skip for now", action: save)
                Button("Skip for now") {
                    onContinue()
                }
                .font(theme.typography.font(.handTight, size: 13))
                .foregroundColor(theme.palette.ink3)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .onAppear { refreshLocation() }
        .task {
            // Refresh every second so the user sees the GPS arrive without
            // having to subscribe to LocationManager via @ObservedObject.
            for _ in 0..<10 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run { refreshLocation() }
                if hasFix { break }
            }
        }
    }

    private func refreshLocation() {
        if let loc = LocationManager.shared.current {
            hasFix = true
            locationLabel = String(format: "%.5f, %.5f · ± %.0f m",
                                   loc.coordinate.latitude,
                                   loc.coordinate.longitude,
                                   loc.horizontalAccuracy)
        } else {
            hasFix = false
            locationLabel = "Waiting for GPS fix…"
        }
    }

    private func save() {
        if let loc = LocationManager.shared.current {
            // Idempotent: onboarding re-runs on every reinstall (the
            // `onboarding.complete` flag is wiped with the app). Creating
            // a fresh "Home" each time accumulated duplicate Home hubs in
            // CloudKit. Update the canonical Home in place instead.
            HubStore.shared.setHomeToCurrentLocation(
                coordinate: loc.coordinate,
                assignedTo: wearerIds,
                createdBy: accountId
            )
        }
        onContinue()
    }
}

// MARK: - Done

private struct DoneStep: View {
    @Environment(\.theme) var theme
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            HaloMotif()
                .frame(width: 200, height: 200)
            Text("All set ♡")
                .font(theme.typography.font(.handTight, size: 38, weight: .bold))
                .padding(.top, 12)
            Text("Your family is connected. The app will mostly stay quiet — only buzzing when it actually matters.")
                .font(theme.typography.font(.handFlow, size: 16))
                .foregroundColor(theme.palette.ink2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 8)
            Spacer()
            PrimaryButton(title: "Open HaloWalk", action: onFinish)
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
        }
    }
}

// MARK: - Shared button

private struct PrimaryButton: View {
    @Environment(\.theme) var theme
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(theme.typography.font(.handTight, size: 14, weight: .bold))
                .foregroundColor(theme.palette.paper)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(theme.palette.ink))
                .overlay(Capsule().stroke(theme.palette.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}
