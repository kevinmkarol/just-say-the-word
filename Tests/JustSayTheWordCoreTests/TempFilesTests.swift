// ABOUTME: Tests that the recordings and transcription folders a previous run left in the temporary folder are
// ABOUTME: removed, and that nothing else there is touched.
import XCTest
@testable import JustSayTheWordCore

final class TempFilesTests: XCTestCase {
    func testLeftoversWithThePrefixAreRemovedAndOtherEntriesAreKept() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: dir.appendingPathComponent("just-say-the-word-abc"), withIntermediateDirectories: true)
        try Data().write(to: dir.appendingPathComponent("just-say-the-word-def.wav"))
        try Data().write(to: dir.appendingPathComponent("other.wav"))

        try TempFiles.removeLeftovers(in: dir, prefix: "just-say-the-word-")

        XCTAssertEqual(try fm.contentsOfDirectory(atPath: dir.path), ["other.wav"])
    }

    func testAMissingFolderIsNotAnError() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertNoThrow(try TempFiles.removeLeftovers(in: dir, prefix: "just-say-the-word-"))
    }
}
