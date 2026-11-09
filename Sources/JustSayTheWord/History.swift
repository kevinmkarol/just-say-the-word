// ABOUTME: Appends every transcript to ~/Library/Application Support/Just Say the Word/history.tsv, so nothing dictated
// ABOUTME: is lost when the paste lands in the wrong window, and reads the most recent ones back.
import JustSayTheWordCore
import Foundation

enum History {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Just Say the Word/history.tsv")

    static func append(text: String, seconds: Double) {
        LineFile.append(TranscriptHistory.line(time: LineFile.now(), seconds: seconds, text: text), to: url)
    }

    static func recent(limit: Int) -> [Transcript] {
        TranscriptHistory.recent(in: LineFile.contents(of: url), limit: limit)
    }
}
