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

    func testFiniteSleepTimerPausesAndResumesWithExactRemainingTime() {
        let start = Date(timeIntervalSince1970: 1_000)
        var state = SleepTimerState()

        state.schedule(.minutes15, now: start)
        XCTAssertEqual(state.phase, .running(deadline: start.addingTimeInterval(900)))
        XCTAssertEqual(state.remainingTime(at: start.addingTimeInterval(100)), 800)

        state.pause(at: start.addingTimeInterval(100))
        XCTAssertEqual(state.phase, .paused(remaining: 800))
        XCTAssertNil(state.deadline)

        state.resume(at: Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(state.phase, .running(deadline: Date(timeIntervalSince1970: 2_800)))
    }

    func testExpiredSleepTimerKeepsFiniteOptionAndZeroRemaining() {
        let start = Date(timeIntervalSince1970: 1_000)
        var state = SleepTimerState()
        state.schedule(.minutes15, now: start)

        XCTAssertTrue(state.expireIfNeeded(at: start.addingTimeInterval(900)))
        XCTAssertEqual(state.option, .minutes15)
        XCTAssertEqual(state.phase, .expired)
        XCTAssertEqual(state.remainingTime(at: start.addingTimeInterval(901)), 0)
        XCTAssertFalse(state.expireIfNeeded(at: start.addingTimeInterval(902)))

        state.resume(at: start.addingTimeInterval(903))
        XCTAssertEqual(state.phase, .expired)
    }

    func testUnlimitedSleepTimerHasNoRemainingTime() {
        var state = SleepTimerState()
        state.schedule(.unlimited, now: Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(state.phase, .unlimited)
        XCTAssertNil(state.deadline)
        XCTAssertNil(state.remainingTime(at: Date(timeIntervalSince1970: 2_000)))
    }
}
