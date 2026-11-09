// ABOUTME: Tests the history file's line format, that a transcript always stays one line of it, and reading the
// ABOUTME: most recent transcripts back out of it.
import XCTest
@testable import JustSayTheWordCore

final class TranscriptHistoryTests: XCTestCase {
    func testALineIsTimeSecondsAndTextSeparatedByTabs() {
        XCTAssertEqual(
            TranscriptHistory.line(time: "2026-11-08 14:55:24", seconds: 11.94, text: "Where is that located?"),
            "2026-11-08 14:55:24\t11.9\tWhere is that located?\n"
        )
    }

    func testTabsAndNewlinesInATranscriptAreFlattenedSoItStaysOneLine() {
        XCTAssertEqual(
            TranscriptHistory.line(time: "t", seconds: 1, text: "one\ntwo\tthree"),
            "t\t1.0\tone two three\n"
        )
    }

    func testEveryKindOfLineBreakIsFlattenedSoTheLineReadsBackWhole() {
        let line = TranscriptHistory.line(time: "t", seconds: 1, text: "one\r\ntwo\rthree\u{2028}four")
        XCTAssertEqual(line, "t\t1.0\tone two three four\n")
        XCTAssertEqual(TranscriptHistory.recent(in: line, limit: 1).first?.text, "one two three four")
    }

    func testRecentTranscriptsComeBackNewestFirst() {
        let contents = [
            TranscriptHistory.line(time: "2026-11-08 14:55:24", seconds: 11.9, text: "first"),
            TranscriptHistory.line(time: "2026-11-08 14:56:02", seconds: 8.3, text: "second"),
            TranscriptHistory.line(time: "2026-11-08 14:56:39", seconds: 14.9, text: "third"),
        ].joined()
        XCTAssertEqual(
            TranscriptHistory.recent(in: contents, limit: 2),
            [
                Transcript(time: "2026-11-08 14:56:39", seconds: 14.9, text: "third"),
                Transcript(time: "2026-11-08 14:56:02", seconds: 8.3, text: "second"),
            ]
        )
    }

    func testEmptyAndMalformedLinesAreSkipped() {
        let contents = "t1\t0.0\t\nnot a history line\n\nt2\t2.5\tkept\n"
        XCTAssertEqual(
            TranscriptHistory.recent(in: contents, limit: 10),
            [Transcript(time: "t2", seconds: 2.5, text: "kept")]
        )
    }

    func testAnEmptyHistoryHasNoRecentTranscripts() {
        XCTAssertEqual(TranscriptHistory.recent(in: "", limit: 10), [])
    }
}
