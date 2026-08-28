import UserNotifications
import XCTest
@testable import IsleWhispers

final class PlaybackEndNotificationSchedulerTests: XCTestCase {
    func testPlaybackEndNotificationUsesStableIdentityAndCopy() {
        XCTAssertEqual(
            LocalPlaybackEndNotificationScheduler.requestIdentifier,
            "isleWhispers.playbackEnded"
        )
        XCTAssertEqual(LocalPlaybackEndNotificationScheduler.notificationTitle, "播放已结束")
    }

    func testForegroundPlaybackEndNotificationUsesBannerAndSound() {
        let options = AppDelegate.foregroundNotificationOptions
        XCTAssertTrue(options.contains(.banner))
        XCTAssertTrue(options.contains(.sound))
    }
}
