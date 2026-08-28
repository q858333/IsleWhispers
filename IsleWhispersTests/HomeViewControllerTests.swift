import UIKit
import XCTest
@testable import IsleWhispers

final class HomeViewControllerTests: XCTestCase {
    @MainActor
    func testSettlingCarouselAutoPlaysOnceAndRecordsRecentSound() throws {
        let context = makeHomeContext()
        defer { context.cleanup() }
        layout(context.controller, size: CGSize(width: 390, height: 844))
        var stateNotificationCount = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .audioPlayerStateDidChange,
            object: context.service,
            queue: nil
        ) { _ in
            stateNotificationCount += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let carousel = try XCTUnwrap(
            findSubview(InfiniteSoundCarousel.self, in: context.controller.view)
        )
        carousel.settle(onPhysicalIndex: 19)

        XCTAssertEqual(context.service.selectedIndex, 4)
        XCTAssertTrue(context.service.isPlaying)
        XCTAssertEqual(context.store.recentSounds.map(\.id), [Sound.catalog[4].id])
        XCTAssertEqual(context.controller.displayedSoundIndex, 4)
        XCTAssertEqual(stateNotificationCount, 1)

        carousel.settle(onPhysicalIndex: 19)
        carousel.settle(onPhysicalIndex: 19)

        XCTAssertEqual(stateNotificationCount, 1)
        XCTAssertEqual(context.store.recentSounds.map(\.id), [Sound.catalog[4].id])
    }

    @MainActor
    func testInitialPlayRecordsSelectedSoundAndPresentsFullScreenFocusPage() throws {
        let context = makeHomeContext()
        defer { context.cleanup() }
        let window = UIWindow(frame: CGRect(origin: .zero, size: CGSize(width: 390, height: 844)))
        window.rootViewController = context.controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        layout(context.controller, size: window.bounds.size)
        let play = try XCTUnwrap(
            findButton(label: "开始播放并打开播放页", in: context.controller.view)
        )

        play.sendActions(for: .touchUpInside)

        XCTAssertTrue(context.service.isPlaying)
        XCTAssertEqual(context.store.recentSounds.map(\.id), [Sound.catalog[2].id])
        let focus = try XCTUnwrap(
            context.controller.presentedViewController as? FocusPlaybackViewController
        )
        XCTAssertEqual(focus.modalPresentationStyle, .fullScreen)
    }

    @MainActor
    func testAlreadyPlayingEntryPresentsWithoutRestartingAudio() throws {
        let context = makeHomeContext()
        defer { context.cleanup() }
        context.service.play()
        var stateNotificationCount = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .audioPlayerStateDidChange,
            object: context.service,
            queue: nil
        ) { _ in
            stateNotificationCount += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let window = UIWindow(frame: CGRect(origin: .zero, size: CGSize(width: 390, height: 844)))
        window.rootViewController = context.controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        layout(context.controller, size: window.bounds.size)
        let open = try XCTUnwrap(
            findButton(label: "打开播放页", in: context.controller.view)
        )

        open.sendActions(for: .touchUpInside)

        let focus = try XCTUnwrap(
            context.controller.presentedViewController as? FocusPlaybackViewController
        )
        XCTAssertEqual(focus.modalPresentationStyle, .fullScreen)
        XCTAssertEqual(stateNotificationCount, 0)
    }

    @MainActor
    func testInitialPlaybackFailureStillPresentsRecoverableFocusPage() throws {
        let context = makeHomeContext(
            resourceBundle: Bundle(for: HomeViewControllerTests.self)
        )
        defer { context.cleanup() }
        let window = UIWindow(frame: CGRect(origin: .zero, size: CGSize(width: 390, height: 844)))
        window.rootViewController = context.controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        layout(context.controller, size: window.bounds.size)
        let play = try XCTUnwrap(
            findButton(label: "开始播放并打开播放页", in: context.controller.view)
        )

        play.sendActions(for: .touchUpInside)

        XCTAssertFalse(context.service.isPlaying)
        let focus = try XCTUnwrap(
            context.controller.presentedViewController as? FocusPlaybackViewController
        )
        focus.loadViewIfNeeded()
        XCTAssertNotNil(findButton(label: "重试播放", in: focus.view))
        XCTAssertNotNil(findButton(label: "关闭播放页", in: focus.view))
    }

    @MainActor
    func testRemoteNextAndPreviousRecordEachPlayingSelectionWithoutStateReordering() throws {
        let context = makeHomeContext()
        defer { context.cleanup() }
        context.controller.loadViewIfNeeded()
        context.service.play()

        XCTAssertEqual(context.service.performRemoteCommand(.next), .success)
        XCTAssertEqual(
            context.store.recentSounds.map(\.id),
            [Sound.catalog[3].id, Sound.catalog[2].id]
        )

        XCTAssertEqual(context.service.performRemoteCommand(.previous), .success)
        let recordedIDs = [Sound.catalog[2].id, Sound.catalog[3].id]
        XCTAssertEqual(context.store.recentSounds.map(\.id), recordedIDs)

        context.service.setMuted(true)
        context.service.setSleepTimer(.minutes15)
        context.service.pause()

        XCTAssertEqual(context.store.recentSounds.map(\.id), recordedIDs)
    }

    @MainActor
    func testPausedSelectionWaitsForSuccessfulPlaybackBeforeRecordingRecent() {
        let context = makeHomeContext()
        defer { context.cleanup() }
        context.controller.loadViewIfNeeded()

        context.service.next()

        XCTAssertFalse(context.service.isPlaying)
        XCTAssertTrue(context.store.recentSounds.isEmpty)

        context.service.play()

        XCTAssertTrue(context.service.isPlaying)
        XCTAssertEqual(context.store.recentSounds.map(\.id), [Sound.catalog[3].id])
    }

    @MainActor
    func testMuteButtonDoesNotPausePlayback() throws {
        let context = makeHomeContext()
        defer { context.cleanup() }
        context.service.play()
        context.controller.loadViewIfNeeded()
        let mute = try XCTUnwrap(findButton(label: "静音", in: context.controller.view))

        mute.sendActions(for: .touchUpInside)

        XCTAssertTrue(context.service.isMuted)
        XCTAssertTrue(context.service.isPlaying)
        XCTAssertEqual(mute.accessibilityLabel, "恢复声音")
    }

    @MainActor
    func testCarouselFillsSpaceBetweenHeaderAndControlsWithoutProgressUI() throws {
        let context = makeHomeContext()
        defer { context.cleanup() }

        for size in [CGSize(width: 375, height: 667), CGSize(width: 430, height: 932)] {
            layout(context.controller, size: size)
            let carousel = try XCTUnwrap(
                findSubview(InfiniteSoundCarousel.self, in: context.controller.view)
            )
            let controls = try XCTUnwrap(
                findView(identifier: "homeControls", in: context.controller.view)
            )

            XCTAssertGreaterThan(carousel.bounds.height, 300)
            XCTAssertLessThanOrEqual(carousel.frame.maxY, controls.frame.minY)
            XCTAssertNil(findSubview(UIProgressView.self, in: context.controller.view))
            XCTAssertFalse(allLabels(in: context.controller.view).contains {
                $0.text?.range(
                    of: #"^\d{1,2}:\d{2}$"#,
                    options: .regularExpression
                ) != nil
            })
        }
    }

    @MainActor
    func testProgrammaticSelectionNotificationRepositionsWithoutAutoplay() throws {
        let context = makeHomeContext()
        defer { context.cleanup() }
        layout(context.controller, size: CGSize(width: 390, height: 844))

        context.service.next()

        let carousel = try XCTUnwrap(
            findSubview(InfiniteSoundCarousel.self, in: context.controller.view)
        )
        XCTAssertEqual(context.service.selectedIndex, 3)
        XCTAssertFalse(context.service.isPlaying)
        XCTAssertEqual(context.controller.displayedSoundIndex, 3)
        XCTAssertEqual(carousel.displayedLogicalIndex, 3)
        XCTAssertTrue(context.store.recentSounds.isEmpty)
    }

    @MainActor
    func testDirectSelectionUsesSinglePlayAndRecentFlow() throws {
        let context = makeHomeContext()
        defer { context.cleanup() }
        layout(context.controller, size: CGSize(width: 390, height: 844))

        context.controller.selectAndPlaySound(at: 7, animated: false)

        let carousel = try XCTUnwrap(
            findSubview(InfiniteSoundCarousel.self, in: context.controller.view)
        )
        XCTAssertEqual(context.service.selectedIndex, 7)
        XCTAssertTrue(context.service.isPlaying)
        XCTAssertEqual(context.store.recentSounds.map(\.id), [Sound.catalog[7].id])
        XCTAssertEqual(context.controller.displayedSoundIndex, 7)
        XCTAssertEqual(carousel.displayedLogicalIndex, 7)
    }

    @MainActor
    func testRecentSelectionAutoplaysRecordsDismissesAndPositionsCarousel() throws {
        let context = makeHomeContext()
        defer { context.cleanup() }
        context.store.record(Sound.catalog[9])

        let window = UIWindow(frame: CGRect(origin: .zero, size: CGSize(width: 390, height: 844)))
        window.rootViewController = context.controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        layout(context.controller, size: window.bounds.size)

        let recentButton = try XCTUnwrap(
            findButton(label: "最近播放", in: context.controller.view)
        )
        recentButton.sendActions(for: .touchUpInside)

        let recentController = try XCTUnwrap(
            context.controller.presentedViewController as? RecentSoundsViewController
        )
        recentController.loadViewIfNeeded()
        let collection = try XCTUnwrap(
            findSubview(UICollectionView.self, in: recentController.view)
        )
        recentController.collectionView(
            collection,
            didSelectItemAt: IndexPath(item: 0, section: 0)
        )

        let carousel = try XCTUnwrap(
            findSubview(InfiniteSoundCarousel.self, in: context.controller.view)
        )
        XCTAssertEqual(context.service.selectedIndex, 9)
        XCTAssertTrue(context.service.isPlaying)
        XCTAssertEqual(context.store.recentSounds.map(\.id).first, Sound.catalog[9].id)
        XCTAssertEqual(context.controller.displayedSoundIndex, 9)
        XCTAssertEqual(carousel.displayedLogicalIndex, 9)
        XCTAssertTrue(waitForDismissal(of: context.controller))
    }

    @MainActor
    func testSleepTimerControlUpdatesPlayerService() throws {
        let context = makeHomeContext()
        defer { context.cleanup() }
        context.controller.loadViewIfNeeded()
        let timerButton = try XCTUnwrap(
            findButton(label: "睡眠定时：15 分钟", in: context.controller.view)
        )

        timerButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(context.service.sleepTimerOption, .minutes15)
    }

    @MainActor
    func testBackgroundSoftnessStaysBehindTransparentPagingSurface() throws {
        let context = makeHomeContext()
        defer { context.cleanup() }
        layout(context.controller, size: CGSize(width: 390, height: 844))

        let carousel = try XCTUnwrap(
            findSubview(InfiniteSoundCarousel.self, in: context.controller.view)
        )
        let blur = try XCTUnwrap(
            findSubview(UIVisualEffectView.self, in: context.controller.view)
        )

        XCTAssertEqual(blur.alpha, 0.20, accuracy: 0.001)
        XCTAssertFalse(carousel.isDescendant(of: blur))
        XCTAssertGreaterThan(context.controller.view.subviews.firstIndex(of: carousel) ?? 0, 0)
    }

    @MainActor
    func testBackgroundTransitionKeepsOneFullScreenBaseBehindGrowingCardInBothDirections() throws {
        let context = makeHomeContext()
        defer { context.cleanup() }
        layout(context.controller, size: CGSize(width: 390, height: 844))
        let backgrounds = context.controller.view.subviews.compactMap { $0 as? UIImageView }
        let sourceBackground = try XCTUnwrap(backgrounds.first)
        let targetBackground = try XCTUnwrap(backgrounds.dropFirst().first)
        let carousel = try XCTUnwrap(
            findSubview(InfiniteSoundCarousel.self, in: context.controller.view)
        )
        let collectionView = try XCTUnwrap(
            carousel.subviews.compactMap { $0 as? UICollectionView }.first
        )
        let flowLayout = try XCTUnwrap(
            collectionView.collectionViewLayout as? SoundCarouselFlowLayout
        )
        let from = try XCTUnwrap(
            flowLayout.layoutAttributesForItem(at: IndexPath(item: 17, section: 0))
        )
        let to = try XCTUnwrap(
            flowLayout.layoutAttributesForItem(at: IndexPath(item: 18, section: 0))
        )
        let pitch = to.center.x - from.center.x

        collectionView.contentOffset.x = from.center.x + pitch * 0.25
            - collectionView.bounds.width / 2
        carousel.scrollViewDidScroll(collectionView)

        XCTAssertEqual(sourceBackground.transform, .identity)
        XCTAssertEqual(sourceBackground.layer.cornerRadius, 0, accuracy: 0.1)
        XCTAssertEqual(targetBackground.transform.a, 0.925, accuracy: 0.001)
        XCTAssertEqual(targetBackground.transform.tx, 292.5, accuracy: 0.25)
        XCTAssertEqual(targetBackground.layer.cornerRadius, 21, accuracy: 0.1)
        XCTAssertEqual(sourceBackground.alpha, 1, accuracy: 0.01)
        XCTAssertEqual(targetBackground.alpha, 1, accuracy: 0.01)
        XCTAssertGreaterThan(
            try XCTUnwrap(context.controller.view.subviews.firstIndex(of: targetBackground)),
            try XCTUnwrap(context.controller.view.subviews.firstIndex(of: sourceBackground))
        )

        collectionView.contentOffset.x = from.center.x + pitch * 0.75
            - collectionView.bounds.width / 2
        carousel.scrollViewDidScroll(collectionView)

        XCTAssertEqual(sourceBackground.transform, .identity)
        XCTAssertEqual(sourceBackground.layer.cornerRadius, 0, accuracy: 0.1)
        XCTAssertEqual(targetBackground.transform.a, 0.975, accuracy: 0.001)
        XCTAssertEqual(targetBackground.transform.tx, 97.5, accuracy: 0.25)
        XCTAssertEqual(targetBackground.layer.cornerRadius, 7, accuracy: 0.1)
        XCTAssertEqual(sourceBackground.alpha, 1, accuracy: 0.01)
        XCTAssertEqual(targetBackground.alpha, 1, accuracy: 0.01)

        let previous = try XCTUnwrap(
            flowLayout.layoutAttributesForItem(at: IndexPath(item: 16, section: 0))
        )
        collectionView.contentOffset.x = previous.center.x + pitch * 0.75
            - collectionView.bounds.width / 2
        carousel.scrollViewDidScroll(collectionView)

        XCTAssertEqual(sourceBackground.transform.a, 0.925, accuracy: 0.001)
        XCTAssertEqual(sourceBackground.transform.tx, -292.5, accuracy: 0.25)
        XCTAssertEqual(sourceBackground.layer.cornerRadius, 21, accuracy: 0.1)
        XCTAssertEqual(targetBackground.transform, .identity)
        XCTAssertEqual(targetBackground.layer.cornerRadius, 0, accuracy: 0.1)
        XCTAssertGreaterThan(
            try XCTUnwrap(context.controller.view.subviews.firstIndex(of: sourceBackground)),
            try XCTUnwrap(context.controller.view.subviews.firstIndex(of: targetBackground))
        )
    }

    @MainActor
    func testSettledBackgroundUsesShortSimpleFadeDuration() {
        XCTAssertGreaterThanOrEqual(HomeViewController.backgroundSettleDuration, 0.20)
        XCTAssertLessThanOrEqual(HomeViewController.backgroundSettleDuration, 0.30)
    }

    @MainActor
    func testSoundArtworkReusesImageForSameResolvedResourceURL() throws {
        let first = try XCTUnwrap(SoundArtwork.image(for: Sound.catalog[0]))
        let repeated = try XCTUnwrap(SoundArtwork.image(for: Sound.catalog[0]))
        let different = try XCTUnwrap(SoundArtwork.image(for: Sound.catalog[1]))

        XCTAssertTrue(first === repeated)
        XCTAssertFalse(first === different)
    }

    @MainActor
    private func makeHomeContext(resourceBundle: Bundle = .main) -> HomeContext {
        let suite = "HomeViewControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false,
            resourceBundle: resourceBundle
        )
        let store = RecentSoundsStore(defaults: defaults)
        let controller = HomeViewController(
            playerService: service,
            recentStore: store
        )
        return HomeContext(
            service: service,
            store: store,
            controller: controller,
            cleanup: {
                defaults.removePersistentDomain(forName: suite)
            }
        )
    }

    @MainActor
    private func layout(_ controller: UIViewController, size: CGSize) {
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(origin: .zero, size: size)
        for _ in 0..<3 {
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
        }
    }

    @MainActor
    private func findSubview<T: UIView>(_ type: T.Type, in root: UIView) -> T? {
        descendants(in: root).compactMap { $0 as? T }.first
    }

    @MainActor
    private func findButton(label: String, in root: UIView) -> UIButton? {
        descendants(in: root)
            .compactMap { $0 as? UIButton }
            .first { $0.accessibilityLabel == label }
    }

    @MainActor
    private func findView(identifier: String, in root: UIView) -> UIView? {
        descendants(in: root).first { $0.accessibilityIdentifier == identifier }
    }

    @MainActor
    private func allLabels(in root: UIView) -> [UILabel] {
        descendants(in: root).compactMap { $0 as? UILabel }
    }

    @MainActor
    private func descendants(in root: UIView) -> [UIView] {
        [root] + root.subviews.flatMap(descendants(in:))
    }

    @MainActor
    private func waitForDismissal(of controller: UIViewController) -> Bool {
        let deadline = Date().addingTimeInterval(1)
        while controller.presentedViewController != nil, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        return controller.presentedViewController == nil
    }
}

@MainActor
private struct HomeContext {
    let service: AudioPlayerService
    let store: RecentSoundsStore
    let controller: HomeViewController
    let cleanup: () -> Void
}
