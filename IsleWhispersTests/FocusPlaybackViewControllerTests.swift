import ObjectiveC
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
            context.service.currentSound.title(bundle: context.localizationBundle)
        )
        let countdownButton = try XCTUnwrap(
            findView(identifier: "focusCountdown", in: context.controller.view) as? UIButton
        )
        XCTAssertEqual(countdownButton.currentTitle, "15:00")
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
        let countdownButton = findView(
            identifier: "focusCountdown",
            in: context.controller.view
        ) as? UIButton
        XCTAssertEqual(countdownButton?.currentTitle, "∞")
        XCTAssertEqual(countdownButton?.accessibilityValue, "不限时")

        context.service.play()
        context.controller.selectTimerForTesting(.minutes15)
        context.advanceNow(by: 900)
        context.service.reconcileSleepTimer()
        context.controller.refreshForTesting()

        XCTAssertEqual(countdownButton?.currentTitle, "00:00")
        XCTAssertEqual(countdownButton?.accessibilityValue, "倒计时已结束")
        XCTAssertFalse(context.service.isPlaying)
    }

    @MainActor
    func testCountdownKeepsVisualClockAndUsesEnglishVoiceOverDuration() throws {
        let context = makeFocusContext(
            localizationBundle: try LocalizationTestSupport.bundle("en")
        )
        defer { context.cleanup() }
        context.service.play()
        context.service.setSleepTimer(.minutes15)
        context.controller.loadViewIfNeeded()
        let countdownButton = try XCTUnwrap(
            findView(identifier: "focusCountdown", in: context.controller.view) as? UIButton
        )

        XCTAssertEqual(countdownButton.currentTitle, "15:00")
        XCTAssertEqual(countdownButton.accessibilityValue, "Remaining: 15 minutes")

        context.advanceNow(by: 840)
        context.controller.refreshForTesting()

        XCTAssertEqual(countdownButton.currentTitle, "01:00")
        XCTAssertEqual(countdownButton.accessibilityValue, "Remaining: 1 minute")

        context.advanceNow(by: 51)
        context.controller.refreshForTesting()

        XCTAssertEqual(countdownButton.currentTitle, "00:09")
        XCTAssertEqual(countdownButton.accessibilityValue, "Remaining: 9 seconds")

        context.advanceNow(by: 8)
        context.controller.refreshForTesting()

        XCTAssertEqual(countdownButton.currentTitle, "00:01")
        XCTAssertEqual(countdownButton.accessibilityValue, "Remaining: 1 second")
    }

    @MainActor
    func testCountdownUsesSimplifiedChineseVoiceOverDuration() throws {
        let context = makeFocusContext(
            localizationBundle: try LocalizationTestSupport.bundle("zh-Hans")
        )
        defer { context.cleanup() }
        context.service.play()
        context.service.setSleepTimer(.minutes15)
        context.controller.loadViewIfNeeded()
        let countdownButton = try XCTUnwrap(
            findView(identifier: "focusCountdown", in: context.controller.view) as? UIButton
        )

        XCTAssertEqual(countdownButton.currentTitle, "15:00")
        XCTAssertEqual(countdownButton.accessibilityValue, "剩余 15 分钟")

        context.advanceNow(by: 899)
        context.controller.refreshForTesting()

        XCTAssertEqual(countdownButton.currentTitle, "00:01")
        XCTAssertEqual(countdownButton.accessibilityValue, "剩余 1 秒")
    }

    @MainActor
    func testCountdownUsesTraditionalChineseVoiceOverDuration() throws {
        let context = makeFocusContext(
            localizationBundle: try LocalizationTestSupport.bundle("zh-Hant")
        )
        defer { context.cleanup() }
        context.service.play()
        context.service.setSleepTimer(.minutes15)
        context.controller.loadViewIfNeeded()
        let countdownButton = try XCTUnwrap(
            findView(identifier: "focusCountdown", in: context.controller.view) as? UIButton
        )

        XCTAssertEqual(countdownButton.currentTitle, "15:00")
        XCTAssertEqual(countdownButton.accessibilityValue, "剩餘 15 分鐘")

        context.advanceNow(by: 899)
        context.controller.refreshForTesting()

        XCTAssertEqual(countdownButton.currentTitle, "00:01")
        XCTAssertEqual(countdownButton.accessibilityValue, "剩餘 1 秒")
    }

    @MainActor
    func testTimerSheetAndPlaybackActionsUseInjectedLanguageBundle() throws {
        let cases = [
            FocusLocalizationExpectation(
                language: "en",
                sound: "Rain",
                currentSoundLabel: "Change sound. Current: Rain",
                switchSoundHint: "Open sound selection",
                countdown: "Set Timer",
                unlimited: "No Limit",
                ended: "Timer Ended",
                play: "Resume Playback",
                pause: "Pause Playback",
                close: "Close Player",
                retry: "Retry Playback",
                retryTitle: "Retry",
                sheetTitle: "Set Timer",
                options: ["No Limit", "15 Minutes", "30 Minutes", "60 Minutes", "Cancel"],
                libraryTitle: "Sound Library"
            ),
            FocusLocalizationExpectation(
                language: "zh-Hans",
                sound: "雨声",
                currentSoundLabel: "切换声音，当前雨声",
                switchSoundHint: "打开声音选择",
                countdown: "设置倒计时",
                unlimited: "不限时",
                ended: "倒计时已结束",
                play: "继续播放",
                pause: "暂停播放",
                close: "关闭播放页",
                retry: "重试播放",
                retryTitle: "重试",
                sheetTitle: "设置倒计时",
                options: ["不限时", "15 分钟", "30 分钟", "60 分钟", "取消"],
                libraryTitle: "声音库"
            ),
            FocusLocalizationExpectation(
                language: "zh-Hant",
                sound: "雨聲",
                currentSoundLabel: "切換聲音，目前為 雨聲",
                switchSoundHint: "開啟聲音選擇",
                countdown: "設定倒數計時",
                unlimited: "不限時",
                ended: "倒數計時已結束",
                play: "繼續播放",
                pause: "暫停播放",
                close: "關閉播放頁",
                retry: "重試播放",
                retryTitle: "重試",
                sheetTitle: "設定倒數計時",
                options: ["不限時", "15 分鐘", "30 分鐘", "60 分鐘", "取消"],
                libraryTitle: "聲音庫"
            )
        ]

        for expectation in cases {
            let bundle = try LocalizationTestSupport.bundle(expectation.language)
            let context = makeFocusContext(
                localizationBundle: bundle,
                serviceLocalizationBundle: try LocalizationTestSupport.bundle("en")
            )
            defer { context.cleanup() }
            let window = UIWindow(
                frame: CGRect(origin: .zero, size: CGSize(width: 390, height: 844))
            )
            window.rootViewController = context.controller
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            layout(context.controller, size: window.bounds.size)

            let soundPicker = try XCTUnwrap(
                findView(identifier: "focusSoundPicker", in: context.controller.view) as? UIButton
            )
            let countdown = try XCTUnwrap(
                findView(identifier: "focusCountdown", in: context.controller.view) as? UIButton
            )
            let primary = try XCTUnwrap(
                findView(identifier: "focusPrimaryControl", in: context.controller.view) as? UIButton
            )

            XCTAssertEqual(
                findLabel(identifier: "focusSoundTitle", in: context.controller.view)?.text,
                expectation.sound
            )
            XCTAssertEqual(soundPicker.accessibilityLabel, expectation.currentSoundLabel)
            XCTAssertEqual(soundPicker.accessibilityHint, expectation.switchSoundHint)
            XCTAssertEqual(countdown.accessibilityLabel, expectation.countdown)
            XCTAssertEqual(countdown.accessibilityValue, expectation.unlimited)
            XCTAssertEqual(primary.accessibilityLabel, expectation.play)
            XCTAssertNotNil(findAnyButton(label: expectation.close, in: context.controller.view))
            let retry = try XCTUnwrap(
                findAnyButton(label: expectation.retry, in: context.controller.view)
            )
            XCTAssertEqual(retry.currentTitle, expectation.retryTitle)
            XCTAssertTrue(
                findView(identifier: "focusStatus", in: context.controller.view)?.isHidden == true
            )

            primary.sendActions(for: .touchUpInside)
            XCTAssertEqual(primary.accessibilityLabel, expectation.pause)

            countdown.sendActions(for: .touchUpInside)
            let sheet = try XCTUnwrap(
                context.controller.presentedViewController as? UIAlertController
            )
            XCTAssertEqual(sheet.title, expectation.sheetTitle)
            XCTAssertEqual(sheet.actions.compactMap(\.title), expectation.options)
            sheet.dismiss(animated: false)
            XCTAssertTrue(waitForDismissal(of: context.controller))

            context.service.setSleepTimer(.minutes15)
            context.advanceNow(by: 900)
            context.service.reconcileSleepTimer()
            context.controller.refreshForTesting()
            XCTAssertEqual(countdown.accessibilityValue, expectation.ended)

            soundPicker.sendActions(for: .touchUpInside)
            let navigation = try XCTUnwrap(
                context.controller.presentedViewController as? UINavigationController
            )
            let library = try XCTUnwrap(
                navigation.viewControllers.first as? SoundLibraryViewController
            )
            library.loadViewIfNeeded()
            XCTAssertNotNil(findLabel(text: expectation.libraryTitle, in: library.view))
            navigation.dismiss(animated: false)
        }
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
    func testAudioFailureShowsLocalizedStatusRetryAndClose() throws {
        let cases = [
            ("en", "Audio Unavailable", "Retry Playback", "Close Player"),
            ("zh-Hans", "音频资源不可用", "重试播放", "关闭播放页"),
            ("zh-Hant", "音訊資源無法使用", "重試播放", "關閉播放頁")
        ]

        for (language, status, retry, close) in cases {
            let context = makeFocusContext(
                resourceBundle: Bundle(for: FocusPlaybackViewControllerTests.self),
                localizationBundle: try LocalizationTestSupport.bundle(language),
                serviceLocalizationBundle: try LocalizationTestSupport.bundle("en")
            )
            defer { context.cleanup() }
            context.service.play()
            layout(context.controller, size: CGSize(width: 390, height: 844))

            XCTAssertEqual(
                findLabel(identifier: "focusStatus", in: context.controller.view)?.text,
                status
            )
            XCTAssertNotNil(findButton(label: retry, in: context.controller.view))
            XCTAssertNotNil(findButton(label: close, in: context.controller.view))
        }
    }

    @MainActor
    func testSoundPickerSelectionAutoplaysRecordsPreservesTimerAndDismissesSheet() throws {
        let context = makeFocusContext()
        defer { context.cleanup() }
        context.service.play()
        context.service.setSleepTimer(.minutes15)
        context.advanceNow(by: 100.25)
        context.service.pause()
        XCTAssertEqual(
            try XCTUnwrap(context.service.sleepTimerRemaining),
            799.75,
            accuracy: 0.001
        )
        XCTAssertNil(context.scheduler.scheduledDate)
        XCTAssertEqual(context.scheduler.scheduledDates, [Date(timeIntervalSince1970: 1_900)])
        context.advanceNow(by: 899.75)
        let window = UIWindow(frame: CGRect(origin: .zero, size: CGSize(width: 390, height: 844)))
        window.rootViewController = context.controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        layout(context.controller, size: window.bounds.size)

        let switchButton = try XCTUnwrap(
            findButton(labelPrefix: "切换声音", in: context.controller.view)
        )
        switchButton.sendActions(for: .touchUpInside)
        let navigation = try XCTUnwrap(
            context.controller.presentedViewController as? UINavigationController
        )
        let library = try XCTUnwrap(
            navigation.viewControllers.first as? SoundLibraryViewController
        )
        library.selectItemForTesting(section: 1, item: 2)

        XCTAssertEqual(context.service.currentSound.title(bundle: context.localizationBundle), "游艇")
        XCTAssertTrue(context.service.isPlaying)
        XCTAssertEqual(context.store.recentSounds.first?.id, context.service.currentSound.id)
        XCTAssertEqual(context.service.sleepTimerOption, .minutes15)
        XCTAssertEqual(
            try XCTUnwrap(context.service.sleepTimerRemaining),
            799.75,
            accuracy: 0.001
        )
        XCTAssertEqual(
            context.scheduler.scheduledDate,
            Date(timeIntervalSince1970: 2_799.75)
        )
        XCTAssertEqual(
            context.scheduler.scheduledDates,
            [
                Date(timeIntervalSince1970: 1_900),
                Date(timeIntervalSince1970: 2_799.75)
            ]
        )
        XCTAssertTrue(waitForDismissal(of: context.controller))
    }

    @MainActor
    func testRapidSoundPickerTapsKeepOnlyFirstPresentedLibrary() throws {
        let context = makeFocusContext()
        defer { context.cleanup() }
        let window = UIWindow(frame: CGRect(origin: .zero, size: CGSize(width: 390, height: 844)))
        window.rootViewController = context.controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        layout(context.controller, size: window.bounds.size)
        let switchButton = try XCTUnwrap(
            findButton(labelPrefix: "切换声音", in: context.controller.view)
        )
        PresentationCallTracker.start(target: context.controller)
        defer { PresentationCallTracker.stop() }

        switchButton.sendActions(for: .touchUpInside)
        let firstNavigation = try XCTUnwrap(
            context.controller.presentedViewController as? UINavigationController
        )
        switchButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(PresentationCallTracker.callCount, 1)
        XCTAssertTrue(context.controller.presentedViewController === firstNavigation)
    }

    @MainActor
    func testCloseClearsTimerPausesDismissesAndKeepsSelectedSound() throws {
        let context = makeFocusContext()
        defer { context.cleanup() }
        context.service.next()
        context.service.play()
        context.service.setSleepTimer(.minutes30)
        let selectedIndex = context.service.selectedIndex
        XCTAssertNotNil(context.scheduler.scheduledDate)
        let host = UIViewController()
        let window = UIWindow(frame: CGRect(origin: .zero, size: CGSize(width: 390, height: 844)))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.present(context.controller, animated: false)
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
        XCTAssertEqual(context.service.sleepTimerOption, .unlimited)
        XCTAssertNil(context.scheduler.scheduledDate)
        XCTAssertEqual(context.service.selectedIndex, selectedIndex)
        XCTAssertTrue(waitForDismissal(of: host))
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
    func testEnglishFocusControlsFitAt320By568AndMaximumAccessibilityText() throws {
        try assertFocusLayout(language: "en", size: CGSize(width: 320, height: 568))
    }

    @MainActor
    func testAllLanguagesFocusControlsFitAt390By844AndMaximumAccessibilityText() throws {
        for language in ["en", "zh-Hans", "zh-Hant"] {
            for size in [CGSize(width: 320, height: 568), CGSize(width: 390, height: 844)] {
                try assertFocusLayout(language: language, size: size)
            }
        }
    }

    @MainActor
    private func makeFocusContext(
        resourceBundle: Bundle = .main,
        localizationBundle: Bundle = try! LocalizationTestSupport.bundle("zh-Hans"),
        serviceLocalizationBundle: Bundle? = nil
    ) -> FocusContext {
        let suite = "FocusPlaybackViewControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let clock = MutableClock(now: Date(timeIntervalSince1970: 1_000))
        let scheduler = FocusPlaybackEndNotificationSchedulerSpy()
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false,
            resourceBundle: resourceBundle,
            localizationBundle: serviceLocalizationBundle ?? localizationBundle,
            nowProvider: { clock.now },
            notificationScheduler: scheduler
        )
        let store = RecentSoundsStore(defaults: defaults)
        let controller = FocusPlaybackViewController(
            playerService: service,
            localizationBundle: localizationBundle,
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
            localizationBundle: localizationBundle,
            clock: clock,
            cleanup: {
                service.clearSleepTimer()
                service.pause()
                defaults.removePersistentDomain(forName: suite)
            }
        )
    }

    @MainActor
    private func assertFocusLayout(language: String, size: CGSize) throws {
        let context = makeFocusContext(
            resourceBundle: Bundle(for: FocusPlaybackViewControllerTests.self),
            localizationBundle: try LocalizationTestSupport.bundle(language)
        )
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
        layout(host, size: size)

        let identifiers = [
            "focusSoundTitle",
            "focusSoundPicker",
            "focusStatus",
            "focusRetry",
            "focusCountdown",
            "focusPrimaryControl",
            "focusClose"
        ]
        let scrollView = try XCTUnwrap(
            findSubview(UIScrollView.self, in: context.controller.view)
        )
        let visibleFrames = try identifiers.compactMap { identifier -> CGRect? in
            let view = try XCTUnwrap(findView(identifier: identifier, in: context.controller.view))
            guard !view.isHidden else { return nil }
            return view.convert(view.bounds, to: scrollView)
        }

        for (index, frame) in visibleFrames.enumerated() {
            for otherFrame in visibleFrames.dropFirst(index + 1) {
                XCTAssertFalse(
                    frame.intersects(otherFrame),
                    "\(language) controls intersect at \(size): \(frame), \(otherFrame)"
                )
            }
        }
        XCTAssertTrue(scrollView.alwaysBounceVertical)
        XCTAssertGreaterThanOrEqual(scrollView.contentSize.height, scrollView.bounds.height)
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
    private func findButton(label: String, in root: UIView) -> UIButton? {
        descendants(in: root)
            .compactMap { $0 as? UIButton }
            .first { $0.accessibilityLabel == label && !$0.isHidden }
    }

    @MainActor
    private func findButton(labelPrefix: String, in root: UIView) -> UIButton? {
        descendants(in: root)
            .compactMap { $0 as? UIButton }
            .first { $0.accessibilityLabel?.hasPrefix(labelPrefix) == true && !$0.isHidden }
    }

    @MainActor
    private func findAnyButton(label: String, in root: UIView) -> UIButton? {
        descendants(in: root)
            .compactMap { $0 as? UIButton }
            .first { $0.accessibilityLabel == label }
    }

    @MainActor
    private func findLabel(text: String, in root: UIView) -> UILabel? {
        descendants(in: root)
            .compactMap { $0 as? UILabel }
            .first { $0.text == text }
    }

    @MainActor
    private func findView(identifier: String, in root: UIView) -> UIView? {
        descendants(in: root).first { $0.accessibilityIdentifier == identifier }
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
    private(set) var scheduledDates: [Date] = []

    func requestAuthorization() {
        authorizationRequestCount += 1
    }

    func schedulePlaybackEnd(at deadline: Date) {
        scheduledDate = deadline
        scheduledDates.append(deadline)
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
    let localizationBundle: Bundle
    let clock: MutableClock
    let cleanup: () -> Void

    func advanceNow(by interval: TimeInterval) {
        clock.now = clock.now.addingTimeInterval(interval)
    }
}

private struct FocusLocalizationExpectation {
    let language: String
    let sound: String
    let currentSoundLabel: String
    let switchSoundHint: String
    let countdown: String
    let unlimited: String
    let ended: String
    let play: String
    let pause: String
    let close: String
    let retry: String
    let retryTitle: String
    let sheetTitle: String
    let options: [String]
    let libraryTitle: String
}

@MainActor
private enum PresentationCallTracker {
    static weak var target: UIViewController?
    static var callCount = 0

    static func start(target: UIViewController) {
        self.target = target
        callCount = 0
        exchangePresentImplementations()
    }

    static func stop() {
        exchangePresentImplementations()
        target = nil
        callCount = 0
    }

    static func recordPresentation(from controller: UIViewController) {
        guard controller === target else { return }
        callCount += 1
    }

    private static func exchangePresentImplementations() {
        let original = class_getInstanceMethod(
            UIViewController.self,
            #selector(UIViewController.present(_:animated:completion:))
        )
        let tracked = class_getInstanceMethod(
            UIViewController.self,
            #selector(UIViewController.task4_present(_:animated:completion:))
        )
        guard let original, let tracked else { return }
        method_exchangeImplementations(original, tracked)
    }
}

extension UIViewController {
    @objc fileprivate func task4_present(
        _ viewControllerToPresent: UIViewController,
        animated flag: Bool,
        completion: (() -> Void)? = nil
    ) {
        PresentationCallTracker.recordPresentation(from: self)
        task4_present(
            viewControllerToPresent,
            animated: flag,
            completion: completion
        )
    }
}
