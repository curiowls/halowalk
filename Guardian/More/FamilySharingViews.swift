import SwiftUI
import UIKit
import CloudKit

struct CloudFamilySharingSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var preparedShare: PreparedShare?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let preparedShare {
                CloudSharingController(preparedShare: preparedShare)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 14) {
                    if let errorMessage {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(theme.palette.haloRed)
                        Text("Could not prepare invite")
                            .font(theme.typography.font(.handTight, size: 20, weight: .bold))
                            .foregroundColor(theme.palette.ink)
                        Text(errorMessage)
                            .font(theme.typography.font(.handFlow, size: 13))
                            .foregroundColor(theme.palette.ink3)
                            .multilineTextAlignment(.leading)
                            .textSelection(.enabled)
                        HStack(spacing: 12) {
                            Button {
                                UIPasteboard.general.string = errorMessage
                            } label: {
                                Label("Copy error", systemImage: "doc.on.doc")
                            }
                            Button("Close") { dismiss() }
                        }
                        .font(theme.typography.font(.handTight, size: 15, weight: .bold))
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    } else {
                        ProgressView()
                            .tint(theme.palette.ink)
                        Text("Preparing family invite...")
                            .font(theme.typography.font(.handTight, size: 17, weight: .bold))
                            .foregroundColor(theme.palette.ink)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.palette.paper.ignoresSafeArea())
                .task { await prepareShare() }
            }
        }
    }

    private func prepareShare() async {
        guard preparedShare == nil, errorMessage == nil else { return }
        do {
            let prepared = try await HaloCloudSync.shared.familyShareForPresentation()
            preparedShare = PreparedShare(share: prepared.0, container: prepared.1)
        } catch {
            HaloCloudSync.shared.note("CloudFamilySharingSheet prepare failed: \(error.localizedDescription)")
            errorMessage = inviteErrorMessage(error)
        }
    }

    private func inviteErrorMessage(_ error: Error) -> String {
        guard let ck = error as? CKError else { return error.localizedDescription }
        var lines = [
            "CloudKit \(ck.code.rawValue) (\(ck.code)): \(ck.localizedDescription)"
        ]
        for (item, itemError) in (ck.partialErrorsByItemID ?? [:]).sorted(by: { "\($0.key)" < "\($1.key)" }) {
            if let itemCK = itemError as? CKError {
                lines.append("\(item): \(itemCK.code.rawValue) (\(itemCK.code)) \(itemCK.localizedDescription)")
            } else {
                lines.append("\(item): \(itemError.localizedDescription)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

private struct PreparedShare {
    let share: CKShare
    let container: CKContainer
}

private struct CloudSharingController: UIViewControllerRepresentable {
    let preparedShare: PreparedShare

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(
            share: preparedShare.share,
            container: preparedShare.container
        )
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
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
