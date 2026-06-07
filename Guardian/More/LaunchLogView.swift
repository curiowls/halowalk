import SwiftUI

/// Read-only view of the launch breadcrumb log. Shareable so the pilot
/// user can copy/email it back when a freeze happens.
struct LaunchLogView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) private var dismiss
    @State private var contents: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(contents.isEmpty ? "(empty — no log yet)" : contents)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .background(theme.palette.paper.ignoresSafeArea())
            .navigationTitle("Launch log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: contents) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .onAppear {
                contents = LaunchLog.read()
            }
        }
    }
}
