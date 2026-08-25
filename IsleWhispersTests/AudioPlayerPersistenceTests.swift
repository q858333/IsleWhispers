import XCTest
@testable import IsleWhispers

final class AudioPlayerPersistenceTests: XCTestCase {
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
