// ABOUTME: Tests that a recording whose transcription failed is kept on disk under a name that sorts by time, and
// ABOUTME: found again with the others, oldest first.
import XCTest
@testable import JustSayTheWordCore

final class FailedRecordingsTests: XCTestCase {
    private var scratch: URL!
    private var recordings: FailedRecordings!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        recordings = FailedRecordings(directory: scratch.appendingPathComponent("Failed Recordings"))
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: scratch)
    }

    private func clip(_ contents: String) throws -> URL {
        let url = scratch.appendingPathComponent("just-say-the-word-\(UUID().uuidString).wav")
        try Data(contents.utf8).write(to: url)
        return url
    }

    private func date(_ secondsAfterReference: TimeInterval) -> Date {
        Date(timeIntervalSinceReferenceDate: secondsAfterReference)
    }

    func testNothingIsKeptBeforeAnythingFails() {
        XCTAssertEqual(recordings.all(), [])
        XCTAssertNil(recordings.latest)
    }

    func testAKeptClipMovesIntoTheDirectoryWithItsAudioIntact() throws {
        let original = try clip("audio")
        let kept = try recordings.keep(original, recordedAt: date(0))
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.path))
        XCTAssertEqual(kept.deletingLastPathComponent().path, recordings.directory.path)
        XCTAssertEqual(kept.pathExtension, "wav")
        XCTAssertEqual(try String(contentsOf: kept, encoding: .utf8), "audio")
    }

    func testKeptClipsAreListedOldestFirstWhateverOrderTheyWereKeptIn() throws {
        let newer = try recordings.keep(try clip("newer"), recordedAt: date(3600))
        let older = try recordings.keep(try clip("older"), recordedAt: date(0))
        XCTAssertEqual(recordings.all().map(\.lastPathComponent), [older, newer].map(\.lastPathComponent))
        XCTAssertEqual(recordings.latest?.lastPathComponent, newer.lastPathComponent)
    }

    func testOtherFilesInTheDirectoryAreNotRecordings() throws {
        try recordings.keep(try clip("audio"), recordedAt: date(0))
        try Data().write(to: recordings.directory.appendingPathComponent(".DS_Store"))
        XCTAssertEqual(recordings.all().count, 1)
    }
}
