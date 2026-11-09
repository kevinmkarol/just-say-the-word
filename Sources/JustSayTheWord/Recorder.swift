// ABOUTME: Records the chosen input (or the system default) to a 16 kHz mono 16-bit WAV with AVAudioEngine,
// ABOUTME: converting from whatever the device delivers, and tracks the peak level for the log and the level bars.
import AudioToolbox
import AVFoundation
import Foundation
import JustSayTheWordCore
import os

enum RecorderError: LocalizedError {
    case device(OSStatus)
    case noInput
    case converter

    var errorDescription: String? {
        switch self {
        case .device(let status): return "could not select the input device (CoreAudio \(status))"
        case .noInput: return "the input device delivers no audio (no microphone?)"
        case .converter: return "could not convert the input to 16 kHz mono"
        }
    }
}

final class Recorder {
    struct Clip {
        let url: URL
        let seconds: Double
        let peakDb: Float
    }

    private var engine: AVAudioEngine?
    private var file: AVAudioFile?
    private var url: URL?
    private var frames: Int64 = 0
    private var peak: Float = 0
    /// The peak of the buffer that arrived last. Written on the audio thread, read on the main one.
    private let latestPeak = OSAllocatedUnfairLock<Float>(initialState: 0)

    var isRecording: Bool { engine != nil }

    /// How loud the input is right now, 0 (silent) to 1 (full scale).
    var level: Float { latestPeak.withLock { $0 } }

    func start(device: AudioDevice?) throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        if let device, let unit = input.audioUnit {
            var id = device.id
            let status = AudioUnitSetProperty(
                unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                &id, UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            guard status == noErr else { throw RecorderError.device(status) }
        }
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else { throw RecorderError.noInput }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(TempFiles.prefix)\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let file = try AVAudioFile(
            forWriting: url, settings: settings, commonFormat: .pcmFormatInt16, interleaved: true
        )
        guard let converter = AVAudioConverter(from: inputFormat, to: file.processingFormat) else {
            throw RecorderError.converter
        }
        frames = 0
        peak = 0
        latestPeak.withLock { $0 = 0 }
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.consume(buffer, converter: converter, file: file)
        }
        engine.prepare()
        try engine.start()
        self.engine = engine
        self.file = file
        self.url = url
    }

    private func consume(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, file: AVAudioFile) {
        let ratio = file.processingFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: capacity) else {
            return
        }
        var delivered = false
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, outStatus in
            if delivered {
                outStatus.pointee = .noDataNow
                return nil
            }
            delivered = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, out.frameLength > 0 else { return }
        if let samples = out.int16ChannelData?[0] {
            var loudest: Int32 = 0
            for i in 0..<Int(out.frameLength) {
                loudest = max(loudest, abs(Int32(samples[i])))
            }
            let bufferPeak = Float(loudest) / 32768
            peak = max(peak, bufferPeak)
            latestPeak.withLock { $0 = bufferPeak }
        }
        frames += Int64(out.frameLength)
        try? file.write(from: out)
    }

    /// Stops and returns the clip, or nil when nothing was recording.
    func stop() -> Clip? {
        guard let engine, let url else { return nil }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
        self.file = nil  // releasing the AVAudioFile finalizes the WAV header
        self.url = nil
        let seconds = Double(frames) / 16000
        let peakDb: Float = peak > 0 ? 20 * log10(peak) : -120
        return Clip(url: url, seconds: seconds, peakDb: peakDb)
    }

    func cancel() {
        if let clip = stop() {
            try? FileManager.default.removeItem(at: clip.url)
        }
    }
}
