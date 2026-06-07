import SwiftUI

/// Family member roster with per-member theme assignment. Tap a member to
/// open their detail card with theme picker.
struct FamilyManagementView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var familyStore: FamilyStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(familyStore.family.name)
                    .font(theme.typography.font(.handTight, size: 22, weight: .bold))
                Text("\(familyStore.watcherMembers.count) guardian\(familyStore.watcherMembers.count == 1 ? "" : "s") · \(familyStore.watchedMembers.count) wearer\(familyStore.watchedMembers.count == 1 ? "" : "s")")
                    .font(theme.typography.font(.handFlow, size: 13))
                    .foregroundColor(theme.palette.ink3)

                if !familyStore.watcherMembers.isEmpty {
                    SectionLabel("Guardians")
                    ForEach(familyStore.watcherMembers) { member in
                        NavigationLink {
                            MemberSettingsView(memberId: member.id)
                        } label: {
                            MemberRow(member: member)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !familyStore.watchedMembers.isEmpty {
                    SectionLabel("Wearers")
                    ForEach(familyStore.watchedMembers) { member in
                        NavigationLink {
                            MemberSettingsView(memberId: member.id)
                        } label: {
                            MemberRow(member: member)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {} label: {
                    Text("+ Add a family member")
                        .font(theme.typography.font(.handFlow, size: 16))
                        .foregroundColor(theme.palette.ink2)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .sketchBorder(dashed: true, padding: 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.paper.ignoresSafeArea())
        .navigationTitle("Family members")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SectionLabel: View {
    @Environment(\.theme) var theme
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(theme.typography.font(.handTight, size: 11))
            .tracking(0.6)
            .foregroundColor(theme.palette.ink3)
            .padding(.top, 8)
    }
}

private struct MemberRow: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var familyStore: FamilyStore
    let member: Member

    private var roleLabel: String {
        let watches = familyStore.isGuardian(member.id)
        let watched = familyStore.isWatched(member.id)
        if watches && watched { return "watches & watched" }
        if watches { return "watches over family" }
        if watched { return "watched by family" }
        return "no relationships"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(member.accentColor.opacity(0.4))
                Circle().stroke(theme.palette.line, lineWidth: 1.5)
                Text(member.initial)
                    .font(theme.typography.font(.handTight, size: 16, weight: .bold))
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(theme.typography.font(.handTight, size: 14, weight: .bold))
                    .foregroundColor(theme.palette.ink)
                HStack(spacing: 4) {
                    Text(roleLabel)
                    if let age = member.ageYears {
                        Text("· \(age)y")
                    }
                    Text("· \(member.preferredTheme.name) theme")
                }
                .font(theme.typography.font(.handFlow, size: 12))
                .foregroundColor(theme.palette.ink3)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.palette.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .sketchBorder(seed: member.id.uuidString.hashValue, padding: 0)
    }
}

/// Per-member detail with theme picker. Pushed from Family Management.
struct MemberSettingsView: View {
    @Environment(\.theme) var theme
    @ObservedObject private var familyStore = FamilyStore.shared
    let memberId: UUID

    private var member: Member? { familyStore.member(memberId) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let member {
                    MemberHero(member: member)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Theme")
                            .font(theme.typography.font(.handTight, size: 11))
                            .tracking(0.5)
                            .foregroundColor(theme.palette.ink3)
                        Text(themeDescription(for: member))
                            .font(theme.typography.font(.handFlow, size: 13))
                            .foregroundColor(theme.palette.ink2)

                        VStack(spacing: 8) {
                            ForEach(Theme.allRegistered) { t in
                                Button {
                                    var updated = member
                                    updated.preferredThemeId = t.id
                                    familyStore.updateMember(updated)
                                } label: {
                                    PerMemberThemeRow(
                                        theme: t,
                                        selected: member.preferredThemeId == t.id
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    Text("Member not found.")
                        .font(theme.typography.font(.handFlow, size: 14))
                        .foregroundColor(theme.palette.ink3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.paper.ignoresSafeArea())
        .navigationTitle(member?.displayName ?? "Member")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func themeDescription(for member: Member) -> String {
        if familyStore.isWatched(member.id) {
            return "Sets the look of \(member.displayName)'s Apple Watch."
        }
        return "Sets the look of \(member.displayName)'s iPhone."
    }
}

private struct MemberHero: View {
    @Environment(\.theme) var theme
    let member: Member

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(member.accentColor.opacity(0.4))
                Circle().stroke(theme.palette.line, lineWidth: 1.5)
                Text(member.initial)
                    .font(theme.typography.font(.handTight, size: 22, weight: .bold))
            }
            .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(theme.typography.font(.handTight, size: 18, weight: .bold))
                if let age = member.ageYears {
                    Text("\(age) years · \(FamilyStore.shared.isGuardian(member.id) ? "guardian" : "wearer")")
                        .font(theme.typography.font(.handFlow, size: 13))
                        .foregroundColor(theme.palette.ink3)
                }
            }
            Spacer()
        }
        .padding(12)
        .sketchBorder(padding: 0)
    }
}

private struct PerMemberThemeRow: View {
    @Environment(\.theme) var envTheme
    let theme: Theme
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ThemeSwatch(
                paper: theme.palette.paper,
                ink: theme.palette.ink,
                accent1: theme.palette.haloGreen,
                accent2: theme.palette.haloYellow,
                accent3: theme.palette.haloRed,
                accent4: theme.palette.haloPink
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(theme.name)
                    .font(envTheme.typography.font(.handTight, size: 14, weight: .bold))
                Text(theme.summary)
                    .font(envTheme.typography.font(.handFlow, size: 12))
                    .foregroundColor(envTheme.palette.ink3)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(envTheme.palette.haloGreen)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .sketchBorder(seed: theme.id.hashValue, padding: 0)
    }
}
