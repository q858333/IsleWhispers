import MediaPlayer
import XCTest
@testable import IsleWhispers

final class AudioPlayerPersistenceTests: XCTestCase {
    @MainActor
    func testRouteChangePostedFromBackgroundStopsPlaybackOnMainActor() async {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let center = NotificationCenter()
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false,
            notificationCenter: center,
            observeSystemNotifications: true
        )
        service.play()
        XCTAssertTrue(service.isPlaying)

        let stateChanged = expectation(description: "route change handled on main actor")
        let observer = center.addObserver(
            forName: .audioPlayerStateDidChange,
            object: service,
            queue: .main
        ) { _ in
            XCTAssertTrue(Thread.isMainThread)
            stateChanged.fulfill()
        }

        DispatchQueue.global().async {
            center.post(
                name: AVAudioSession.routeChangeNotification,
                object: nil,
                userInfo: [
                    AVAudioSessionRouteChangeReasonKey:
                        AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
                ]
            )
        }

        await fulfillment(of: [stateChanged], timeout: 2)
        XCTAssertFalse(service.isPlaying)
        center.removeObserver(observer)
        defaults.removePersistentDomain(forName: suite)
    }

    @MainActor
    func testExpiredTimerDuringInterruptionPreventsShouldResume() {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        var now = Date(timeIntervalSince1970: 1_000)
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false,
            nowProvider: { now }
        )
        service.play()
        service.setSleepTimer(.minutes15)
        service.handleAudioSessionInterruption(interruption(.began))

        now = now.addingTimeInterval(900)
        service.handleAudioSessionInterruption(interruption(.ended, shouldResume: true))

        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(service.sleepTimerOption, .unlimited)
        defaults.removePersistentDomain(forName: suite)
    }

    @MainActor
    func testRouteRemovalDuringInterruptionCancelsResumeIntent() {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let service = AudioPlayerService(defaults: defaults, configureSystemIntegration: false)
        service.play()
        service.handleAudioSessionInterruption(interruption(.began))
        service.handleAudioRouteChange(
            Notification(
                name: AVAudioSession.routeChangeNotification,
                userInfo: [
                    AVAudioSessionRouteChangeReasonKey:
                        AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
                ]
            )
        )
        service.handleAudioSessionInterruption(interruption(.ended, shouldResume: true))

        XCTAssertFalse(service.isPlaying)
        defaults.removePersistentDomain(forName: suite)
    }

    @MainActor
    func testUserPauseDuringInterruptionCancelsResumeIntent() {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let service = AudioPlayerService(defaults: defaults, configureSystemIntegration: false)
        service.play()
        service.handleAudioSessionInterruption(interruption(.began))
        service.pause()
        service.handleAudioSessionInterruption(interruption(.ended, shouldResume: true))

        XCTAssertFalse(service.isPlaying)
        defaults.removePersistentDomain(forName: suite)
    }

    func testAppBundleContainsUserDefaultsPrivacyManifest() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy")
        )
        let data = try Data(contentsOf: url)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: Any]
        )
        let accessedTypes = try XCTUnwrap(
            plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]]
        )
        let userDefaults = try XCTUnwrap(
            accessedTypes.first {
                $0["NSPrivacyAccessedAPIType"] as? String
                    == "NSPrivacyAccessedAPICategoryUserDefaults"
            }
        )
        XCTAssertEqual(userDefaults["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"])
    }

    @MainActor
    func testExpiredTimerRejectsRemotePlayBeforeStartingAudio() {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        var now = Date(timeIntervalSince1970: 1_000)
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false,
            nowProvider: { now }
        )
        service.setSleepTimer(.minutes15)
        now = now.addingTimeInterval(900)

        XCTAssertEqual(service.performRemoteCommand(.play), .commandFailed)
        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(service.sleepTimerOption, .unlimited)
        defaults.removePersistentDomain(forName: suite)
    }

    @MainActor
    func testRemoteCommandStatusesReflectCompletedActions() {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let service = AudioPlayerService(defaults: defaults, configureSystemIntegration: false)

        XCTAssertEqual(service.performRemoteCommand(.play), .success)
        XCTAssertTrue(service.isPlaying)
        XCTAssertEqual(service.performRemoteCommand(.next), .success)
        XCTAssertEqual(service.selectedIndex, 3)
        XCTAssertTrue(service.isPlaying)
        XCTAssertEqual(service.performRemoteCommand(.previous), .success)
        XCTAssertEqual(service.selectedIndex, 2)
        XCTAssertTrue(service.isPlaying)
        XCTAssertEqual(service.performRemoteCommand(.togglePlayback), .success)
        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(service.performRemoteCommand(.togglePlayback), .success)
        XCTAssertTrue(service.isPlaying)
        XCTAssertEqual(service.performRemoteCommand(.pause), .success)
        XCTAssertFalse(service.isPlaying)

        defaults.removePersistentDomain(forName: suite)
    }

    @MainActor
    func testRemotePlayReportsNoSuchContentWhenAudioIsMissing() {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false,
            resourceBundle: Bundle(for: AudioPlayerPersistenceTests.self)
        )

        XCTAssertEqual(service.performRemoteCommand(.play), .noSuchContent)
        XCTAssertFalse(service.isPlaying)

        defaults.removePersistentDomain(forName: suite)
    }

    @MainActor
    func testRemoteCommandBridgeWaitsForMainActorAction() async {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let service = AudioPlayerService(defaults: defaults, configureSystemIntegration: false)

        let status: MPRemoteCommandHandlerStatus = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(returning: service.handleRemoteCommand(.play))
            }
        }

        XCTAssertEqual(status, .success)
        XCTAssertTrue(service.isPlaying)
        service.pause()
        defaults.removePersistentDomain(forName: suite)
    }

    @MainActor
    func testPreparesBundledDefaultSound() {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!

        let service = AudioPlayerService(defaults: defaults, configureSystemIntegration: false)

        XCTAssertEqual(service.statusMessage, "准备就绪")
        defaults.removePersistentDomain(forName: suite)
    }

    @MainActor
    func testFallsBackToRainWhenNoSelectionWasPersisted() {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!

        let service = AudioPlayerService(defaults: defaults, configureSystemIntegration: false)

        XCTAssertEqual(service.selectedIndex, 2)
        XCTAssertFalse(service.isPlaying)
        defaults.removePersistentDomain(forName: suite)
    }

    @MainActor
    func testRestoresLastValidSelectionWithoutAutoplay() {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(11, forKey: AudioPlayerService.selectedSoundDefaultsKey)
        let service = AudioPlayerService(defaults: defaults, configureSystemIntegration: false)
        XCTAssertEqual(service.selectedIndex, 11)
        XCTAssertFalse(service.isPlaying)
        defaults.removePersistentDomain(forName: suite)
    }

    private func interruption(
        _ type: AVAudioSession.InterruptionType,
        shouldResume: Bool = false
    ) -> Notification {
        Notification(
            name: AVAudioSession.interruptionNotification,
            userInfo: [
                AVAudioSessionInterruptionTypeKey: type.rawValue,
                AVAudioSessionInterruptionOptionKey: shouldResume
                    ? AVAudioSession.InterruptionOptions.shouldResume.rawValue
                    : 0
            ]
        )
    }
}
