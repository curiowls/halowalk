import SwiftUI

/// Live CloudKit sync diagnostics. Built so we can read exactly what the
/// sync engine does on a real device — every enqueue / fetch / send with
/// record names and exact CKError codes — instead of guessing from the
/// outside. Reachable from More → CloudKit sync.
struct CloudSyncDiagnosticsView: View {
    @Environment(\.theme) var theme
    @ObservedObject private var sync = HaloCloudSync.shared
    @ObservedObject private var family = FamilyStore.shared

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    statusCard

                    HStack(spacing: 10) {
                        Button {
                            sync.forceResync()
                        } label: {
                            Label("Force re-sync", systemImage: "arrow.triangle.2.circlepath")
                                .font(theme.typography.font(.handTight, size: 13, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .sketchBorder(padding: 0)
                        }
                        .buttonStyle(.plain)
                        Button {
                            sync.clearLog()
                        } label: {
                            Label("Clear log", systemImage: "trash")
                                .font(theme.typography.font(.handTight, size: 13, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .sketchBorder(padding: 0)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        UIPasteboard.general.string = sync.log.joined(separator: "\n")
                    } label: {
                        Label("Copy full log", systemImage: "doc.on.doc")
                            .font(theme.typography.font(.handTight, size: 13, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .sketchBorder(padding: 0)
                    }
                    .buttonStyle(.plain)

                    Text("Event log")
                        .font(theme.typography.font(.handTight, size: 11))
                        .tracking(0.6)
                        .foregroundColor(theme.palette.ink3)

                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(sync.log.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(lineColor(line))
                                .textSelection(.enabled)
                                .id(idx)
                        }
                        if sync.log.isEmpty {
                            Text("No events yet.")
                                .font(theme.typography.font(.handFlow, size: 12))
                                .foregroundColor(theme.palette.ink3)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(theme.palette.paper2))
                    .onChange(of: sync.log.count) { _, _ in
                        if let last = sync.log.indices.last {
                            withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("CloudKit sync")
        .navigationBarTitleDisplayMode(.inline)
        .background(theme.palette.paper.ignoresSafeArea())
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Database scope", sync.databaseScope.label)
            row("Active zone", sync.activeZoneDescription)
            row("iCloud account", sync.accountAvailable ? "available" : "UNAVAILABLE")
            row("Engine running", sync.isRunning ? "yes" : "no")
            row("Last sync", sync.lastSyncAt.map { rel($0) } ?? "never")
            row("My avatar (local)", family.me?.avatarId ?? "nil")
            if let err = sync.lastError {
                Text("Last error: \(err)")
                    .font(theme.typography.font(.handFlow, size: 12))
                    .foregroundColor(theme.palette.haloRed)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .sketchBorder(padding: 0)
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(theme.typography.font(.handFlow, size: 13))
                .foregroundColor(theme.palette.ink3)
            Spacer()
            Text(v).font(theme.typography.font(.handTight, size: 13, weight: .bold))
                .foregroundColor(theme.palette.ink)
        }
    }
    private func lineColor(_ line: String) -> Color {
        if line.contains("FAILED") || line.contains("NIL") || line.contains("ABORT") || line.contains("unavailable") {
            return theme.palette.haloRed
        }
        if line.contains("SENT OK") || line.contains("→ upsert") || line.contains("complete") {
            return theme.palette.haloGreen
        }
        return theme.palette.ink2
    }
    private func rel(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: d, relativeTo: Date())
    }
}
