// ABOUTME: Tests the recording indicator's bars: the decibel scale a peak level maps onto, and the rolling window
// ABOUTME: of recent levels the bars are drawn from.
import XCTest
@testable import JustSayTheWordCore

final class LevelMeterTests: XCTestCase {
    func testSilenceIsFlatAndFullScaleIsFull() {
        XCTAssertEqual(LevelMeter.height(forPeak: 0), 0)
        XCTAssertEqual(LevelMeter.height(forPeak: 1), 1)
    }

    func testHeightIsLinearInDecibelsDownToTheFloor() {
        let halfwayToTheFloor = Float(pow(10, Double(LevelMeter.floorDb) / 2 / 20))
        XCTAssertEqual(LevelMeter.height(forPeak: halfwayToTheFloor), 0.5, accuracy: 0.001)
        let belowTheFloor = Float(pow(10, Double(LevelMeter.floorDb - 10) / 20))
        XCTAssertEqual(LevelMeter.height(forPeak: belowTheFloor), 0)
    }

    func testAClippedPeakStillFitsTheBar() {
        XCTAssertEqual(LevelMeter.height(forPeak: 1.7), 1)
    }

    func testANewLevelPushesTheOldestOneOut() {
        var meter = LevelMeter(barCount: 3)
        XCTAssertEqual(meter.bars, [0, 0, 0])
        meter.push(peak: 1)
        XCTAssertEqual(meter.bars, [0, 0, 1])
        meter.push(peak: 0)
        meter.push(peak: 0)
        XCTAssertEqual(meter.bars, [1, 0, 0])
        meter.push(peak: 0)
        XCTAssertEqual(meter.bars, [0, 0, 0])
    }

    func testResetFlattensEveryBar() {
        var meter = LevelMeter(barCount: 4)
        meter.push(peak: 1)
        meter.push(peak: 0.5)
        meter.reset()
        XCTAssertEqual(meter.bars, [0, 0, 0, 0])
    }
}
