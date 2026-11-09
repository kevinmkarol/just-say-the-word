// ABOUTME: The whisper-cli side that needs no process: the argument list, the vocabulary file and its prompt rule,
// ABOUTME: and reading the JSON whisper-cli writes.
import Foundation

public enum Vocabulary {
    static let instructions = """
        # Names and terms whisper should know how to spell, one per line. Blank lines and # comments are skipped.
        # Read as each recording is transcribed, so edits take effect at the next dictation.

        """

    /// Writes the file with its instructions when there is none, so there is something to edit.
    public static func createFile(at url: URL) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try instructions.write(to: url, atomically: true, encoding: .utf8)
    }

    /// One name per line, blank lines and # comments skipped, joined for whisper-cli's initial prompt.
    public static func prompt(from contents: String) -> String {
        contents.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .joined(separator: ", ")
    }
}

public enum WhisperCommand {
    public static func arguments(
        model: String, vadModel: String?, prompt: String, language: String,
        audio: String, outputPrefix: String
    ) -> [String] {
        var args = [
            "-m", model,
            "-f", audio,
            "-l", language,
            "-np",   // nothing but the result on stdout
            "-sns",  // suppress non-speech tokens like (laughs)
            "-oj", "-of", outputPrefix,
        ]
        if let vadModel {
            args += ["--vad", "-vm", vadModel]  // without VAD, silence becomes "you" or "Thank you."
        }
        if !prompt.isEmpty {
            args += ["--prompt", prompt]
        }
        return args
    }
}

public enum WhisperOutputError: Error, Equatable {
    case malformed
}

public enum WhisperOutput {
    /// The transcript from whisper-cli's `-oj` file: the segments' text, each stripped, joined with spaces.
    public static func text(fromJSON data: Data) throws -> String {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let segments = root["transcription"] as? [[String: Any]]
        else { throw WhisperOutputError.malformed }
        return segments
            .compactMap { ($0["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
