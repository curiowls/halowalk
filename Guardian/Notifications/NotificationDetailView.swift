import SwiftUI

/// Pushed when the user taps a notification. Shows full text, the related
/// member, and a primary "Respond" button + secondary actions. Per the
/// design conversation, this is the primary entry point for Quick Reply /
/// Nudge / Head Out actions.
struct NotificationDetailView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationStore: NotificationStore
    @EnvironmentObject var familyStore: FamilyStore

    let notificationId: UUID
    let onSeeMember: (UUID) -> Void

    @State private var presentedRespond: AppNotification.RespondKind?

    private var notification: AppNotification? {
        notificationStore.notifications.first { $0.id == notificationId }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let n = notification {
                    SeverityBanner(severity: n.severity)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(n.title)
                            .font(theme.typography.font(.handTight, size: 22, weight: .bold))
                        Text(n.body)
                            .font(theme.typography.font(.handFlow, size: 15))
                            .foregroundColor(theme.palette.ink2)
                        Text(timestamp(n.timestamp))
                            .font(theme.typography.font(.handFlow, size: 12))
                            .foregroundColor(theme.palette.ink3)
                    }

                    if let memberId = n.aboutMemberId,
                       let member = familyStore.member(memberId) {
                        Button { onSeeMember(memberId) } label: {
                            MemberRow(member: member)
                        }
                        .buttonStyle(.plain)
                    }

                    if let suggested = n.suggestedRespond {
                        PrimaryRespondButton(kind: suggested) {
                            presentedRespond = suggested
                        }
                    }

                    SecondaryRespondActions(
                        excluded: n.suggestedRespond,
                        onAction: { presentedRespond = $0 }
                    )

                    Button(role: .destructive) {
                        notificationStore.dismiss(n.id)
                        dismiss()
                    } label: {
                        Label("Dismiss notification", systemImage: "xmark.circle")
                            .font(theme.typography.font(.handTight, size: 13))
                    }
                    .padding(.top, 8)
                } else {
                    Text("Notification not found.")
                        .font(theme.typography.font(.handFlow, size: 14))
                        .foregroundColor(theme.palette.ink3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.paper.ignoresSafeArea())
        .navigationTitle("Notification")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $presentedRespond) { kind in
            respondSheet(for: kind)
        }
    }

    @ViewBuilder
    private func respondSheet(for kind: AppNotification.RespondKind) -> some View {
        if let n = notification, let memberId = n.aboutMemberId {
            NavigationStack {
                switch kind {
                case .quickReply: RespondQuickReplyView(toMemberId: memberId)
                case .nudgeHome:  RespondNudgeHomeView(toMemberId: memberId)
                case .headOut:    RespondHeadOutView(toMemberId: memberId)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func timestamp(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }
}

private struct SeverityBanner: View {
    @Environment(\.theme) var theme
    let severity: AppNotification.Severity

    private var label: String {
        switch severity {
        case .critical: return "CRITICAL"
        case .headsUp:  return "HEADS-UP"
        case .quiet:    return "QUIET ♡"
        }
    }
    private var color: Color {
        switch severity {
        case .critical: return theme.palette.haloRed
        case .headsUp:  return theme.palette.haloYellow
        case .quiet:    return theme.palette.haloGreen
        }
    }
    private var icon: String {
        switch severity {
        case .critical: return "exclamationmark.triangle.fill"
        case .headsUp:  return "bell.badge.fill"
        case .quiet:    return "sparkle"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(label)
                .font(theme.typography.font(.handTight, size: 11, weight: .bold))
                .tracking(0.6)
        }
        .foregroundColor(theme.palette.paper)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(color))
    }
}

private struct MemberRow: View {
    @Environment(\.theme) var theme
    let member: Member
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(member.accentColor.opacity(0.4))
                Circle().stroke(theme.palette.line, lineWidth: 1.5)
                Text(member.initial)
                    .font(theme.typography.font(.handTight, size: 14, weight: .bold))
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(theme.typography.font(.handTight, size: 14, weight: .bold))
                Text("Tap for full status & timeline →")
                    .font(theme.typography.font(.handFlow, size: 12))
                    .foregroundColor(theme.palette.ink3)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(theme.palette.ink3)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(10)
        .sketchBorder(padding: 0)
    }
}

private struct PrimaryRespondButton: View {
    @Environment(\.theme) var theme
    let kind: AppNotification.RespondKind
    let action: () -> Void

    private var label: String {
        switch kind {
        case .quickReply: return "Send a quick reply"
        case .nudgeHome:  return "Nudge them home"
        case .headOut:    return "Head out to them"
        }
    }
    private var color: Color {
        switch kind {
        case .quickReply: return theme.palette.haloGreen
        case .nudgeHome:  return theme.palette.haloYellow
        case .headOut:    return theme.palette.haloRed
        }
    }
    private var icon: String {
        switch kind {
        case .quickReply: return "heart.text.square.fill"
        case .nudgeHome:  return "house.fill"
        case .headOut:    return "car.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).font(.system(size: 16))
                Text(label.uppercased())
                    .font(theme.typography.font(.handTight, size: 14, weight: .bold))
                    .tracking(0.5)
                Spacer()
                Image(systemName: "arrow.right").font(.system(size: 14))
            }
            .foregroundColor(theme.palette.paper)
            .padding(.horizontal, 14).padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(color))
            .overlay(Capsule().stroke(theme.palette.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

private struct SecondaryRespondActions: View {
    @Environment(\.theme) var theme
    let excluded: AppNotification.RespondKind?
    let onAction: (AppNotification.RespondKind) -> Void

    private var available: [AppNotification.RespondKind] {
        AppNotification.RespondKind.allCases.filter { $0 != excluded }
    }

    var body: some View {
        if !available.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Other responses")
                    .font(theme.typography.font(.handTight, size: 11))
                    .tracking(0.5)
                    .foregroundColor(theme.palette.ink3)
                HStack(spacing: 8) {
                    ForEach(available, id: \.self) { kind in
                        Button { onAction(kind) } label: {
                            HStack(spacing: 4) {
                                Image(systemName: icon(for: kind))
                                    .font(.system(size: 12))
                                Text(label(for: kind))
                                    .font(theme.typography.font(.handTight, size: 11, weight: .bold))
                            }
                            .foregroundColor(theme.palette.ink)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(theme.palette.paper2))
                            .overlay(Capsule().stroke(theme.palette.line, lineWidth: 1.2))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func label(for kind: AppNotification.RespondKind) -> String {
        switch kind {
        case .quickReply: return "Reply"
        case .nudgeHome:  return "Nudge"
        case .headOut:    return "Head out"
        }
    }
    private func icon(for kind: AppNotification.RespondKind) -> String {
        switch kind {
        case .quickReply: return "heart.text.square"
        case .nudgeHome:  return "house"
        case .headOut:    return "car"
        }
    }
}
