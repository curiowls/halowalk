import SwiftUI

/// Title block at the top of every Guardian screen — handwritten title with a
/// flowing-script subtitle.
struct SectionHeader: View {
    @Environment(\.theme) var theme
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(theme.typography.font(.handTight, size: 22, weight: .bold))
                .foregroundColor(theme.palette.ink)
            Text(subtitle)
                .font(theme.typography.font(.handFlow, size: 16))
                .foregroundColor(theme.palette.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
