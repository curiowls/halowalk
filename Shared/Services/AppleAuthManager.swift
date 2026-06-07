import Foundation
import AuthenticationServices
import Combine

/// Wraps Sign in with Apple. Build A of the CloudKit track — establishes a
/// stable per-user identity. The Apple `user` identifier is the durable key
/// (it never changes for a given Apple ID + app, and is the same across the
/// user's devices), so it's what we'll later use to key the CloudKit
/// family-share participant lookup.
///
/// We persist the identifier in the Keychain (Apple's guidance — not
/// UserDefaults) plus the display name / email, which Apple only hands over
/// on the *first* authorization. On every launch we re-check
/// `getCredentialState` so a revoked / signed-out Apple ID drops us back to
/// the signed-out state.
@MainActor
final class AppleAuthManager: NSObject, ObservableObject {
    static let shared = AppleAuthManager()

    struct Identity: Codable, Equatable {
        let userId: String          // ASAuthorizationAppleIDCredential.user
        var fullName: String?       // only present on first sign-in
        var email: String?          // only present on first sign-in
    }

    @Published private(set) var identity: Identity?
    @Published private(set) var isAuthorizing = false
    @Published private(set) var lastError: String?

    var isSignedIn: Bool { identity != nil }

    private let keychainAccount = "halowalk.appleAuth.identity.v1"
    private var pendingCompletion: ((Result<Identity, Error>) -> Void)?

    private override init() {
        super.init()
        self.identity = Self.loadFromKeychain(account: keychainAccount)
    }

    // MARK: - Launch revalidation

    /// Call once at launch. If the Apple ID was revoked / signed out at the
    /// system level, clear our local identity so the UI returns to signed-out.
    func revalidateOnLaunch() {
        guard let id = identity else { return }
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: id.userId) { [weak self] state, _ in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .authorized:
                    break  // still good
                case .revoked, .notFound:
                    self.signOutLocally()
                case .transferred:
                    // App was transferred between dev teams — rare; treat
                    // as still-valid for the pilot.
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: - Sign in

    func signIn() {
        isAuthorizing = true
        lastError = nil
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        #if os(iOS)
        controller.presentationContextProvider = self
        #endif
        controller.performRequests()
    }

    func signOutLocally() {
        // Apple provides no programmatic sign-out; we just forget the
        // identity locally. The user manages the Apple ID link in
        // Settings → Apple ID → Sign in with Apple.
        identity = nil
        Self.deleteFromKeychain(account: keychainAccount)
    }

    // MARK: - Keychain

    private static func saveToKeychain(_ identity: Identity, account: String) {
        guard let data = try? JSONEncoder().encode(identity) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
    private static func loadFromKeychain(account: String) -> Identity? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data,
              let id = try? JSONDecoder().decode(Identity.self, from: data)
        else { return nil }
        return id
    }
    private static func deleteFromKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    fileprivate func persist(_ identity: Identity) {
        // Merge: name/email only arrive on first sign-in. If a later
        // sign-in omits them, keep what we already had.
        var merged = identity
        if let existing = self.identity, existing.userId == identity.userId {
            merged.fullName = identity.fullName ?? existing.fullName
            merged.email = identity.email ?? existing.email
        }
        self.identity = merged
        Self.saveToKeychain(merged, account: keychainAccount)
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleAuthManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        let nameParts = [cred.fullName?.givenName, cred.fullName?.familyName].compactMap { $0 }
        let fullName = nameParts.isEmpty ? nil : nameParts.joined(separator: " ")
        let identity = Identity(userId: cred.user, fullName: fullName, email: cred.email)
        Task { @MainActor in
            self.isAuthorizing = false
            self.persist(identity)
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            self.isAuthorizing = false
            // User-cancelled is not an error worth surfacing.
            if (error as? ASAuthorizationError)?.code == .canceled {
                self.lastError = nil
            } else {
                self.lastError = error.localizedDescription
            }
        }
    }
}

// MARK: - Presentation anchor (iOS only — watchOS inherits identity from
// the paired phone via WatchSync, it never runs the ASAuthorization UI).

#if os(iOS)
import UIKit

extension AppleAuthManager: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
            return windowScene?.keyWindow ?? ASPresentationAnchor()
        }
    }
}

private extension UIWindowScene {
    var keyWindow: UIWindow? { windows.first { $0.isKeyWindow } }
}
#endif
