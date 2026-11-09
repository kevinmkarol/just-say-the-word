// ABOUTME: Tests the activity log's line format and reading the most recent entries back, problems marked as such,
// ABOUTME: and how an entry splits into its headline and detail for the Activity view.
import XCTest
@testable import JustSayTheWordCore

final class ActivityLogTests: XCTestCase {
    func testALineIsTheTimeThenTheMessage() {
        XCTAssertEqual(
            ActivityLog.line(time: "2026-11-08 20:16:56", message: "hotkey tap running", isProblem: false),
            "2026-11-08 20:16:56 hotkey tap running\n"
        )
    }

    func testAProblemIsMarkedInItsLineAndReadBackWithoutTheMark() {
        let line = ActivityLog.line(time: "2026-11-08 20:16:56", message: "Can't record: no microphone", isProblem: true)
        XCTAssertEqual(
            ActivityLog.recent(in: line, limit: 10),
            [ActivityEntry(time: "2026-11-08 20:16:56", message: "Can't record: no microphone", isProblem: true)]
        )
    }

    func testRecentEntriesComeBackNewestFirst() {
        let contents = [
            ActivityLog.line(time: "2026-11-08 20:15:03", message: "started", isProblem: false),
            ActivityLog.line(time: "2026-11-08 20:15:10", message: "microphone access granted", isProblem: false),
            ActivityLog.line(time: "2026-11-08 20:15:21", message: "hotkey tap running", isProblem: false),
        ].joined()
        XCTAssertEqual(
            ActivityLog.recent(in: contents, limit: 2),
            [
                ActivityEntry(time: "2026-11-08 20:15:21", message: "hotkey tap running", isProblem: false),
                ActivityEntry(time: "2026-11-08 20:15:10", message: "microphone access granted", isProblem: false),
            ]
        )
    }

    func testALineWithoutATimeIsKeptAsAMessageOnItsOwn() {
        XCTAssertEqual(
            ActivityLog.recent(in: "something another program wrote\n\n", limit: 10),
            [ActivityEntry(time: "", message: "something another program wrote", isProblem: false)]
        )
    }

    func testAnEmptyLogHasNoEntries() {
        XCTAssertEqual(ActivityLog.recent(in: "", limit: 10), [])
    }

    func testAnEntrysTimeSplitsIntoItsDayAndItsClock() {
        let entry = ActivityEntry(time: "2026-11-08 20:16:56", message: "hotkey tap running", isProblem: false)
        XCTAssertEqual(entry.day, "2026-11-08")
        XCTAssertEqual(entry.clock, "20:16:56")
        let undated = ActivityEntry(time: "", message: "something another program wrote", isProblem: false)
        XCTAssertEqual(undated.day, "")
        XCTAssertEqual(undated.clock, "")
    }

    func testAMessageSplitsIntoAHeadlineAndItsDetailAtTheFirstColonOrSemicolon() {
        let recorded = ActivityEntry(
            time: "", message: "recorded 12.2 s: MacBook Pro Microphone, peak -15 dBFS", isProblem: false
        )
        XCTAssertEqual(recorded.headline, "recorded 12.2 s")
        XCTAssertEqual(recorded.detail, "MacBook Pro Microphone, peak -15 dBFS")
        let started = ActivityEntry(time: "", message: "started; hotkey Right ⌘; config: /a/b", isProblem: false)
        XCTAssertEqual(started.headline, "started")
        XCTAssertEqual(started.detail, "hotkey Right ⌘; config: /a/b", "only the first break splits")
    }

    func testAMessageWithNoBreakIsAllHeadline() {
        let entry = ActivityEntry(time: "", message: "hotkey tap running", isProblem: false)
        XCTAssertEqual(entry.headline, "hotkey tap running")
        XCTAssertNil(entry.detail)
    }

    func testEntriesGroupByDayInTheOrderTheyCome() {
        let entries = [
            ActivityEntry(time: "2026-11-08 09:00:00", message: "c", isProblem: false),
            ActivityEntry(time: "2026-11-08 08:00:00", message: "b", isProblem: false),
            ActivityEntry(time: "2026-11-07 23:00:00", message: "a", isProblem: false),
        ]
        let days = ActivityLog.byDay(entries)
        XCTAssertEqual(days.map(\.day), ["2026-11-08", "2026-11-07"])
        XCTAssertEqual(days.map { $0.entries.map(\.message) }, [["c", "b"], ["a"]])
    }
}
