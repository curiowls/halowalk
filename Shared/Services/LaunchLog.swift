import Foundation
import os.log

/// Persistent breadcrumb log for diagnosing launch crashes. Writes to a
/// rotating file in the app's documents directory + os_log for Console.app
/// visibility. Survives crashes — the file is on disk before the app dies.
///
/// Read it back via the Privacy & permissions page during pilot
/// (Build 13 adds a "View launch log" button).
enum LaunchLog {
    private static let logger = Logger(subsystem: "com.halowalk.guardian", category: "launch")

    private static var fileURL: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return url.appendingPathComponent("launch.log")
    }

    /// Record a step. Tag is short — e.g. "stores.init", "wcsession.activate".
    static func step(_ tag: String, _ detail: String? = nil) {
        let line: String = {
            let ts = ISO8601DateFormatter().string(from: Date())
            if let d = detail {
                return "[\(ts)] \(tag) — \(d)\n"
            }
            return "[\(ts)] \(tag)\n"
        }()
        logger.info("\(line, privacy: .public)")
        append(line)
    }

    static func error(_ tag: String, _ error: Error) {
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] ⚠ \(tag) — \(error.localizedDescription)\n"
        logger.error("\(line, privacy: .public)")
        append(line)
    }

    /// Read the entire log back. Used by the "View launch log" UI button.
    static func read() -> String {
        guard let data = try? Data(contentsOf: fileURL) else { return "(no log)" }
        return String(data: data, encoding: .utf8) ?? "(unreadable)"
    }

    /// Wipe the log when starting a fresh launch trace.
    static func reset() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func append(_ line: String) {
        let data = line.data(using: .utf8) ?? Data()
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: fileURL)
        }
    }
}
