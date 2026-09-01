import XCTest
@testable import IsleWhispers

final class RootTabBarControllerTests: XCTestCase {
    @MainActor
    func testRootContainsHomeSoundAndSettingsTabs() {
        let context = makeRootContext()
        defer { context.cleanup() }
        context.controller.loadViewIfNeeded()

        XCTAssertEqual(context.controller.viewControllers?.count, 3)
        XCTAssertEqual(
            context.controller.viewControllers?.map { $0.tabBarItem.title },
            ["首页", "声音", "设置"]
        )
    }

    @MainActor
    func testLibrarySelectionAutoPlaysAndReturnsHome() {
        let context = makeRootContext()
        defer { context.cleanup() }
        context.controller.loadViewIfNeeded()
        context.controller.selectedIndex = 1

        context.controller.selectSoundFromLibrary(at: 11)

        XCTAssertEqual(context.controller.selectedIndex, 0)
        XCTAssertEqual(context.service.selectedIndex, 11)
        XCTAssertTrue(context.service.isPlaying)
        XCTAssertEqual(context.store.recentSounds.map(\.id), [Sound.catalog[11].id])
        XCTAssertEqual(context.controller.homeViewController.displayedSoundIndex, 11)
    }

    @MainActor
    func testCarouselSelectionUpdatesLibrarySelectedState() {
        let context = makeRootContext()
        defer { context.cleanup() }
        context.controller.loadViewIfNeeded()

        context.controller.homeViewController.selectAndPlaySound(at: 4, animated: false)

        XCTAssertEqual(
            context.controller.soundLibraryViewController.selectedSoundID,
            Sound.catalog[4].id
        )
    }

    @MainActor
    func testSwitchingTabsDoesNotChangePlaybackState() {
        let context = makeRootContext()
        defer { context.cleanup() }
        context.controller.loadViewIfNeeded()

        let selectedIndex = context.service.selectedIndex
        XCTAssertFalse(context.service.isPlaying)

        context.controller.selectedIndex = 1
        context.controller.selectedIndex = 2
        context.controller.selectedIndex = 0

        XCTAssertEqual(context.service.selectedIndex, selectedIndex)
        XCTAssertFalse(context.service.isPlaying)
        XCTAssertTrue(context.store.recentSounds.isEmpty)
    }

    @MainActor
    func testSoundAndSettingsTabsUseMatchingBlurAppearanceDistinctFromHome() throws {
        let context = makeRootContext()
        defer { context.cleanup() }
        context.controller.loadViewIfNeeded()

        context.controller.selectedIndex = 0
        let homeAppearance = context.controller.tabBar.standardAppearance

        context.controller.selectedIndex = 1
        let soundAppearance = context.controller.tabBar.standardAppearance

        context.controller.selectedIndex = 2
        let settingsAppearance = context.controller.tabBar.standardAppearance

        XCTAssertNotNil(soundAppearance.backgroundEffect)
        XCTAssertNotNil(settingsAppearance.backgroundEffect)
        let homeColor = try XCTUnwrap(homeAppearance.backgroundColor)
        let soundColor = try XCTUnwrap(soundAppearance.backgroundColor)
        let settingsColor = try XCTUnwrap(settingsAppearance.backgroundColor)
        XCTAssertFalse(soundColor.isEqual(homeColor))
        XCTAssertTrue(settingsColor.isEqual(soundColor))
    }

    @MainActor
    private func makeRootContext() -> RootContext {
        let suite = "RootTabBarControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false
        )
        let store = RecentSoundsStore(defaults: defaults)
        let controller = RootTabBarController(
            playerService: service,
            recentStore: store
        )
        return RootContext(
            service: service,
            store: store,
            controller: controller,
            cleanup: {
                defaults.removePersistentDomain(forName: suite)
            }
        )
    }
}

@MainActor
private struct RootContext {
    let service: AudioPlayerService
    let store: RecentSoundsStore
    let controller: RootTabBarController
    let cleanup: () -> Void
}
