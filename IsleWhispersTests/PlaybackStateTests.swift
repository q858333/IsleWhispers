import XCTest
@testable import IsleWhispers

@MainActor
final class PlaybackStateTests: XCTestCase {
    func testNextAndPreviousWrapAroundCatalog() {
        var state = PlaybackState(selectedIndex: 14, isPlaying: false)
        state.selectNext(count: 15)
        XCTAssertEqual(state.selectedIndex, 0)
        state.selectPrevious(count: 15)
        XCTAssertEqual(state.selectedIndex, 14)
    }

    func testSelectingSoundPreservesPlayingIntent() {
        var state = PlaybackState(selectedIndex: 2, isPlaying: true)
        state.select(index: 7, count: 15)
        XCTAssertEqual(state, PlaybackState(selectedIndex: 7, isPlaying: true))
    }

    func testSleepTimerExpiresAtDeadline() {
        let now = Date(timeIntervalSince1970: 1_000)
        var state = SleepTimerState()
        state.schedule(.minutes15, now: now)
        XCTAssertFalse(state.isExpired(at: now.addingTimeInterval(899)))
        XCTAssertTrue(state.isExpired(at: now.addingTimeInterval(900)))
    }
}
