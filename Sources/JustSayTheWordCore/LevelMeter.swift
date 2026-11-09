// ABOUTME: The bars the recording indicator draws: a short rolling window of the microphone's recent peak levels on a
// ABOUTME: decibel scale, so speech moves the bars and a dead microphone leaves them flat.
import Foundation

public struct LevelMeter: Equatable {
    /// Peaks at or below this many decibels (relative to full scale) draw as an empty bar.
    public static let floorDb: Float = -50

    /// One height per bar, 0 (silent) to 1 (full scale), oldest first.
    public private(set) var bars: [Float]

    public init(barCount: Int = 14) {
        bars = Array(repeating: 0, count: barCount)
    }

    /// Where a peak sample level (1 is full scale) sits between the floor and full scale, in decibels.
    public static func height(forPeak peak: Float) -> Float {
        guard peak > 0 else { return 0 }
        let db = 20 * log10(peak)
        return min(1, max(0, 1 - db / floorDb))
    }

    public mutating func push(peak: Float) {
        bars.removeFirst()
        bars.append(Self.height(forPeak: peak))
    }

    public mutating func reset() {
        bars = Array(repeating: 0, count: bars.count)
    }
}
