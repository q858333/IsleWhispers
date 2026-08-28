import UIKit
import XCTest
@testable import IsleWhispers

final class FocusPlaybackViewControllerTests: XCTestCase {
    @MainActor
    func testPlayingPageShowsArtworkCountdownAndNoCloseButton() throws {
        let context = makeFocusContext()
        defer { context.cleanup() }
        context.service.play()
        context.service.setSleepTimer(.minutes15)
        layout(context.controller, size: CGSize(width: 390, height: 844))

        XCTAssertEqual(
            findLabel(identifier: "focusSoundTitle", in: context.controller.view)?.text,
            context.service.currentSound.title
        )
        XCTAssertEqual(
            findLabel(identifier: "focusCountdown", in: context.controller.view)?.text,
            "15:00",
            "countdown labels: \(matchingLabelTexts(identifier: "focusCountdown", in: context.controller.view))"
        )
        XCTAssertNotNil(findButton(label: "暂停播放", in: context.controller.view))
        XCTAssertNil(findButton(label: "关闭播放页", in: context.controller.view))
        let blur = try XCTUnwrap(
            findSubview(UIVisualEffectView.self, in: context.controller.view)
        )
        XCTAssertLessThanOrEqual(blur.alpha, 0.20)
    }

    @MainActor
    func testPauseShowsCloseAndResumeContinuesExactCountdown() throws {
        let context = makeFocusContext()
        defer { context.cleanup() }
        context.service.play()
        context.service.setSleepTimer(.minutes15)
        layout(context.controller, size: CGSize(width: 375, height: 667))

        findButton(label: "暂停播放", in: context.controller.view)?
            .sendActions(for: .touchUpInside)
        XCTAssertFalse(context.service.isPlaying)
        XCTAssertEqual(context.controller.countdownTextForTesting, "15:00")
        XCTAssertNotNil(findButton(label: "继续播放", in: context.controller.view))
        XCTAssertNotNil(findButton(label: "关闭播放页", in: context.controller.view))

        findButton(label: "继续播放", in: context.controller.view)?
            .sendActions(for: .touchUpInside)
        XCTAssertTrue(context.service.isPlaying)
        XCTAssertEqual(context.controller.countdownTextForTesting, "15:00")
        XCTAssertNil(findButton(label: "关闭播放页", in: context.controller.view))
    }

    @MainActor
    func testUnlimitedAndExpiredCountdownCopy() {
        let context = makeFocusContext()
        defer { context.cleanup() }
        context.controller.loadViewIfNeeded()
        XCTAssertEqual(context.controller.countdownTextForTesting, "∞")

        context.service.play()
        context.controller.selectTimerForTesting(.minutes15)
        context.advanceNow(by: 900)
        context.service.reconcileSleepTimer()
        context.controller.refreshForTesting()

        XCTAssertEqual(context.controller.countdownTextForTesting, "00:00")
        XCTAssertFalse(context.service.isPlaying)
    }

    @MainActor
    func testExpiredCountdownAllowsPlaybackWithoutRestoringTimer() throws {
        let context = makeFocusContext()
        defer { context.cleanup() }
        context.service.play()
        context.controller.selectTimerForTesting(.minutes15)
        context.advanceNow(by: 900)
        context.service.reconcileSleepTimer()
        context.controller.refreshForTesting()

        let resumeButton = try XCTUnwrap(
            findButton(label: "继续播放", in: context.controller.view)
        )
        resumeButton.sendActions(for: .touchUpInside)

        XCTAssertTrue(context.service.isPlaying)
        XCTAssertEqual(context.service.sleepTimerPhase, .expired)
        XCTAssertEqual(context.controller.countdownTextForTesting, "00:00")
        XCTAssertNotNil(findButton(label: "关闭播放页", in: context.controller.view))
    }

    @MainActor
    func testLoadingRunningTimerOffscreenDoesNotStartDisplayTimer() {
        let context = makeFocusContext()
        defer { context.cleanup() }
        context.service.play()
        context.service.setSleepTimer(.minutes15)

        context.controller.loadViewIfNeeded()

        XCTAssertFalse(context.controller.hasDisplayTimerForTesting)
    }

    @MainActor
    func testPlayerNotificationAfterDisappearDoesNotRestartDisplayTimer() {
        let context = makeFocusContext()
        defer { context.cleanup() }
        context.service.play()
        context.service.setSleepTimer(.minutes15)
        context.controller.loadViewIfNeeded()
        context.controller.viewWillAppear(false)
        XCTAssertTrue(context.controller.hasDisplayTimerForTesting)

        context.controller.viewDidDisappear(false)
        XCTAssertFalse(context.controller.hasDisplayTimerForTesting)

        context.service.setSleepTimer(.minutes30)

        XCTAssertFalse(context.controller.hasDisplayTimerForTesting)
    }

    @MainActor
    func testAudioFailureShowsStatusRetryAndClose() throws {
        let context = makeFocusContext(
            resourceBundle: Bundle(for: FocusPlaybackViewControllerTests.self)
        )
        defer { context.cleanup() }
        context.service.play()
        layout(context.controller, size: CGSize(width: 390, height: 844))

        XCTAssertEqual(
            findLabel(identifier: "focusStatus", in: context.controller.view)?.text,
            "音频资源不可用"
        )
        XCTAssertNotNil(findButton(label: "重试播放", in: context.controller.view))
        XCTAssertNotNil(findButton(label: "关闭播放页", in: context.controller.view))
    }

    @MainActor
    func testCloseClearsTimerPausesAndCancelsScheduledNotification() throws {
        let context = makeFocusContext()
        defer { context.cleanup() }
        context.service.play()
        context.service.setSleepTimer(.minutes30)
        XCTAssertNotNil(context.scheduler.scheduledDate)
        layout(context.controller, size: CGSize(width: 390, height: 844))
        findButton(label: "暂停播放", in: context.controller.view)?
            .sendActions(for: .touchUpInside)
        XCTAssertNil(context.scheduler.scheduledDate)

        let closeButton = try XCTUnwrap(
            findButton(label: "关闭播放页", in: context.controller.view)
        )
        closeButton.sendActions(for: .touchUpInside)

        XCTAssertFalse(context.service.isPlaying)
        XCTAssertEqual(context.service.sleepTimerPhase, .unlimited)
        XCTAssertNil(context.scheduler.scheduledDate)
    }

    @MainActor
    func testRequiredControlsRemainInsideSafeAreaAtCompactAndLargeSizes() throws {
        let context = makeFocusContext()
        defer { context.cleanup() }

        for size in [CGSize(width: 375, height: 667), CGSize(width: 430, height: 932)] {
            layout(context.controller, size: size)
            let safeFrame = context.controller.view.safeAreaLayoutGuide.layoutFrame
            for identifier in [
                "focusSoundTitle",
                "focusSoundPicker",
                "focusCountdown",
                "focusPrimaryControl"
            ] {
                let control = try XCTUnwrap(
                    findView(identifier: identifier, in: context.controller.view)
                )
                XCTAssertTrue(
                    safeFrame.contains(control.frame),
                    "\(identifier) escaped safe area at \(size): \(control.frame)"
                )
            }
        }
    }

    @MainActor
    func testAccessibilityExtraExtraExtraLargeGroupsFitWithoutIntersection() throws {
        let context = makeFocusContext()
        defer { context.cleanup() }
        let host = UIViewController()
        host.loadViewIfNeeded()
        host.addChild(context.controller)
        host.view.addSubview(context.controller.view)
        context.controller.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            context.controller.view.topAnchor.constraint(equalTo: host.view.topAnchor),
            context.controller.view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            context.controller.view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            context.controller.view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor)
        ])
        context.controller.didMove(toParent: host)
        host.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            forChild: context.controller
        )
        layout(host, size: CGSize(width: 375, height: 667))

        let title = try XCTUnwrap(
            findView(identifier: "focusSoundTitle", in: context.controller.view)
        )
        let soundPicker = try XCTUnwrap(
            findView(identifier: "focusSoundPicker", in: context.controller.view)
        )
        let countdown = try XCTUnwrap(
            findView(identifier: "focusCountdown", in: context.controller.view)
        )
        let primaryControl = try XCTUnwrap(
            findView(identifier: "focusPrimaryControl", in: context.controller.view)
        )
        let safeFrame = context.controller.view.safeAreaLayoutGuide.layoutFrame
        let topFrame = title.frame.union(soundPicker.frame)
        let bottomFrame = countdown.frame.union(primaryControl.frame)

        XCTAssertTrue(safeFrame.contains(topFrame), "top group escaped safe area: \(topFrame)")
        XCTAssertTrue(safeFrame.contains(bottomFrame), "bottom group escaped safe area: \(bottomFrame)")
        XCTAssertLessThanOrEqual(topFrame.maxY, bottomFrame.minY)
    }

    @MainActor
    private func makeFocusContext(resourceBundle: Bundle = .main) -> FocusContext {
        let suite = "FocusPlaybackViewControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let clock = MutableClock(now: Date(timeIntervalSince1970: 1_000))
        let scheduler = FocusPlaybackEndNotificationSchedulerSpy()
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false,
            resourceBundle: resourceBundle,
            nowProvider: { clock.now },
            notificationScheduler: scheduler
        )
        let store = RecentSoundsStore(defaults: defaults)
        let controller = FocusPlaybackViewController(
            playerService: service,
            onSelectSound: { index in
                service.selectAndPlay(at: index)
                store.record(Sound.catalog[index])
            }
        )
        return FocusContext(
            service: service,
            store: store,
            scheduler: scheduler,
            controller: controller,
            clock: clock,
            cleanup: {
                service.clearSleepTimer()
                service.pause()
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
    private func findLabel(identifier: String, in root: UIView) -> UILabel? {
        descendants(in: root)
            .compactMap { $0 as? UILabel }
            .first { $0.accessibilityIdentifier == identifier }
    }

    @MainActor
    private func matchingLabelTexts(identifier: String, in root: UIView) -> [String] {
        descendants(in: root)
            .compactMap { $0 as? UILabel }
            .filter { $0.accessibilityIdentifier == identifier }
            .compactMap(\.text)
    }

    @MainActor
    private func findButton(label: String, in root: UIView) -> UIButton? {
        descendants(in: root)
            .compactMap { $0 as? UIButton }
            .first { $0.accessibilityLabel == label && !$0.isHidden }
    }

    @MainActor
    private func findView(identifier: String, in root: UIView) -> UIView? {
        descendants(in: root).first { $0.accessibilityIdentifier == identifier }
    }

    @MainActor
    private func descendants(in root: UIView) -> [UIView] {
        [root] + root.subviews.flatMap(descendants(in:))
    }
}

@MainActor
private final class MutableClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

@MainActor
private final class FocusPlaybackEndNotificationSchedulerSpy:
    PlaybackEndNotificationScheduling {
    private(set) var authorizationRequestCount = 0
    private(set) var scheduledDate: Date?

    func requestAuthorization() {
        authorizationRequestCount += 1
    }

    func schedulePlaybackEnd(at deadline: Date) {
        scheduledDate = deadline
    }

    func cancelPlaybackEnd() {
        scheduledDate = nil
    }
}

@MainActor
private struct FocusContext {
    let service: AudioPlayerService
    let store: RecentSoundsStore
    let scheduler: FocusPlaybackEndNotificationSchedulerSpy
    let controller: FocusPlaybackViewController
    let clock: MutableClock
    let cleanup: () -> Void

    func advanceNow(by interval: TimeInterval) {
        clock.now = clock.now.addingTimeInterval(interval)
    }
}
