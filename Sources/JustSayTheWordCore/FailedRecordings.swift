// ABOUTME: Keeps the audio of a dictation whose transcription failed, so a long recording is not lost to a
// ABOUTME: whisper-cli error and can be transcribed again. Each clip is a WAV named for when it was recorded.
import Foundation

public struct FailedRecordings {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// Moves `clip` into the directory and returns where it now is.
    @discardableResult
    public func keep(_ clip: URL, recordedAt date: Date) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let kept = directory.appendingPathComponent(Self.name(for: date))
        try FileManager.default.moveItem(at: clip, to: kept)
        return kept
    }

    /// The kept clips, oldest first.
    public func all() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "wav" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public var latest: URL? { all().last }

    /// A name that sorts by recording time, e.g. "2026-11-08 18.34.26.wav".
    private static func name(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: date) + ".wav"
    }
}
