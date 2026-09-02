import UserNotifications
import XCTest
@testable import IsleWhispers

final class PlaybackEndNotificationSchedulerTests: XCTestCase {
    @MainActor
    func testPlaybackEndNotificationUsesStableIdentity() {
        XCTAssertEqual(
            LocalPlaybackEndNotificationScheduler.requestIdentifier,
            "isleWhispers.playbackEnded"
        )
    }

    @MainActor
    func testPlaybackEndNotificationTitleUsesInjectedBundle() async throws {
        let expectations = [
            ("en", "Playback Ended"),
            ("zh-Hans", "播放已结束"),
            ("zh-Hant", "播放已結束")
        ]

        for (language, title) in expectations {
            let center = UserNotificationCenterSpy()
            let requestAdded = expectation(description: "\(language) notification request added")
            center.onAdd = { _ in requestAdded.fulfill() }
            let scheduler = LocalPlaybackEndNotificationScheduler(
                center: center,
                localizationBundle: try LocalizationTestSupport.bundle(language)
            )

            scheduler.schedulePlaybackEnd(at: Date().addingTimeInterval(60))

            await fulfillment(of: [requestAdded], timeout: 1)
            let request = try XCTUnwrap(center.addedRequests.last)
            XCTAssertEqual(request.identifier, "isleWhispers.playbackEnded", language)
            XCTAssertEqual(request.content.title, title, language)
        }
    }

    func testForegroundPlaybackEndNotificationUsesBannerAndSound() {
        let options = AppDelegate.foregroundNotificationOptions
        XCTAssertTrue(options.contains(.banner))
        XCTAssertTrue(options.contains(.sound))
    }
}

@MainActor
private final class UserNotificationCenterSpy: PlaybackEndUserNotificationCenter {
    private(set) var addedRequests: [UNNotificationRequest] = []
    var onAdd: ((UNNotificationRequest) -> Void)?

    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping @Sendable (Bool, Error?) -> Void
    ) {
        completionHandler(true, nil)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}

    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?
    ) {
        addedRequests.append(request)
        onAdd?(request)
        completionHandler?(nil)
    }
}
