import SnapKit
import UIKit

final class FocusPlaybackViewController: UIViewController {
    private static let readyStatus = "准备就绪"
    private static let normalOverlayAlpha: CGFloat = 0.24
    private static let highContrastOverlayAlpha: CGFloat = 0.38

    private let playerService: AudioPlayerService
    private let onSelectSound: (Int) -> Void
    private let backgroundImageView = UIImageView()
    private let blurView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemUltraThinMaterialDark)
    )
    private let overlayView = UIView()
    private let titleLabel = UILabel()
    private let soundPickerButton = UIButton(type: .system)
    private let countdownButton = UIButton(type: .system)
    private let primaryControlButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let statusStack = UIStackView()
    private var displayTimer: Timer?
    private var displayedBackgroundResource: String?
    private var isVisible = false

    init(playerService: AudioPlayerService, onSelectSound: @escaping (Int) -> Void) {
        self.playerService = playerService
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
        guard previousTraitCollection?.accessibilityContrast != traitCollection.accessibilityContrast
        else { return }
        updateContrastAppearance()
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
        soundPickerButton.accessibilityLabel = "切换声音"
        soundPickerButton.accessibilityHint = "打开声音选择"
        soundPickerButton.accessibilityIdentifier = "focusSoundPicker"
    }

    private func setupBottomControls() {
        countdownButton.setTitle("∞", for: .normal)
        countdownButton.setTitleColor(.white, for: .normal)
        countdownButton.titleLabel?.font = AppTheme.font(.largeTitle, weight: .regular)
        countdownButton.titleLabel?.adjustsFontForContentSizeCategory = true
        countdownButton.titleLabel?.accessibilityIdentifier = "focusCountdown"
        countdownButton.accessibilityIdentifier = "focusCountdown"
        countdownButton.accessibilityLabel = "设置倒计时"
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
        closeButton.accessibilityLabel = "关闭播放页"

        statusLabel.font = AppTheme.font(.footnote, weight: .semibold)
        statusLabel.textColor = UIColor.systemRed.withAlphaComponent(0.96)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.accessibilityIdentifier = "focusStatus"
        statusLabel.accessibilityTraits = .updatesFrequently

        retryButton.setTitle("重试", for: .normal)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.titleLabel?.font = AppTheme.font(.footnote, weight: .semibold)
        retryButton.titleLabel?.adjustsFontForContentSizeCategory = true
        retryButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.82)
        retryButton.applyRoundedCorners(radius: 20)
        retryButton.accessibilityLabel = "重试播放"
        retryButton.accessibilityHint = "重新载入当前声音"

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

        view.addSubview(titleLabel)
        view.addSubview(soundPickerButton)
        view.addSubview(statusStack)
        view.addSubview(countdownButton)
        view.addSubview(primaryControlButton)
        view.addSubview(closeButton)

        soundPickerButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.trailing.equalTo(view.safeAreaLayoutGuide).inset(20)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.leading.equalTo(view.safeAreaLayoutGuide).inset(20)
            make.trailing.lessThanOrEqualTo(soundPickerButton.snp.leading).offset(-12)
            make.bottom.lessThanOrEqualTo(soundPickerButton.snp.bottom)
        }

        primaryControlButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(20)
        }
        closeButton.snp.makeConstraints { make in
            make.trailing.equalTo(view.safeAreaLayoutGuide).inset(20)
            make.centerY.equalTo(primaryControlButton)
        }
        countdownButton.snp.makeConstraints { make in
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(20)
            make.bottom.equalTo(primaryControlButton.snp.top).offset(-16)
            make.height.greaterThanOrEqualTo(64)
        }
        statusStack.snp.makeConstraints { make in
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(20)
            make.bottom.equalTo(countdownButton.snp.top).offset(-12)
        }
        retryButton.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(56)
            make.width.greaterThanOrEqualTo(96)
        }
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
        titleLabel.text = sound.title
        soundPickerButton.accessibilityLabel = "切换声音，当前\(sound.title)"
        updateBackground(for: sound)
        updateCountdownPresentation()

        let playing = playerService.isPlaying
        let hasError = playerService.statusMessage != Self.readyStatus
        primaryControlButton.accessibilityLabel = playing ? "暂停播放" : "继续播放"
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

        statusLabel.text = hasError ? playerService.statusMessage : nil
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
            countdownButton.accessibilityValue = "不限时"
        case .running, .paused:
            countdownButton.accessibilityValue = "剩余 \(countdownAccessibilityDuration())"
        case .expired:
            countdownButton.accessibilityValue = "倒计时已结束"
        }
    }

    private func countdownAccessibilityDuration() -> String {
        let totalSeconds = Int(ceil(max(playerService.sleepTimerRemaining ?? 0, 0)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if seconds == 0 {
            return "\(minutes) 分钟"
        }
        if minutes == 0 {
            return "\(seconds) 秒"
        }
        return "\(minutes) 分 \(seconds) 秒"
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
        let library = SoundLibraryViewController(selectedSoundID: playerService.currentSound.id)
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
            title: "设置倒计时",
            message: nil,
            preferredStyle: .actionSheet
        )
        [
            ("不限时", SleepTimerOption.unlimited),
            ("15 分钟", .minutes15),
            ("30 分钟", .minutes30),
            ("60 分钟", .minutes60)
        ].forEach { title, option in
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.selectTimer(option)
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
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
