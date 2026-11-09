// ABOUTME: One-line timestamped log to ~/Library/Logs/Just Say the Word.log and stderr, so the Activity view and
// ABOUTME: `tail -f` show what the app did. Problems are marked so they stand out.
import Foundation
import JustSayTheWordCore

enum Log {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Just Say the Word.log")
    private static let queue = DispatchQueue(label: "just-say-the-word.log")

    static func write(_ message: String) {
        append(message, isProblem: false)
    }

    /// Logs something that went wrong or needs the user's attention.
    static func problem(_ message: String) {
        append(message, isProblem: true)
    }

    /// The most recent entries, newest first, including any still waiting to be written.
    static func recent(limit: Int) -> [ActivityEntry] {
        ActivityLog.recent(in: queue.sync { LineFile.contents(of: url) }, limit: limit)
    }

    private static func append(_ message: String, isProblem: Bool) {
        let line = ActivityLog.line(time: LineFile.now(), message: message, isProblem: isProblem)
        FileHandle.standardError.write(Data(line.utf8))
        queue.async { LineFile.append(line, to: url) }
    }
}
