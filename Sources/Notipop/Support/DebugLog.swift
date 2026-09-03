import Foundation

/// Tiny append-only log for local debugging (DEBUG builds only).
enum DebugLog {
    static func write(_ message: String) {
        #if DEBUG
        let url = Store.shared.supportDirectory.appendingPathComponent("debug.log")
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
        #endif
    }
}
