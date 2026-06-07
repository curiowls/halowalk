import SwiftUI

// Stubs for the three Respond destinations. Sheets that present from Member
// Detail (Phase 3) and from Notification Detail (Phase 5). Filled in Phase 5.

struct RespondQuickReplyView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var familyStore: FamilyStore
    let toMemberId: UUID

    private let templates = [
        "Have fun ♡",
        "Be back by 5pm",
        "Stay near Home",
        "Send me a 👍 when you head back"
    ]
    @State private var customText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Reply to \(familyStore.displayName(toMemberId))")
                    .font(theme.typography.font(.handFlow, size: 13))
                    .foregroundColor(theme.palette.ink3)
                Text("Quick message")
                    .font(theme.typography.font(.handTight, size: 22, weight: .bold))
            }
            Text("Tap to send · arrives as a watch buzz")
                .font(theme.typography.font(.handFlow, size: 13))
                .foregroundColor(theme.palette.ink3)

            VStack(spacing: 8) {
                ForEach(templates, id: \.self) { template in
                    Button {
                        // wired in Build 6 (WatchConnectivity)
                        dismiss()
                    } label: {
                        Text(template)
                            .font(theme.typography.font(.handTight, size: 13))
                            .foregroundColor(theme.palette.ink)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .sketchBorder(fill: theme.palette.highlightSoft, padding: 0)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.paper.ignoresSafeArea())
        .navigationTitle("Quick reply")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel") { dismiss() }.foregroundColor(theme.palette.ink)
            }
        }
    }
}

struct RespondNudgeHomeView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var familyStore: FamilyStore
    let toMemberId: UUID
    @State private var nudgeStyle = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Nudge \(familyStore.displayName(toMemberId)) home")
                    .font(theme.typography.font(.handTight, size: 22, weight: .bold))
                Text("Their watch will buzz with a return prompt.")
                    .font(theme.typography.font(.handFlow, size: 13))
                    .foregroundColor(theme.palette.ink3)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Nudge style")
                    .font(theme.typography.font(.handTight, size: 11))
                    .tracking(0.5)
                    .foregroundColor(theme.palette.ink3)
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Button { nudgeStyle = i } label: {
                            Text(["♡ gentle", "firm", "haptic buzz"][i])
                                .font(theme.typography.font(.handTight, size: 12))
                                .foregroundColor(nudgeStyle == i ? theme.palette.paper : theme.palette.ink)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Capsule().fill(nudgeStyle == i ? theme.palette.ink : theme.palette.paper2))
                                .overlay(Capsule().stroke(theme.palette.line, lineWidth: 1.2))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Button { dismiss() } label: {
                Text("SEND NUDGE →")
                    .font(theme.typography.font(.handTight, size: 14, weight: .bold))
                    .foregroundColor(theme.palette.ink)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Capsule().fill(theme.palette.haloYellow))
                    .overlay(Capsule().stroke(theme.palette.line, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.paper.ignoresSafeArea())
        .navigationTitle("Nudge home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel") { dismiss() }.foregroundColor(theme.palette.ink)
            }
        }
    }
}

struct RespondHeadOutView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var familyStore: FamilyStore
    @EnvironmentObject var presenceStore: PresenceStore
    let toMemberId: UUID
    @State private var mode = 0 // 0=drive, 1=walk, 2=transit

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("HEAD TO \(familyStore.displayName(toMemberId).uppercased())")
                    .font(theme.typography.font(.handTight, size: 11))
                    .tracking(0.7)
                    .foregroundColor(theme.palette.haloRed)
                Text("Open in Maps")
                    .font(theme.typography.font(.handTight, size: 22, weight: .bold))
                if let r = presenceStore.reading(for: toMemberId) {
                    Text(String(format: "Last seen ± %.0f m accuracy",
                                r.horizontalAccuracy))
                        .font(theme.typography.font(.handFlow, size: 13))
                        .foregroundColor(theme.palette.ink3)
                }
            }
            HStack(spacing: 6) {
                ForEach(["🚗 drive", "walk", "transit"], id: \.self) { label in
                    let i = ["🚗 drive", "walk", "transit"].firstIndex(of: label) ?? 0
                    Button { mode = i } label: {
                        Text(label)
                            .font(theme.typography.font(.handTight, size: 12))
                            .foregroundColor(mode == i ? theme.palette.paper : theme.palette.ink)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(mode == i ? theme.palette.ink : theme.palette.paper2))
                            .overlay(Capsule().stroke(theme.palette.line, lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)
                }
            }
            Button { dismiss() } label: {
                Text("OPEN MAPS →")
                    .font(theme.typography.font(.handTight, size: 14, weight: .bold))
                    .foregroundColor(theme.palette.paper)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Capsule().fill(theme.palette.haloRed))
                    .overlay(Capsule().stroke(theme.palette.line, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            Text("\(familyStore.displayName(toMemberId))'s watch will buzz: \"Help is on the way\"")
                .font(theme.typography.font(.handFlow, size: 13))
                .foregroundColor(theme.palette.ink3)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.paper.ignoresSafeArea())
        .navigationTitle("Head out")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel") { dismiss() }.foregroundColor(theme.palette.ink)
            }
        }
    }
}
