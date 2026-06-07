import SwiftUI
import UIKit
import CloudKit

struct CloudFamilySharingSheet: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: { dismiss() })
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController { _, completion in
            HaloCloudSync.shared.prepareFamilyShare(completion: completion)
        }
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            HaloCloudSync.shared.forceResync()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            HaloCloudSync.shared.forceResync()
        }

        func cloudSharingController(
            _ csc: UICloudSharingController,
            failedToSaveShareWithError error: Error
        ) {
            HaloCloudSync.shared.note("UICloudSharingController failed: \(error.localizedDescription)")
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            FamilyStore.shared.family.name
        }
    }
}
