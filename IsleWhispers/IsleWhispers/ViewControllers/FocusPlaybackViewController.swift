import SnapKit
import UIKit

final class FocusPlaybackViewController: UIViewController {
    private static let normalOverlayAlpha: CGFloat = 0.24
    private static let highContrastOverlayAlpha: CGFloat = 0.38
    private static let minimumAccessibilityScrollOverflow: CGFloat = 24

    private let playerService: AudioPlayerService
    private let localizationBundle: Bundle
    private let onSelectSound: (Int) -> Void
    private let backgroundImageView = UIImageView()
    private let blurView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemUltraThinMaterialDark)
    )
    private let overlayView = UIView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let soundPickerButton = UIButton(type: .system)
    private let countdownButton = UIButton(type: .system)
    private let primaryControlButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let statusStack = UIStackView()
    private var minimumContentHeightConstraint: Constraint?
    private var displayTimer: Timer?
    private var displayedBackgroundResource: String?
    private var isVisible = false

    init(
        playerService: AudioPlayerService,
        localizationBundle: Bundle = .main,
        onSelectSound: @escaping (Int) -> Void
    ) {
        self.playerService = playerService
        self.localizationBundle = localizationBundle
        self.onSelectSound = onSelectSound
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        displayTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        setupBackground()
        setupTopControls()
        setupBottomControls()
        setupLayout()
        setupInteractions()
        observePlayerState()
        updateContrastAppearance()
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isVisible = true
        render()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isVisible = false
        invalidateDisplayTimer()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.accessibilityContrast != traitCollection.accessibilityContrast {
            updateContrastAppearance()
        }
        if previousTraitCollection?.preferredContentSizeCategory
            != traitCollection.preferredContentSizeCategory {
            updateMinimumContentHeight()
        }
    }

    var countdownTextForTesting: String {
        countdownText()
    }

    var hasDisplayTimerForTesting: Bool {
        displayTimer != nil
    }

    func refreshForTesting() {
        render()
    }

    func selectTimerForTesting(_ option: SleepTimerOption) {
        selectTimer(option)
    }

    private func setupBackground() {
        view.backgroundColor = AppTheme.tabBarBackground

        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        backgroundImageView.isAccessibilityElement = false
        backgroundImageView.isUserInteractionEnabled = false

        blurView.alpha = 0.14
        blurView.isAccessibilityElement = false
        blurView.isUserInteractionEnabled = false

        overlayView.backgroundColor = .black
        overlayView.isAccessibilityElement = false
        overlayView.isUserInteractionEnabled = false

        [backgroundImageView, blurView, overlayView].forEach(view.addSubview)
    }

    private func setupTopControls() {
        titleLabel.font = AppTheme.font(.title1, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityIdentifier = "focusSoundTitle"

        configureCircularButton(soundPickerButton, diameter: 56)
        soundPickerButton.setImage(
            UIImage(
                systemName: "music.note.list",
                withConfiguration: AppTheme.symbolConfiguration(
                    pointSize: 19,
                    weight: .semibold
                )
            ),
            for: .normal
        )
        soundPickerButton.accessibilityLabel = L10n.text(
            "focus.sound_picker.label",
            bundle: localizationBundle
        )
        soundPickerButton.accessibilityHint = L10n.text(
            "focus.sound_picker.hint",
            bundle: localizationBundle
        )
        soundPickerButton.accessibilityIdentifier = "focusSoundPicker"
    }

    private func setupBottomControls() {
        countdownButton.setTitle("∞", for: .normal)
        countdownButton.setTitleColor(.white, for: .normal)
        countdownButton.titleLabel?.font = AppTheme.font(.largeTitle, weight: .regular)
        countdownButton.titleLabel?.adjustsFontForContentSizeCategory = true
        countdownButton.titleLabel?.accessibilityIdentifier = "focusCountdown"
        countdownButton.accessibilityIdentifier = "focusCountdown"
        countdownButton.accessibilityLabel = L10n.text(
            "focus.countdown.label",
            bundle: localizationBundle
        )
        countdownButton.contentHorizontalAlignment = .center

        configureCircularButton(primaryControlButton, diameter: 72)
        primaryControlButton.backgroundColor = AppTheme.accent
        primaryControlButton.tintColor = AppTheme.accentForeground
        primaryControlButton.accessibilityIdentifier = "focusPrimaryControl"

        configureCircularButton(closeButton, diameter: 56)
        closeButton.setImage(
            UIImage(
                systemName: "xmark",
                withConfiguration: AppTheme.symbolConfiguration(
                    pointSize: 18,
                    weight: .bold
                )
            ),
            for: .normal
        )
        closeButton.accessibilityLabel = L10n.text("focus.close", bundle: localizationBundle)
        closeButton.accessibilityIdentifier = "focusClose"

        statusLabel.font = AppTheme.font(.footnote, weight: .semibold)
        statusLabel.textColor = UIColor.systemRed.withAlphaComponent(0.96)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.accessibilityIdentifier = "focusStatus"
        statusLabel.accessibilityTraits = .updatesFrequently

        retryButton.setTitle(
            L10n.text("common.retry", bundle: localizationBundle),
            for: .normal
        )
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.titleLabel?.font = AppTheme.font(.footnote, weight: .semibold)
        retryButton.titleLabel?.adjustsFontForContentSizeCategory = true
        retryButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.82)
        retryButton.applyRoundedCorners(radius: 20)
        retryButton.accessibilityLabel = L10n.text(
            "focus.retry.label",
            bundle: localizationBundle
        )
        retryButton.accessibilityHint = L10n.text(
            "home.retry.hint",
            bundle: localizationBundle
        )
        retryButton.accessibilityIdentifier = "focusRetry"

        statusStack.axis = .vertical
        statusStack.alignment = .center
        statusStack.spacing = 8
        statusStack.addArrangedSubview(statusLabel)
        statusStack.addArrangedSubview(retryButton)

        [soundPickerButton, countdownButton, primaryControlButton, closeButton, retryButton]
            .forEach { $0.titleLabel?.adjustsFontForContentSizeCategory = true }
    }

    private func configureCircularButton(_ button: UIButton, diameter: CGFloat) {
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        button.applyRoundedCorners(radius: diameter / 2)
        button.snp.makeConstraints { make in
            make.size.equalTo(diameter)
        }
    }

    private func setupLayout() {
        [backgroundImageView, blurView, overlayView].forEach { backgroundView in
            backgroundView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        [titleLabel, soundPickerButton, statusStack, countdownButton, primaryControlButton, closeButton]
            .forEach(contentView.addSubview)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
            minimumContentHeightConstraint = make.height
                .greaterThanOrEqualTo(scrollView.frameLayoutGuide)
                .offset(contentHeightOverflow)
                .constraint
        }

        soundPickerButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().inset(20)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalToSuperview().inset(20)
            make.trailing.lessThanOrEqualTo(soundPickerButton.snp.leading).offset(-12)
        }

        primaryControlButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().inset(20)
        }
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(20)
            make.centerY.equalTo(primaryControlButton)
        }
        countdownButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalTo(primaryControlButton.snp.top).offset(-16)
            make.height.greaterThanOrEqualTo(64)
        }
        statusStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.greaterThanOrEqualTo(titleLabel.snp.bottom).offset(24)
            make.top.greaterThanOrEqualTo(soundPickerButton.snp.bottom).offset(24)
            make.bottom.equalTo(countdownButton.snp.top).offset(-12)
        }
        retryButton.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(56)
            make.width.greaterThanOrEqualTo(96)
        }
    }

    private var contentHeightOverflow: CGFloat {
        traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            ? Self.minimumAccessibilityScrollOverflow
            : 0
    }

    private func updateMinimumContentHeight() {
        minimumContentHeightConstraint?.update(offset: contentHeightOverflow)
    }

    private func setupInteractions() {
        soundPickerButton.addTarget(
            self,
            action: #selector(didTapSoundPicker),
            for: .touchUpInside
        )
        countdownButton.addTarget(
            self,
            action: #selector(didTapCountdown),
            for: .touchUpInside
        )
        primaryControlButton.addTarget(
            self,
            action: #selector(didTapPrimaryControl),
            for: .touchUpInside
        )
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        retryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)
    }

    private func observePlayerState() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlayerStateDidChange),
            name: .audioPlayerStateDidChange,
            object: playerService
        )
    }

    private func countdownText() -> String {
        guard let remaining = playerService.sleepTimerRemaining else { return "∞" }
        let total = Int(ceil(max(remaining, 0)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func render() {
        let sound = playerService.currentSound
        let soundTitle = sound.title(bundle: localizationBundle)
        titleLabel.text = soundTitle
        soundPickerButton.accessibilityLabel = L10n.format(
            "focus.sound_picker.current.format",
            bundle: localizationBundle,
            soundTitle
        )
        updateBackground(for: sound)
        updateCountdownPresentation()

        let playing = playerService.isPlaying
        let hasError = playerService.status != .ready
        primaryControlButton.accessibilityLabel = L10n.text(
            playing ? "focus.pause" : "focus.play",
            bundle: localizationBundle
        )
        primaryControlButton.setImage(
            UIImage(
                systemName: playing ? "pause.fill" : "play.fill",
                withConfiguration: AppTheme.symbolConfiguration(
                    pointSize: 26,
                    weight: .bold
                )
            ),
            for: .normal
        )
        let shouldShowClose = !playing || hasError || playerService.sleepTimerPhase == .expired
        closeButton.isHidden = !shouldShowClose
        closeButton.accessibilityElementsHidden = !shouldShowClose

        statusLabel.text = hasError
            ? L10n.text(playerService.status.localizationKey, bundle: localizationBundle)
            : nil
        statusStack.isHidden = !hasError
        statusLabel.isHidden = !hasError
        retryButton.isHidden = !hasError
        updateDisplayTimer()
    }

    private func updateCountdownPresentation() {
        let text = countdownText()
        countdownButton.setTitle(text, for: .normal)
        countdownButton.titleLabel?.accessibilityIdentifier = "focusCountdown"
        switch playerService.sleepTimerPhase {
        case .unlimited:
            countdownButton.accessibilityValue = L10n.text(
                "focus.countdown.unlimited",
                bundle: localizationBundle
            )
        case .running, .paused:
            countdownButton.accessibilityValue = L10n.format(
                "focus.countdown.remaining.format",
                bundle: localizationBundle,
                countdownAccessibilityDuration()
            )
        case .expired:
            countdownButton.accessibilityValue = L10n.text(
                "focus.countdown.ended",
                bundle: localizationBundle
            )
        }
    }

    private func countdownAccessibilityDuration() -> String {
        let seconds = max(Int(ceil(playerService.sleepTimerRemaining ?? 0)), 0)
        let minutes = seconds / 60
        let remainder = seconds % 60
        if remainder == 0 {
            return L10n.plural(
                "timer.duration.minutes",
                count: minutes,
                bundle: localizationBundle
            )
        }
        if minutes == 0 {
            return L10n.plural(
                "timer.duration.seconds",
                count: remainder,
                bundle: localizationBundle
            )
        }
        return L10n.format(
            "timer.duration.minutes_seconds.format",
            bundle: localizationBundle,
            minutes,
            remainder
        )
    }

    private func updateBackground(for sound: Sound) {
        guard displayedBackgroundResource != sound.backgroundResource else { return }
        displayedBackgroundResource = sound.backgroundResource
        let image = SoundArtwork.image(for: sound)
        guard !UIAccessibility.isReduceMotionEnabled else {
            backgroundImageView.image = image
            return
        }
        UIView.transition(
            with: backgroundImageView,
            duration: 0.20,
            options: [.transitionCrossDissolve, .allowAnimatedContent]
        ) {
            self.backgroundImageView.image = image
        }
    }

    private func updateContrastAppearance() {
        overlayView.alpha = traitCollection.accessibilityContrast == .high
            ? Self.highContrastOverlayAlpha
            : Self.normalOverlayAlpha
    }

    private func updateDisplayTimer() {
        guard isVisible, case .running = playerService.sleepTimerPhase else {
            invalidateDisplayTimer()
            return
        }
        guard displayTimer == nil else { return }
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] _ in
            self?.updateCountdownPresentation()
        }
        displayTimer?.tolerance = 0.10
    }

    private func invalidateDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func selectTimer(_ option: SleepTimerOption) {
        playerService.setSleepTimer(option)
        render()
    }

    @objc private func didTapSoundPicker() {
        guard presentedViewController == nil else { return }
        let library = SoundLibraryViewController(
            selectedSoundID: playerService.currentSound.id,
            localizationBundle: localizationBundle
        )
        let navigation = UINavigationController(rootViewController: library)
        library.navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak navigation] _ in
                navigation?.dismiss(animated: true)
            }
        )
        library.onSelect = { [weak self, weak navigation] index in
            self?.onSelectSound(index)
            navigation?.dismiss(animated: true)
        }
        navigation.modalPresentationStyle = .pageSheet
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(navigation, animated: true)
    }

    @objc private func didTapCountdown() {
        let sheet = UIAlertController(
            title: L10n.text("focus.timer.sheet.title", bundle: localizationBundle),
            message: nil,
            preferredStyle: .actionSheet
        )
        [
            (L10n.text("timer.option.unlimited", bundle: localizationBundle), SleepTimerOption.unlimited),
            (L10n.text("timer.option.minutes15", bundle: localizationBundle), .minutes15),
            (L10n.text("timer.option.minutes30", bundle: localizationBundle), .minutes30),
            (L10n.text("timer.option.minutes60", bundle: localizationBundle), .minutes60)
        ].forEach { title, option in
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.selectTimer(option)
            })
        }
        sheet.addAction(
            UIAlertAction(
                title: L10n.text("common.cancel", bundle: localizationBundle),
                style: .cancel
            )
        )
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = countdownButton
            popover.sourceRect = countdownButton.bounds
        }
        present(sheet, animated: true)
    }

    @objc private func didTapPrimaryControl() {
        playerService.isPlaying ? playerService.pause() : playerService.play()
    }

    @objc private func didTapClose() {
        playerService.clearSleepTimer()
        playerService.pause()
        dismiss(animated: true)
    }

    @objc private func didTapRetry() {
        playerService.retry()
        playerService.play()
    }

    @objc private func handlePlayerStateDidChange() {
        render()
    }
}
