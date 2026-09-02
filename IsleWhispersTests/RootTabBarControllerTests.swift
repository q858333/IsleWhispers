import XCTest
@testable import IsleWhispers

final class RootTabBarControllerTests: XCTestCase {
    @MainActor
    func testRootTabTitlesUseInjectedLanguageBundle() throws {
        let expectations = [
            ("en", ["Home", "Sounds", "Settings"]),
            ("zh-Hans", ["首页", "声音", "设置"]),
            ("zh-Hant", ["首頁", "聲音", "設定"])
        ]

        for (language, titles) in expectations {
            let context = makeRootContext(
                localizationBundle: try LocalizationTestSupport.bundle(language)
            )
            defer { context.cleanup() }
            context.controller.loadViewIfNeeded()

            XCTAssertEqual(
                context.controller.viewControllers?.map { $0.tabBarItem.title ?? "" },
                titles,
                language
            )
        }
    }

    @MainActor
    func testRootPassesInjectedBundleToAllThreeTabs() throws {
        let context = makeRootContext(
            localizationBundle: try LocalizationTestSupport.bundle("en")
        )
        defer { context.cleanup() }
        context.controller.homeViewController.loadViewIfNeeded()
        context.controller.soundLibraryViewController.loadViewIfNeeded()
        context.controller.settingsViewController.loadViewIfNeeded()

        XCTAssertNotNil(
            findLabel(text: "Now · Hear the island", in: context.controller.homeViewController.view)
        )
        XCTAssertNotNil(
            findLabel(text: "Sound Library", in: context.controller.soundLibraryViewController.view)
        )
        XCTAssertNotNil(
            findLabel(text: "Settings", in: context.controller.settingsViewController.view)
        )
    }

    @MainActor
    func testRootContainsHomeSoundAndSettingsTabs() throws {
        let context = makeRootContext(
            localizationBundle: try LocalizationTestSupport.bundle("zh-Hans")
        )
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
    func testUserSelectingSecondaryTabsUpdatesBlurAppearance() throws {
        let context = makeRootContext()
        defer { context.cleanup() }
        context.controller.loadViewIfNeeded()
        let controllers = try XCTUnwrap(context.controller.viewControllers)
        let homeColor = try XCTUnwrap(
            context.controller.tabBar.standardAppearance.backgroundColor
        )

        for index in [1, 2] {
            context.controller.selectedViewController = controllers[0]
            context.controller.selectedViewController = controllers[index]

            XCTAssertEqual(context.controller.selectedIndex, index)
            let selectedColor = try XCTUnwrap(
                context.controller.tabBar.standardAppearance.backgroundColor
            )
            XCTAssertFalse(selectedColor.isEqual(homeColor))
        }
    }

    @MainActor
    private func makeRootContext(localizationBundle: Bundle = .main) -> RootContext {
        let suite = "RootTabBarControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false
        )
        let store = RecentSoundsStore(defaults: defaults)
        let controller = RootTabBarController(
            playerService: service,
            recentStore: store,
            localizationBundle: localizationBundle
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

    @MainActor
    private func findLabel(text: String, in root: UIView) -> UILabel? {
        descendants(in: root)
            .compactMap { $0 as? UILabel }
            .first { $0.text == text }
    }

    @MainActor
    private func descendants(in root: UIView) -> [UIView] {
        [root] + root.subviews.flatMap(descendants(in:))
    }
}

@MainActor
private struct RootContext {
    let service: AudioPlayerService
    let store: RecentSoundsStore
    let controller: RootTabBarController
    let cleanup: () -> Void
}
