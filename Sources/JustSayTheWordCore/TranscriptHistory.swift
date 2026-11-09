// ABOUTME: The history file's format: one transcript per line as time, clip seconds and text, separated by tabs.
// ABOUTME: Writes a line and reads the most recent transcripts back, which is what the menu offers to copy again.
import Foundation

public struct Transcript: Equatable {
    public let time: String
    public let seconds: Double
    public let text: String

    public init(time: String, seconds: Double, text: String) {
        self.time = time
        self.seconds = seconds
        self.text = text
    }
}

public enum TranscriptHistory {
    /// The line for one transcript; tabs and line breaks of every kind in the text become spaces so it stays one line.
    public static func line(time: String, seconds: Double, text: String) -> String {
        let flat = String(text.map { $0.isNewline || $0 == "\t" ? " " : $0 })
        return "\(time)\t\(String(format: "%.1f", seconds))\t\(flat)\n"
    }

    /// Up to `limit` transcripts from a history file's contents, newest first, skipping lines that are not history
    /// lines or carry no text. Every line is parsed, which keeps this simple; a history of many megabytes would be
    /// better served by reading only the tail of the file.
    public static func recent(in contents: String, limit: Int) -> [Transcript] {
        let transcripts = contents.split(whereSeparator: \.isNewline).compactMap { line -> Transcript? in
            let fields = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            guard fields.count == 3, let seconds = Double(fields[1]), !fields[2].isEmpty else { return nil }
            return Transcript(time: String(fields[0]), seconds: seconds, text: String(fields[2]))
        }
        return Array(transcripts.suffix(limit).reversed())
    }
}
