import SwiftUI

struct FamilySharingJoinSetupView: View {
    @Environment(\.theme) var theme
    @ObservedObject private var auth = AppleAuthManager.shared
    @ObservedObject private var familyStore = FamilyStore.shared

    let onComplete: () -> Void

    @State private var selectedRole: FamilyStore.JoinRole = .guardian
    @State private var sharesLocation = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Join \(familyStore.family.name)")
                        .font(theme.typography.font(.handTight, size: 30, weight: .bold))
                        .foregroundColor(theme.palette.ink)
                    Text("Choose how you appear to the family before HaloWalk starts sharing your status.")
                        .font(theme.typography.font(.handFlow, size: 15))
                        .foregroundColor(theme.palette.ink2)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Role")
                        .font(theme.typography.font(.handTight, size: 11))
                        .tracking(0.6)
                        .foregroundColor(theme.palette.ink3)
                    ForEach(FamilyStore.JoinRole.allCases) { role in
                        Button {
                            selectedRole = role
                        } label: {
                            HStack {
                                Image(systemName: selectedRole == role ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedRole == role ? theme.palette.haloGreen : theme.palette.ink3)
                                Text(role.title)
                                    .font(theme.typography.font(.handTight, size: 15, weight: .bold))
                                Spacer()
                            }
                            .padding(12)
                            .sketchBorder(seed: role.rawValue.hashValue, padding: 0)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Toggle(isOn: $sharesLocation) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Share this iPhone's location")
                            .font(theme.typography.font(.handTight, size: 15, weight: .bold))
                        Text("You can turn this off later. When off, HaloWalk removes your pin from the family map.")
                            .font(theme.typography.font(.handFlow, size: 12))
                            .foregroundColor(theme.palette.ink3)
                    }
                }
                .toggleStyle(.switch)
                .padding(12)
                .sketchBorder(padding: 0)

                if auth.isSignedIn {
                    SketchButton("Join family", kind: .green) {
                        complete()
                    }
                } else {
                    SketchButton(.ink, action: { auth.signIn() }) {
                        HStack {
                            if auth.isAuthorizing {
                                ProgressView().tint(theme.palette.paper)
                            } else {
                                Image(systemName: "applelogo")
                            }
                            Text("Sign in with Apple")
                        }
                    }
                }

                if let err = auth.lastError {
                    Text(err)
                        .font(theme.typography.font(.handFlow, size: 12))
                        .foregroundColor(theme.palette.haloRed)
                }
            }
            .padding(20)
        }
        .background(theme.palette.paper.ignoresSafeArea())
        .onChange(of: auth.identity) { _, newValue in
            guard newValue != nil else { return }
            if auth.isSignedIn { complete() }
        }
    }

    private func complete() {
        guard let identity = auth.identity else {
            auth.signIn()
            return
        }
        familyStore.configureJoinedAccount(
            appleUserId: identity.userId,
            fullName: identity.fullName,
            email: identity.email,
            role: selectedRole,
            sharesLocation: sharesLocation
        )
        if !sharesLocation {
            PresenceStore.shared.removeReadings(for: familyStore.account.memberId)
            HaloCloudSync.shared.deleteLocationReadings(for: familyStore.account.memberId)
        }
        HaloCloudSync.shared.forceResync()
        onComplete()
    }
}
