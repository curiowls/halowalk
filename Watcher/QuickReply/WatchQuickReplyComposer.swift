import SwiftUI

/// Compose a quick reply to a specific guardian. Templates only — typing
/// on a watch is impractical and the wearer's most common need is one
/// of a handful of short statuses ("I'm here", "On my way", "Need help").
/// Sends via WatchSync; iPhone surfaces it as a local notification.
struct WatchQuickReplyComposer: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var familyStore: FamilyStore
    @EnvironmentObject var watchSync: WatchSync

    let toMemberId: UUID

    /// Pre-canned replies. The first three are the design's quick
    /// statuses; the fourth is a soft signal of distress without
    /// jumping straight to SOS.
    private let templates: [Template] = [
        .init(label: "I'm here ♡", body: "I'm here."),
        .init(label: "On my way", body: "On my way."),
        .init(label: "Running late", body: "Running a bit late."),
        .init(label: "Need help", body: "I need help — please check on me.")
    ]

    @State private var sentLabel: String?

    private var recipient: Member? { familyStore.member(toMemberId) }
    private var senderId: UUID { familyStore.account.memberId }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if let recipient {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle().fill(recipient.accentColor)
                            Text(recipient.initial)
                                .font(theme.typography.font(.handTight, size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 22, height: 22)
                        Text("To \(recipient.displayName)")
                            .font(theme.typography.font(.handTight, size: 11, weight: .bold))
                            .foregroundColor(theme.palette.watchForeground)
                            .lineLimit(1)
                    }
                    .padding(.top, 4)
                }

                ForEach(templates) { template in
                    Button {
                        send(template)
                    } label: {
                        HStack {
                            Text(template.label)
                                .font(theme.typography.font(.handTight, size: 12, weight: .bold))
                                .foregroundColor(theme.palette.watchForeground)
                            Spacer()
                            if sentLabel == template.label {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(theme.palette.haloGreen)
                            }
                        }
                        .padding(8)
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

                if sentLabel != nil {
                    Text("Sent.")
                        .font(theme.typography.font(.handFlow, size: 10))
                        .foregroundColor(theme.palette.watchMuted)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 12)
        }
        .navigationTitle(recipient?.displayName ?? "Reply")
        .background(theme.palette.watchBackground.ignoresSafeArea())
    }

    private func send(_ template: Template) {
        watchSync.sendMessage(
            fromMemberId: senderId,
            toMemberId: toMemberId,
            body: template.body
        )
        sentLabel = template.label
        // Brief confirmation, then pop back so the watch doesn't sit on
        // a dead-end screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }

    private struct Template: Identifiable {
        let id = UUID()
        let label: String
        let body: String
    }
}
