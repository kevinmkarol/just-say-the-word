// ABOUTME: Tests the hold/tap/cancel state machine against the way the hotkey is actually used: held, tapped for
// ABOUTME: hands-free, interrupted by a shortcut, or left down past the time limit.
import XCTest
@testable import JustSayTheWordCore

final class PushToTalkTests: XCTestCase {
    func testHoldRecordsAndReleaseStops() {
        let ptt = PushToTalk()
        XCTAssertEqual(ptt.handle(.hotkeyDown(at: 0)), .start)
        XCTAssertTrue(ptt.isRecording)
        XCTAssertEqual(ptt.handle(.hotkeyUp(at: 1.2)), .stop)
        XCTAssertEqual(ptt.state, .idle)
    }

    func testTapKeepsRecordingUntilTheNextPress() {
        let ptt = PushToTalk()
        XCTAssertEqual(ptt.handle(.hotkeyDown(at: 0)), .start)
        XCTAssertEqual(ptt.handle(.hotkeyUp(at: 0.1)), .none)
        XCTAssertEqual(ptt.state, .handsFree)
        XCTAssertEqual(ptt.handle(.otherKeyDown), .none, "typing while hands-free is allowed")
        XCTAssertEqual(ptt.handle(.hotkeyDown(at: 5)), .stop)
        XCTAssertEqual(ptt.handle(.hotkeyUp(at: 5.1)), .none, "the release of the stopping press is ignored")
        XCTAssertEqual(ptt.state, .idle)
    }

    func testTapIsAHoldWhenHandsFreeIsOff() {
        let ptt = PushToTalk(tapTogglesHandsFree: false)
        XCTAssertEqual(ptt.handle(.hotkeyDown(at: 0)), .start)
        XCTAssertEqual(ptt.handle(.hotkeyUp(at: 0.1)), .stop)
    }

    func testAnotherKeyDuringAHoldIsAShortcutNotDictation() {
        let ptt = PushToTalk()
        XCTAssertEqual(ptt.handle(.hotkeyDown(at: 0)), .start)
        XCTAssertEqual(ptt.handle(.otherKeyDown), .cancel)
        XCTAssertEqual(ptt.state, .idle)
        XCTAssertEqual(ptt.handle(.hotkeyUp(at: 0.5)), .none)
    }

    func testEscapeCancelsEitherKindOfRecording() {
        let ptt = PushToTalk()
        _ = ptt.handle(.hotkeyDown(at: 0))
        XCTAssertEqual(ptt.handle(.escape), .cancel)
        _ = ptt.handle(.hotkeyDown(at: 1))
        _ = ptt.handle(.hotkeyUp(at: 1.1))
        XCTAssertEqual(ptt.state, .handsFree)
        XCTAssertEqual(ptt.handle(.escape), .cancel)
        XCTAssertEqual(ptt.state, .idle)
    }

    func testTimeoutStopsAndIdleIgnoresEverythingElse() {
        let ptt = PushToTalk()
        _ = ptt.handle(.hotkeyDown(at: 0))
        XCTAssertEqual(ptt.handle(.timeout), .stop)
        XCTAssertEqual(ptt.handle(.timeout), .none)
        XCTAssertEqual(ptt.handle(.hotkeyUp(at: 2)), .none)
        XCTAssertEqual(ptt.handle(.otherKeyDown), .none)
        XCTAssertEqual(ptt.handle(.escape), .none)
    }
}
