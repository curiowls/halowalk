import SwiftUI

/// Themed button matching the prototype's `.btn` look.
struct SketchButton<Label: View>: View {
    @Environment(\.theme) var theme
    enum Kind { case paper, ink, yellow, green, red, custom(fill: Color, fg: Color) }
    let kind: Kind
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    init(_ kind: Kind = .paper, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.kind = kind
        self.action = action
        self.label = label
    }

    var body: some View {
        let (fill, fg): (Color, Color) = {
            switch kind {
            case .paper:  return (theme.palette.paper, theme.palette.ink)
            case .ink:    return (theme.palette.ink, theme.palette.paper)
            case .yellow: return (theme.palette.haloYellow, theme.palette.ink)
            case .green:  return (theme.palette.haloGreen, theme.palette.paper)
            case .red:    return (theme.palette.haloRed, theme.palette.paper)
            case .custom(let f, let g): return (f, g)
            }
        }()
        return Button(action: action) {
            label()
                .font(theme.typography.font(.handTight, size: 12))
                .foregroundColor(fg)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(fill))
                .overlay(Capsule().stroke(theme.palette.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

extension SketchButton where Label == Text {
    init(_ title: String, kind: Kind = .paper, action: @escaping () -> Void) {
        self.init(kind, action: action) { Text(title) }
    }
}

/// Toggle that looks like the prototype's hand-drawn slider.
struct SketchToggle: View {
    @Environment(\.theme) var theme
    @Binding var isOn: Bool
    var width: CGFloat = 32
    var height: CGFloat = 18

    var body: some View {
        Button { withAnimation(.spring(response: 0.25)) { isOn.toggle() } } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? theme.palette.haloGreen : theme.palette.paper2)
                    .overlay(Capsule().stroke(theme.palette.line, lineWidth: 1.2))
                    .frame(width: width, height: height)
                Circle()
                    .fill(theme.palette.paper)
                    .overlay(Circle().stroke(theme.palette.line, lineWidth: 1))
                    .frame(width: height - 4, height: height - 4)
                    .padding(.horizontal, 2)
            }
        }
        .buttonStyle(.plain)
    }
}
