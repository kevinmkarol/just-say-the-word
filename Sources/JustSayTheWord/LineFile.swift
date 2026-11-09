// ABOUTME: A text file that grows a line at a time, which is what the history and the log each are: stamps a line
// ABOUTME: with the time, appends it (creating the file and its folder when missing) and reads the file back.
import Foundation

enum LineFile {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    /// The time now, as every line records it.
    static func now() -> String {
        formatter.string(from: Date())
    }

    static func contents(of url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    static func append(_ line: String, to url: URL) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
