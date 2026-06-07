import SwiftUI

/// The Notifications feed. Severity-grouped scroll, with a filter chip
/// strip at the top. Tapping a notification pushes Notification Detail —
/// from there the user can choose a respond action (or land on Member
/// Detail for fuller context).
struct NotificationsTabView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var notificationStore: NotificationStore
    @EnvironmentObject var familyStore: FamilyStore
    @State private var filter: SeverityFilter = .all
    @State private var path: [Route] = []

    enum SeverityFilter: Hashable, CaseIterable {
        case all, critical, headsUp, quiet
        var label: String {
            switch self {
            case .all: return "All"
            case .critical: return "Critical"
            case .headsUp: return "Heads-up"
            case .quiet: return "Quiet ♡"
            }
        }
    }
    enum Route: Hashable {
        case detail(notificationId: UUID)
        case member(memberId: UUID)
    }

    private var filtered: [AppNotification] {
        let base = notificationStore.visible
        switch filter {
        case .all: return base
        case .critical: return base.filter { $0.severity == .critical }
        case .headsUp: return base.filter { $0.severity == .headsUp }
        case .quiet: return base.filter { $0.severity == .quiet }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                NotificationsHeader(unreadCount: notificationStore.unread.count)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 8)

                FilterStrip(selected: $filter, store: notificationStore)
                    .padding(.bottom, 6)

                if filtered.isEmpty {
                    EmptyState(filter: filter)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(filtered) { n in
                                Button {
                                    notificationStore.markRead(n.id)
                                    path.append(.detail(notificationId: n.id))
                                } label: {
                                    NotificationRow(notification: n)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.palette.paper.ignoresSafeArea())
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .detail(let id):
                    NotificationDetailView(
                        notificationId: id,
                        onSeeMember: { memberId in path.append(.member(memberId: memberId)) }
                    )
                case .member(let id):
                    MemberDetailView(memberId: id)
                }
            }
        }
    }
}

private struct NotificationsHeader: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var notificationStore: NotificationStore
    let unreadCount: Int

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Notifications")
                    .font(theme.typography.font(.handTight, size: 22, weight: .bold))
                Text(unreadCount > 0
                     ? "\(unreadCount) unread"
                     : "all caught up ♡")
                    .font(theme.typography.font(.handFlow, size: 14))
                    .foregroundColor(theme.palette.ink3)
            }
            Spacer()
            if unreadCount > 0 {
                Button("Mark all read") {
                    notificationStore.markAllRead()
                }
                .font(theme.typography.font(.handTight, size: 12))
                .foregroundColor(theme.palette.ink2)
            }
        }
    }
}

private struct FilterStrip: View {
    @Environment(\.theme) var theme
    @Binding var selected: NotificationsTabView.SeverityFilter
    let store: NotificationStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(NotificationsTabView.SeverityFilter.allCases, id: \.self) { filter in
                    Button { selected = filter } label: {
                        HStack(spacing: 4) {
                            indicator(for: filter)
                            Text(filter.label)
                                .font(theme.typography.font(.handTight, size: 12, weight: .bold))
                            if let count = badge(for: filter), count > 0 {
                                Text("\(count)")
                                    .font(theme.typography.font(.handTight, size: 10, weight: .bold))
                                    .foregroundColor(theme.palette.paper)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Capsule().fill(filterColor(filter)))
                            }
                        }
                        .foregroundColor(selected == filter ? theme.palette.paper : theme.palette.ink)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(selected == filter ? theme.palette.ink : theme.palette.paper2))
                        .overlay(Capsule().stroke(theme.palette.line, lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func indicator(for filter: NotificationsTabView.SeverityFilter) -> some View {
        if filter != .all {
            Circle().fill(filterColor(filter)).frame(width: 8, height: 8)
        }
    }
    private func filterColor(_ filter: NotificationsTabView.SeverityFilter) -> Color {
        switch filter {
        case .critical: return theme.palette.haloRed
        case .headsUp:  return theme.palette.haloYellow
        case .quiet:    return theme.palette.haloGreen
        case .all:      return theme.palette.ink
        }
    }
    private func badge(for filter: NotificationsTabView.SeverityFilter) -> Int? {
        switch filter {
        case .critical: return store.count(of: .critical)
        case .headsUp:  return store.count(of: .headsUp)
        case .quiet:    return store.count(of: .quiet)
        case .all:      return store.unread.count
        }
    }
}

private struct EmptyState: View {
    @Environment(\.theme) var theme
    let filter: NotificationsTabView.SeverityFilter

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 56))
                .foregroundColor(theme.palette.ink3)
            Text(filter == .all ? "Nothing to see — everyone is in a halo ♡" : "No \(filter.label.lowercased()) notifications")
                .font(theme.typography.font(.handFlow, size: 16))
                .foregroundColor(theme.palette.ink3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One row in the feed.
struct NotificationRow: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var familyStore: FamilyStore
    let notification: AppNotification

    private var accent: Color {
        switch notification.severity {
        case .critical: return theme.palette.haloRed
        case .headsUp:  return theme.palette.haloYellow
        case .quiet:    return theme.palette.haloGreen
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if !notification.read {
                        Circle().fill(accent).frame(width: 8, height: 8)
                    }
                    Text(notification.title)
                        .font(theme.typography.font(.handTight, size: 14, weight: .bold))
                    Spacer()
                    Text(timeAgo)
                        .font(theme.typography.font(.handTight, size: 11))
                        .foregroundColor(theme.palette.ink3)
                }
                Text(notification.body)
                    .font(theme.typography.font(.handFlow, size: 13))
                    .foregroundColor(theme.palette.ink2)
                    .lineLimit(2)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.palette.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .sketchBorder(seed: notification.id.uuidString.hashValue, padding: 0)
        .overlay(
            Rectangle().fill(accent).frame(width: 5)
                .padding(.vertical, 6),
            alignment: .leading
        )
        .opacity(notification.read ? 0.85 : 1.0)
    }

    private var timeAgo: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: notification.timestamp, relativeTo: Date())
    }
}
