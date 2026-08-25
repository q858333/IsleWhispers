import MediaPlayer
import XCTest
@testable import IsleWhispers

final class AudioPlayerPersistenceTests: XCTestCase {
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
}
