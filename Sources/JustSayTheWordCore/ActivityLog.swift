// ABOUTME: The log file's format: one line per event as a timestamp and a message, with problems marked so the
// ABOUTME: Activity view can pick them out. Writes a line and reads the most recent entries back.
import Foundation

public struct ActivityEntry: Equatable {
    /// "yyyy-MM-dd HH:mm:ss", or empty for a line that carried no timestamp.
    public let time: String
    public let message: String
    public let isProblem: Bool

    public init(time: String, message: String, isProblem: Bool) {
        self.time = time
        self.message = message
        self.isProblem = isProblem
    }

    /// The "yyyy-MM-dd" of `time`, or empty when there is no time.
    public var day: String { String(time.prefix(10)) }

    /// The "HH:mm:ss" of `time`, or empty when there is no time.
    public var clock: String { String(time.dropFirst(11)) }

    /// What happened, in a few words: the message up to its first ": " or "; ".
    public var headline: String { parts.headline }

    /// What follows the headline, or nil for a message that is all headline.
    public var detail: String? { parts.detail }

    private var parts: (headline: String, detail: String?) {
        let breaks = [": ", "; "].compactMap { message.range(of: $0) }
        guard let first = breaks.min(by: { $0.lowerBound < $1.lowerBound }) else { return (message, nil) }
        return (String(message[..<first.lowerBound]), String(message[first.upperBound...]))
    }
}

public enum ActivityLog {
    private static let problemMark = "problem: "
    private static let timeLength = "yyyy-MM-dd HH:mm:ss".count

    public static func line(time: String, message: String, isProblem: Bool) -> String {
        "\(time) \(isProblem ? problemMark : "")\(message)\n"
    }

    /// Up to `limit` entries from a log file's contents, newest first. Every line is parsed, which keeps this
    /// simple; a log of many megabytes would be better served by reading only the tail of the file.
    public static func recent(in contents: String, limit: Int) -> [ActivityEntry] {
        let entries = contents.split(whereSeparator: \.isNewline).map { line -> ActivityEntry in
            guard let (time, rest) = splitTime(from: line) else {
                return ActivityEntry(time: "", message: String(line), isProblem: false)
            }
            let isProblem = rest.hasPrefix(problemMark)
            return ActivityEntry(
                time: time, message: String(isProblem ? rest.dropFirst(problemMark.count) : rest), isProblem: isProblem
            )
        }
        return Array(entries.suffix(limit).reversed())
    }

    /// The entries in runs that share a day, in the order they come.
    public static func byDay(_ entries: [ActivityEntry]) -> [(day: String, entries: [ActivityEntry])] {
        var days: [(day: String, entries: [ActivityEntry])] = []
        for entry in entries {
            if days.last?.day == entry.day {
                days[days.count - 1].entries.append(entry)
            } else {
                days.append((entry.day, [entry]))
            }
        }
        return days
    }

    /// The timestamp a line starts with and what follows it, or nil when the line does not start with one.
    private static func splitTime(from line: Substring) -> (time: String, rest: Substring)? {
        let time = line.prefix(timeLength)
        let rest = line.dropFirst(timeLength)
        let digits = time.filter(\.isNumber).count
        guard time.count == timeLength, digits == 14, rest.first == " " else { return nil }
        return (String(time), rest.dropFirst())
    }
}
