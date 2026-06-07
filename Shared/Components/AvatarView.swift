import SwiftUI

/// Bare avatar — no circle, no border. Just the bundled illustration at
/// the requested size. When the member has no avatarId (or the asset
/// catalog hasn't loaded yet), falls back to the initial-in-circle
/// pattern we've used since the start so older builds + new builds can
/// share screens without crashing.
struct MemberAvatar: View {
    @Environment(\.theme) var theme
    let member: Member
    let size: CGFloat

    init(_ member: Member, size: CGFloat = 56) {
        self.member = member
        self.size = size
    }

    var body: some View {
        if let img = AvatarCatalog.image(for: member.avatarId) {
            img
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            // Fallback — initial in a soft accent circle.
            ZStack {
                Circle().fill(member.accentColor.opacity(0.4))
                Circle().stroke(theme.palette.line, lineWidth: 1.5)
                Text(member.initial)
                    .font(theme.typography.font(.handTight, size: size * 0.42, weight: .bold))
                    .foregroundColor(theme.palette.ink)
            }
            .frame(width: size, height: size)
        }
    }
}

/// Avatar + name underneath — used in lists, on map markers, and on
/// member detail. Per the Build 25 design call: "avatars without circle
/// with a name under each for people."
struct MemberAvatarWithName: View {
    @Environment(\.theme) var theme
    let member: Member
    let size: CGFloat
    let nameStyle: NameStyle

    enum NameStyle {
        case full          // member.displayName, body weight
        case compact       // single-line, smaller, used on map markers
    }

    init(_ member: Member, size: CGFloat = 56, nameStyle: NameStyle = .full) {
        self.member = member
        self.size = size
        self.nameStyle = nameStyle
    }

    var body: some View {
        VStack(spacing: 2) {
            MemberAvatar(member, size: size)
            Text(member.displayName)
                .font(font)
                .foregroundColor(theme.palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var font: Font {
        switch nameStyle {
        case .full:
            return theme.typography.font(.handTight, size: 13, weight: .bold)
        case .compact:
            return theme.typography.font(.handTight, size: 10, weight: .bold)
        }
    }
}
