import AVFoundation
import MediaPlayer
import XCTest
@testable import IsleWhispers

final class AudioPlayerPersistenceTests: XCTestCase {
    @MainActor
    func testInterruptionEndingWithoutShouldResumeReleasesSystemPlaybackOwnership() throws {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        defer {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            defaults.removePersistentDomain(forName: suite)
        }

        let service = AudioPlayerService(defaults: defaults, configureSystemIntegration: true)
        service.play()
        XCTAssertTrue(service.isPlaying)
        XCTAssertTrue(service.ownsPlaybackSession)
        XCTAssertTrue(service.audioSessionIsActive)
        XCTAssertNotNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)

        service.handleAudioSessionInterruption(interruption(.began))
        service.handleAudioSessionInterruption(interruption(.ended))

        XCTAssertFalse(service.isPlaying)
        XCTAssertFalse(service.ownsPlaybackSession)
        XCTAssertFalse(service.audioSessionIsActive)
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
    }

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
    func testDecodeErrorFreezesRunningTimerAndCancelsNotification() throws {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = Date(timeIntervalSince1970: 1_000)
        let scheduler = PlaybackEndNotificationSchedulerSpy()
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false,
            nowProvider: { now },
            notificationScheduler: scheduler
        )
        service.play()
        service.setSleepTimer(.minutes15)
        now = Date(timeIntervalSince1970: 1_100.25)
        let audioURL = try XCTUnwrap(
            Bundle.main.url(
                forResource: service.currentSound.audioResource,
                withExtension: "caf",
                subdirectory: "Audio"
            ) ?? Bundle.main.url(
                forResource: service.currentSound.audioResource,
                withExtension: "caf"
            )
        )
        let decoder = try AVAudioPlayer(contentsOf: audioURL)

        service.audioPlayerDecodeErrorDidOccur(decoder, error: nil)

        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(service.sleepTimerPhase, .paused(remaining: 799.75))
        XCTAssertNil(scheduler.scheduledDate)
        XCTAssertEqual(scheduler.scheduledDates, [Date(timeIntervalSince1970: 1_900)])
    }

    @MainActor
    func testRouteRemovalFreezesRunningTimerAndCancelsNotification() {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = Date(timeIntervalSince1970: 1_000)
        let scheduler = PlaybackEndNotificationSchedulerSpy()
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false,
            nowProvider: { now },
            notificationScheduler: scheduler
        )
        service.play()
        service.setSleepTimer(.minutes15)
        now = Date(timeIntervalSince1970: 1_100.25)

        service.handleAudioRouteChange(
            Notification(
                name: AVAudioSession.routeChangeNotification,
                userInfo: [
                    AVAudioSessionRouteChangeReasonKey:
                        AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
                ]
            )
        )

        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(service.sleepTimerPhase, .paused(remaining: 799.75))
        XCTAssertNil(scheduler.scheduledDate)
        XCTAssertEqual(scheduler.scheduledDates, [Date(timeIntervalSince1970: 1_900)])
    }

    @MainActor
    func testInterruptionResumeRestartsExactFrozenTimerAfterPlaybackSucceeds() {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = Date(timeIntervalSince1970: 1_000)
        let scheduler = PlaybackEndNotificationSchedulerSpy()
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false,
            nowProvider: { now },
            notificationScheduler: scheduler
        )
        service.play()
        service.setSleepTimer(.minutes15)
        now = Date(timeIntervalSince1970: 1_100.25)
        service.handleAudioSessionInterruption(interruption(.began))

        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(service.sleepTimerPhase, .paused(remaining: 799.75))
        XCTAssertNil(scheduler.scheduledDate)

        now = Date(timeIntervalSince1970: 2_000)
        service.handleAudioSessionInterruption(interruption(.ended, shouldResume: true))

        XCTAssertTrue(service.isPlaying)
        XCTAssertEqual(
            service.sleepTimerPhase,
            .running(deadline: Date(timeIntervalSince1970: 2_799.75))
        )
        XCTAssertEqual(scheduler.scheduledDate, Date(timeIntervalSince1970: 2_799.75))
        XCTAssertEqual(
            scheduler.scheduledDates,
            [
                Date(timeIntervalSince1970: 1_900),
                Date(timeIntervalSince1970: 2_799.75)
            ]
        )
    }

    @MainActor
    func testInterruptionWithoutShouldResumeKeepsExactTimerPaused() {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = Date(timeIntervalSince1970: 1_000)
        let scheduler = PlaybackEndNotificationSchedulerSpy()
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false,
            nowProvider: { now },
            notificationScheduler: scheduler
        )
        service.play()
        service.setSleepTimer(.minutes15)
        now = Date(timeIntervalSince1970: 1_100.25)
        service.handleAudioSessionInterruption(interruption(.began))

        now = Date(timeIntervalSince1970: 2_000)
        service.handleAudioSessionInterruption(interruption(.ended))

        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(service.sleepTimerOption, .minutes15)
        XCTAssertEqual(service.sleepTimerPhase, .paused(remaining: 799.75))
        XCTAssertNil(scheduler.scheduledDate)
        XCTAssertEqual(scheduler.scheduledDates, [Date(timeIntervalSince1970: 1_900)])
    }

    @MainActor
    func testInterruptionBeginningAtTimerDeadlineExpiresWithoutAutoResume() {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = Date(timeIntervalSince1970: 1_000)
        let scheduler = PlaybackEndNotificationSchedulerSpy()
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false,
            nowProvider: { now },
            notificationScheduler: scheduler
        )
        service.play()
        service.setSleepTimer(.minutes15)
        now = Date(timeIntervalSince1970: 1_900)

        service.handleAudioSessionInterruption(interruption(.began))
        service.handleAudioSessionInterruption(interruption(.ended, shouldResume: true))

        XCTAssertEqual(service.sleepTimerPhase, .expired)
        XCTAssertFalse(service.isPlaying)
        XCTAssertFalse(service.ownsPlaybackSession)
        XCTAssertEqual(scheduler.scheduledDates, [Date(timeIntervalSince1970: 1_900)])
    }

    @MainActor
    func testInterruptionBeginningUsesOneNowSampleToFreezePositiveRemainingTime() {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = Date(timeIntervalSince1970: 1_000)
        var interruptionNowSequence: [Date] = []
        var interruptionNowSampleCount = 0
        let scheduler = PlaybackEndNotificationSchedulerSpy()
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false,
            nowProvider: {
                guard !interruptionNowSequence.isEmpty else { return now }
                interruptionNowSampleCount += 1
                return interruptionNowSequence.removeFirst()
            },
            notificationScheduler: scheduler
        )
        service.play()
        service.setSleepTimer(.minutes15)
        interruptionNowSequence = [
            Date(timeIntervalSince1970: 1_899.75),
            Date(timeIntervalSince1970: 1_900)
        ]

        service.handleAudioSessionInterruption(interruption(.began))

        XCTAssertEqual(interruptionNowSampleCount, 1)
        XCTAssertEqual(service.sleepTimerPhase, .paused(remaining: 0.25))
        XCTAssertFalse(service.isPlaying)
        XCTAssertNil(scheduler.scheduledDate)

        interruptionNowSequence.removeAll()
        now = Date(timeIntervalSince1970: 2_000)
        service.handleAudioSessionInterruption(interruption(.ended, shouldResume: true))

        XCTAssertTrue(service.isPlaying)
        XCTAssertEqual(
            service.sleepTimerPhase,
            .running(deadline: Date(timeIntervalSince1970: 2_000.25))
        )
        XCTAssertEqual(scheduler.scheduledDate, Date(timeIntervalSince1970: 2_000.25))
        XCTAssertEqual(
            scheduler.scheduledDates,
            [
                Date(timeIntervalSince1970: 1_900),
                Date(timeIntervalSince1970: 2_000.25)
            ]
        )
    }

    @MainActor
    func testInterruptionStillAutoResumesPlaybackUserStartedAfterTimerExpired() {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = Date(timeIntervalSince1970: 1_000)
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false,
            nowProvider: { now }
        )
        service.play()
        service.setSleepTimer(.minutes15)
        now = Date(timeIntervalSince1970: 1_900)
        service.reconcileSleepTimer()
        service.play()
        XCTAssertTrue(service.isPlaying)

        service.handleAudioSessionInterruption(interruption(.began))
        service.handleAudioSessionInterruption(interruption(.ended, shouldResume: true))

        XCTAssertEqual(service.sleepTimerPhase, .expired)
        XCTAssertTrue(service.isPlaying)
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
        service.play()
        service.setSleepTimer(.minutes15)
        now = now.addingTimeInterval(900)

        XCTAssertEqual(service.performRemoteCommand(.play), .commandFailed)
        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(service.sleepTimerOption, .minutes15)
        XCTAssertEqual(service.sleepTimerPhase, .expired)
        XCTAssertEqual(service.performRemoteCommand(.play), .success)
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

    @MainActor
    func testSelectAndPlayStartsNewSoundEvenWhenPreviouslyPaused() {
        let (service, defaults, suite) = makeService()
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertFalse(service.isPlaying)
        service.selectAndPlay(at: 4)

        XCTAssertEqual(service.selectedIndex, 4)
        XCTAssertTrue(service.isPlaying)
    }

    @MainActor
    func testMuteDoesNotPauseAndSurvivesSoundSelection() {
        let (service, defaults, suite) = makeService()
        defer { defaults.removePersistentDomain(forName: suite) }
        service.play()

        service.setMuted(true)
        XCTAssertTrue(service.isMuted)
        XCTAssertTrue(service.isPlaying)

        service.selectAndPlay(at: 7)
        XCTAssertTrue(service.isMuted)
        XCTAssertTrue(service.isPlaying)

        service.toggleMuted()
        XCTAssertFalse(service.isMuted)
        XCTAssertTrue(service.isPlaying)
    }

    @MainActor
    func testPlayingFiniteTimerPausesAndReschedulesOneNotification() {
        let suite = "AudioTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = Date(timeIntervalSince1970: 1_000)
        let scheduler = PlaybackEndNotificationSchedulerSpy()
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false,
            nowProvider: { now },
            notificationScheduler: scheduler
        )
        service.play()
        service.setSleepTimer(.minutes15)

        XCTAssertEqual(scheduler.authorizationRequestCount, 1)
        XCTAssertEqual(scheduler.scheduledDate, Date(timeIntervalSince1970: 1_900))

        now = Date(timeIntervalSince1970: 1_100)
        service.pause()
        XCTAssertEqual(service.sleepTimerPhase, .paused(remaining: 800))
        XCTAssertNil(scheduler.scheduledDate)

        now = Date(timeIntervalSince1970: 2_000)
        service.play()
        XCTAssertEqual(service.sleepTimerPhase, .running(deadline: Date(timeIntervalSince1970: 2_800)))
        XCTAssertEqual(scheduler.scheduledDate, Date(timeIntervalSince1970: 2_800))
    }

    @MainActor
    func testFiniteTimerSelectedWhilePausedWaitsToScheduleUntilPlayback() {
        let (service, defaults, suite, scheduler) = makeTimerService(
            now: Date(timeIntervalSince1970: 1_000)
        )
        defer { defaults.removePersistentDomain(forName: suite) }

        service.setSleepTimer(.minutes15)
        XCTAssertEqual(service.sleepTimerPhase, .paused(remaining: 900))
        XCTAssertEqual(scheduler.authorizationRequestCount, 1)
        XCTAssertNil(scheduler.scheduledDate)

        service.play()
        XCTAssertEqual(service.sleepTimerPhase, .running(deadline: Date(timeIntervalSince1970: 1_900)))
        XCTAssertEqual(scheduler.scheduledDate, Date(timeIntervalSince1970: 1_900))
    }

    @MainActor
    func testTimerExpiryPausesOnceAndKeepsZeroState() {
        let suite = "AudioTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = Date(timeIntervalSince1970: 1_000)
        let scheduler = PlaybackEndNotificationSchedulerSpy()
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false,
            nowProvider: { now },
            notificationScheduler: scheduler
        )
        service.play()
        service.setSleepTimer(.minutes15)
        now = Date(timeIntervalSince1970: 1_900)

        service.reconcileSleepTimer()
        service.reconcileSleepTimer()

        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(service.sleepTimerOption, .minutes15)
        XCTAssertEqual(service.sleepTimerPhase, .expired)
        XCTAssertEqual(service.sleepTimerRemaining, 0)
        XCTAssertEqual(scheduler.scheduledDate, Date(timeIntervalSince1970: 1_900))

        service.play()
        XCTAssertEqual(scheduler.scheduledDate, Date(timeIntervalSince1970: 1_900))
    }

    @MainActor
    func testChangingFiniteTimerReplacesDeadlineAndRemoteCommandsPauseIt() {
        let suite = "AudioTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = Date(timeIntervalSince1970: 1_000)
        let scheduler = PlaybackEndNotificationSchedulerSpy()
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false,
            nowProvider: { now },
            notificationScheduler: scheduler
        )
        service.play()
        service.setSleepTimer(.minutes15)
        now = Date(timeIntervalSince1970: 1_100)
        service.setSleepTimer(.minutes30)
        XCTAssertEqual(scheduler.scheduledDate, Date(timeIntervalSince1970: 2_900))

        XCTAssertEqual(service.performRemoteCommand(.pause), .success)
        XCTAssertEqual(service.sleepTimerPhase, .paused(remaining: 1_800))
        XCTAssertNil(scheduler.scheduledDate)
        XCTAssertEqual(service.performRemoteCommand(.play), .success)
        XCTAssertEqual(service.sleepTimerPhase, .running(deadline: Date(timeIntervalSince1970: 2_900)))
    }

    @MainActor
    func testDeniedNotificationSchedulingDoesNotBlockTimerExpiry() {
        let suite = "AudioTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = Date(timeIntervalSince1970: 1_000)
        let scheduler = PlaybackEndNotificationSchedulerSpy()
        scheduler.allowsScheduling = false
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false,
            nowProvider: { now },
            notificationScheduler: scheduler
        )
        service.play()
        service.setSleepTimer(.minutes15)
        now = Date(timeIntervalSince1970: 1_900)
        service.reconcileSleepTimer()

        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(service.sleepTimerPhase, .expired)
        XCTAssertNil(scheduler.scheduledDate)
    }

    @MainActor
    private func makeService() -> (AudioPlayerService, UserDefaults, String) {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (
            AudioPlayerService(defaults: defaults, configureSystemIntegration: false),
            defaults,
            suite
        )
    }

    @MainActor
    private func makeTimerService(
        now: Date
    ) -> (AudioPlayerService, UserDefaults, String, PlaybackEndNotificationSchedulerSpy) {
        let suite = "AudioTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let scheduler = PlaybackEndNotificationSchedulerSpy()
        return (
            AudioPlayerService(
                defaults: defaults,
                configureSystemIntegration: false,
                nowProvider: { now },
                notificationScheduler: scheduler
            ),
            defaults,
            suite,
            scheduler
        )
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

@MainActor
private final class PlaybackEndNotificationSchedulerSpy: PlaybackEndNotificationScheduling {
    private(set) var authorizationRequestCount = 0
    private(set) var scheduledDate: Date?
    private(set) var scheduledDates: [Date] = []
    var allowsScheduling = true

    func requestAuthorization() {
        authorizationRequestCount += 1
    }

    func schedulePlaybackEnd(at deadline: Date) {
        if allowsScheduling {
            scheduledDate = deadline
            scheduledDates.append(deadline)
        }
    }

    func cancelPlaybackEnd() {
        scheduledDate = nil
    }
}
