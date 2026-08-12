import SwiftUI

/// Family tab — root view. Holds the list/map toggle and pushes Member
/// Detail when a member is tapped.
struct FamilyTabView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var familyStore: FamilyStore
    @ObservedObject private var cloudSync = HaloCloudSync.shared
    // Build 25: default to map and persist the last choice across app
    // launches. Per the user: "I constantly switch to the map view. In
    // most families, the guardian likely manages 1‑2 children and 1‑2
    // seniors… so the list view will be pretty empty for many people."
    @AppStorage("halowalk.familyTab.mode") private var mode: Mode = .map
    @State private var path: [FamilyRoute] = []
    @State private var editingHub: Hub? = nil
    @State private var showingShareSheet = false

    enum Mode: String, CaseIterable { case list, map }
    enum FamilyRoute: Hashable {
        case memberDetail(memberId: UUID)
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                FamilyHeader(
                    mode: $mode,
                    familyName: familyStore.family.name,
                    canInvite: cloudSync.databaseScope == .privateOwner,
                    onInvite: { showingShareSheet = true }
                )
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 8)

                ZStack {
                    // Both children fill the same frame so the parent VStack
                    // height stays constant when the toggle flips.
                    if mode == .list {
                        FamilyListView(onTap: { id in path.append(.memberDetail(memberId: id)) })
                    } else {
                        FamilyMapView(
                            onMemberTap: { id in path.append(.memberDetail(memberId: id)) },
                            onHubTap: { hub in editingHub = hub }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.palette.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: FamilyRoute.self) { route in
                switch route {
                case .memberDetail(let id):
                    MemberDetailView(memberId: id)
                }
            }
            .sheet(item: $editingHub) { hub in
                EditHubSheet(hub: hub)
            }
            .sheet(isPresented: $showingShareSheet) {
                CloudFamilySharingSheet()
            }
        }
        // Family tab is the canonical "I want to see where everyone is"
        // surface — keep continuous coarse updates running for the duration.
        .locationAware()
    }
}

private struct FamilyHeader: View {
    @Environment(\.theme) var theme
    @Binding var mode: FamilyTabView.Mode
    let familyName: String
    let canInvite: Bool
    let onInvite: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Family")
                    .font(theme.typography.font(.handTight, size: 22, weight: .bold))
                Text(familyName)
                    .font(theme.typography.font(.handFlow, size: 14))
                    .foregroundColor(theme.palette.ink3)
            }
            Spacer()
            if canInvite {
                Button(action: onInvite) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.palette.ink)
                        .frame(width: 34, height: 34)
                        .sketchBorder(padding: 0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Invite family member")
            }
            ListMapToggle(mode: $mode)
        }
    }
}

/// Hand-drawn pill toggle: list ⇄ map.
private struct ListMapToggle: View {
    @Environment(\.theme) var theme
    @Binding var mode: FamilyTabView.Mode

    var body: some View {
        HStack(spacing: 0) {
            toggleHalf(.list, icon: "list.bullet", label: "List")
            toggleHalf(.map, icon: "map", label: "Map")
        }
        .padding(2)
        .background(
            Capsule().fill(theme.palette.paper2)
        )
        .overlay(
            Capsule().stroke(theme.palette.line, lineWidth: 1.2)
        )
    }

    @ViewBuilder
    private func toggleHalf(_ which: FamilyTabView.Mode, icon: String, label: String) -> some View {
        let selected = mode == which
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { mode = which }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(theme.typography.font(.handTight, size: 12, weight: .bold))
            }
            .foregroundColor(selected ? theme.palette.paper : theme.palette.ink2)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(selected ? theme.palette.ink : .clear)
            )
        }
        .buttonStyle(.plain)
    }
}
