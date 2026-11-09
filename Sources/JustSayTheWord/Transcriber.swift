// ABOUTME: Runs the whisper-cli inside the app's bundle on a clip in the background and hands back the text on the
// ABOUTME: main thread. Each run loads the model afresh, which keeps its memory free between dictations.
import AVFoundation
import JustSayTheWordCore
import Foundation

enum TranscribeError: LocalizedError {
    case timeout(Double)
    case failed(Int32, String)
    case noOutput

    var errorDescription: String? {
        switch self {
        case .timeout(let seconds): return String(format: "whisper-cli wrote no result within %.0f s", seconds)
        case .failed(let status, let detail): return "whisper-cli exited \(status): \(detail)"
        case .noOutput: return "whisper-cli wrote no JSON"
        }
    }
}

/// What the app carries in its own bundle: the speech engine, and the models used unless the settings name others.
private enum BuiltIn {
    private static let contents = Bundle.main.bundleURL.appendingPathComponent("Contents")
    static let whisperCli = contents.appendingPathComponent("MacOS/whisper-cli")
    static let model = contents.appendingPathComponent("Resources/ggml-medium.bin").path
    static let vadModel = contents.appendingPathComponent("Resources/ggml-silero-v5.1.2.bin").path
}

final class Transcriber {
    private let queue = DispatchQueue(label: "just-say-the-word.transcriber")

    /// How long the audio file at `clip` runs.
    static func seconds(of clip: URL) throws -> Double {
        let audio = try AVAudioFile(forReading: clip)
        return Double(audio.length) / audio.processingFormat.sampleRate
    }

    func transcribe(
        _ audio: URL, config: Config, clipSeconds: Double,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        queue.async {
            let result = Result { try self.run(audio, config: config, clipSeconds: clipSeconds) }
            DispatchQueue.main.async { completion(result) }
        }
    }

    func run(_ audio: URL, config: Config, clipSeconds: Double) throws -> String {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("\(TempFiles.prefix)\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        let prefix = dir.appendingPathComponent("out")
        let errorLog = dir.appendingPathComponent("stderr.log")
        fm.createFile(atPath: errorLog.path, contents: nil)

        let vocabulary = (try? String(contentsOfFile: Config.expand(config.vocabulary), encoding: .utf8)) ?? ""
        let vad = config.vadModelPath(builtIn: BuiltIn.vadModel)
        let process = Process()
        process.executableURL = BuiltIn.whisperCli
        process.arguments = WhisperCommand.arguments(
            model: config.modelPath(builtIn: BuiltIn.model),
            vadModel: fm.fileExists(atPath: vad) ? vad : nil,
            prompt: Vocabulary.prompt(from: vocabulary),
            language: config.language,
            audio: audio.path,
            outputPrefix: prefix.path
        )
        process.standardOutput = FileHandle.nullDevice
        process.standardError = try FileHandle(forWritingTo: errorLog)
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        let started = Date()
        try process.run()
        let timeout = 30 + 2 * clipSeconds
        if finished.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            throw TranscribeError.timeout(timeout)
        }
        guard process.terminationStatus == 0 else {
            let stderr = (try? String(contentsOf: errorLog, encoding: .utf8)) ?? ""
            let last = stderr.split(whereSeparator: \.isNewline).last.map(String.init) ?? "no output"
            throw TranscribeError.failed(process.terminationStatus, last)
        }
        guard let data = fm.contents(atPath: prefix.path + ".json") else { throw TranscribeError.noOutput }
        let text = try WhisperOutput.text(fromJSON: data)
        Log.write(String(
            format: "transcribed %d characters: %.1f s clip in %.2f s",
            text.count, clipSeconds, Date().timeIntervalSince(started)
        ))
        return text
    }
}
