import SnapKit
import UIKit

final class HomeViewController: UIViewController {
    static let backgroundSettleDuration: TimeInterval = 0.25

    private let playerService: AudioPlayerService
    private let recentStore: RecentSoundsStore
    private let localizationBundle: Bundle
    private let carousel: InfiniteSoundCarousel
    private(set) var displayedSoundIndex: Int
    private var coordinatedRecentSelectionIndex: Int
    private var hasRecordedCoordinatedSelection = false

    private let firstBackgroundImageView = UIImageView()
    private let secondBackgroundImageView = UIImageView()
    private let backgroundBlurView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemUltraThinMaterialDark)
    )
    private let backgroundOverlayView = UIView()
    private var firstBackgroundResource: String?
    private var secondBackgroundResource: String?
    private var settledBackgroundIndex: Int?

    private let headerView = UIView()
    private let greetingLabel = UILabel()
    private let titleLabel = UILabel()
    private let muteButton = UIButton(type: .system)
    private let recentButton = UIButton(type: .system)

    private let controlsView = UIView()
    private let pageControl = UIPageControl()
    private let playPauseButton = UIButton(type: .system)
    private let sleepTimerView: SleepTimerView
    private let statusLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let statusStack = UIStackView()

    init(
        playerService: AudioPlayerService,
        recentStore: RecentSoundsStore,
        localizationBundle: Bundle = .main
    ) {
        self.playerService = playerService
        self.recentStore = recentStore
        self.localizationBundle = localizationBundle
        sleepTimerView = SleepTimerView(localizationBundle: localizationBundle)
        displayedSoundIndex = playerService.selectedIndex
        coordinatedRecentSelectionIndex = playerService.selectedIndex
        carousel = InfiniteSoundCarousel(
            sounds: Sound.catalog,
            selectedIndex: playerService.selectedIndex,
            localizationBundle: localizationBundle
        )
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        setupBackground()
        setupHeader()
        setupControls()
        updateContrastAppearance()
        setupLayout()
        setupInteractions()
        observeChanges()
        render()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.accessibilityContrast != traitCollection.accessibilityContrast
        else { return }
        updateContrastAppearance()
    }

    func selectAndPlaySound(at index: Int, animated: Bool) {
        guard Sound.catalog.indices.contains(index) else { return }
        playerService.selectAndPlay(at: index)
        displayedSoundIndex = index
        carousel.setSelectedSound(index: index, animated: animated)
        render()
    }

    private func setupBackground() {
        view.backgroundColor = AppTheme.tabBarBackground

        [firstBackgroundImageView, secondBackgroundImageView].forEach { imageView in
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerCurve = .continuous
            imageView.isAccessibilityElement = false
            imageView.isUserInteractionEnabled = false
            view.addSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        backgroundBlurView.alpha = 0.20
        backgroundBlurView.isUserInteractionEnabled = false
        backgroundBlurView.isAccessibilityElement = false
        view.addSubview(backgroundBlurView)
        backgroundBlurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        backgroundOverlayView.isUserInteractionEnabled = false
        backgroundOverlayView.isAccessibilityElement = false
        view.addSubview(backgroundOverlayView)
        backgroundOverlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        updateContrastAppearance()
    }

    private func setupHeader() {
        greetingLabel.text = L10n.text("home.greeting", bundle: localizationBundle)
        greetingLabel.accessibilityIdentifier = "home.greeting"
        greetingLabel.font = AppTheme.font(.caption1, weight: .semibold)
        greetingLabel.textColor = UIColor.white.withAlphaComponent(0.74)
        greetingLabel.adjustsFontForContentSizeCategory = true
        greetingLabel.numberOfLines = 0

        titleLabel.font = AppTheme.font(.title2, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 2

        configureHeaderButton(
            muteButton,
            systemName: "speaker.wave.2.fill",
            accessibilityLabel: L10n.text("home.action.mute", bundle: localizationBundle)
        )
        muteButton.accessibilityIdentifier = "home.mute"
        configureHeaderButton(
            recentButton,
            systemName: "clock.arrow.circlepath",
            accessibilityLabel: L10n.text("home.action.recent", bundle: localizationBundle)
        )
        recentButton.accessibilityIdentifier = "home.recent"

        let labelStack = UIStackView(arrangedSubviews: [greetingLabel, titleLabel])
        labelStack.axis = .vertical
        labelStack.spacing = 3

        let actionStack = UIStackView(arrangedSubviews: [muteButton, recentButton])
        actionStack.axis = .horizontal
        actionStack.alignment = .center
        actionStack.spacing = 10

        headerView.addSubview(labelStack)
        headerView.addSubview(actionStack)
        labelStack.snp.makeConstraints { make in
            make.top.bottom.leading.equalToSuperview()
            make.trailing.lessThanOrEqualTo(actionStack.snp.leading).offset(-12)
        }
        actionStack.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
        }
        [muteButton, recentButton].forEach { button in
            button.snp.makeConstraints { make in
                make.size.equalTo(AppTheme.controlSize)
            }
        }
    }

    private func configureHeaderButton(
        _ button: UIButton,
        systemName: String,
        accessibilityLabel: String
    ) {
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.26)
        button.applyRoundedCorners(radius: AppTheme.controlSize / 2)
        button.setImage(
            UIImage(
                systemName: systemName,
                withConfiguration: AppTheme.symbolConfiguration(
                    pointSize: 18,
                    weight: .semibold
                )
            ),
            for: .normal
        )
        button.accessibilityLabel = accessibilityLabel
    }

    private func setupControls() {
        controlsView.accessibilityIdentifier = "homeControls"
        controlsView.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        controlsView.applyRoundedCorners(radius: 24)
        controlsView.layer.borderWidth = 1
        controlsView.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor

        pageControl.numberOfPages = Sound.catalog.count
        pageControl.currentPageIndicatorTintColor = .white
        pageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.30)
        pageControl.isUserInteractionEnabled = false
        pageControl.accessibilityLabel = L10n.text("carousel.label", bundle: localizationBundle)

        playPauseButton.tintColor = AppTheme.accentForeground
        playPauseButton.backgroundColor = AppTheme.accent
        playPauseButton.applyRoundedCorners(radius: AppTheme.primaryControlSize / 2)
        playPauseButton.accessibilityIdentifier = "home.play"

        statusLabel.font = AppTheme.font(.footnote, weight: .medium)
        statusLabel.textColor = UIColor.systemRed.withAlphaComponent(0.96)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.accessibilityTraits = .updatesFrequently

        retryButton.setTitle(L10n.text("common.retry", bundle: localizationBundle), for: .normal)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.titleLabel?.font = AppTheme.font(.footnote, weight: .semibold)
        retryButton.titleLabel?.adjustsFontForContentSizeCategory = true
        retryButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.82)
        retryButton.applyRoundedCorners(radius: 17)
        retryButton.accessibilityIdentifier = "home.retry"
        retryButton.accessibilityHint = L10n.text("home.retry.hint", bundle: localizationBundle)
        retryButton.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(34)
        }

        statusStack.axis = .vertical
        statusStack.alignment = .center
        statusStack.spacing = 6
        statusStack.addArrangedSubview(statusLabel)
        statusStack.addArrangedSubview(retryButton)

        let playButtonContainer = UIView()
        playButtonContainer.addSubview(playPauseButton)
        playPauseButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(AppTheme.primaryControlSize)
            make.top.bottom.equalToSuperview()
        }

        let controlsStack = UIStackView(
            arrangedSubviews: [pageControl, playButtonContainer, sleepTimerView, statusStack]
        )
        controlsStack.axis = .vertical
        controlsStack.spacing = 8
        controlsView.addSubview(controlsStack)
        controlsStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
        pageControl.snp.makeConstraints { make in
            make.height.equalTo(18)
        }
    }

    private func setupLayout() {
        view.addSubview(headerView)
        view.addSubview(carousel)
        view.addSubview(controlsView)

        headerView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(12)
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(20)
        }
        controlsView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(12)
        }
        carousel.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(controlsView.snp.top).offset(-12)
        }
    }

    private func setupInteractions() {
        carousel.onSettled = { [weak self] index in
            guard let self else { return }
            guard index != self.playerService.selectedIndex else {
                self.displayedSoundIndex = index
                return
            }
            self.selectAndPlaySound(at: index, animated: false)
        }
        carousel.onTransition = { [weak self] from, to, progress in
            self?.renderBackgroundTransition(from: from, to: to, progress: progress)
        }
        muteButton.addTarget(self, action: #selector(didTapMute), for: .touchUpInside)
        recentButton.addTarget(self, action: #selector(didTapRecent), for: .touchUpInside)
        playPauseButton.addTarget(
            self,
            action: #selector(didTapOpenFocusPlayback),
            for: .touchUpInside
        )
        retryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)
        sleepTimerView.onSelect = { [weak self] option in
            self?.playerService.setSleepTimer(option)
        }
    }

    private func observeChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlayerStateDidChange),
            name: .audioPlayerStateDidChange,
            object: playerService
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDarkerSystemColorsDidChange),
            name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil
        )
    }

    private func render() {
        coordinateRecentPlayback()
        let selectedIndex = playerService.selectedIndex
        let sound = playerService.currentSound
        displayedSoundIndex = selectedIndex
        titleLabel.text = sound.title(bundle: localizationBundle)

        if carousel.displayedLogicalIndex != selectedIndex {
            carousel.setSelectedSound(index: selectedIndex, animated: false)
        }

        pageControl.currentPage = selectedIndex
        pageControl.accessibilityValue = L10n.format(
            "carousel.position.format",
            bundle: localizationBundle,
            sound.title(bundle: localizationBundle),
            Int64(selectedIndex + 1),
            Int64(Sound.catalog.count)
        )

        let isPlaying = playerService.isPlaying
        let playSymbol = isPlaying ? "waveform" : "play.fill"
        playPauseButton.setImage(
            UIImage(
                systemName: playSymbol,
                withConfiguration: AppTheme.symbolConfiguration(
                    pointSize: 24,
                    weight: .bold
                )
            ),
            for: .normal
        )
        playPauseButton.accessibilityLabel = L10n.text(
            isPlaying ? "home.action.open_player" : "home.action.play_and_open",
            bundle: localizationBundle
        )

        let isMuted = playerService.isMuted
        muteButton.setImage(
            UIImage(
                systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                withConfiguration: AppTheme.symbolConfiguration(
                    pointSize: 18,
                    weight: .semibold
                )
            ),
            for: .normal
        )
        muteButton.accessibilityLabel = L10n.text(
            isMuted ? "home.action.unmute" : "home.action.mute",
            bundle: localizationBundle
        )
        muteButton.accessibilityValue = L10n.text(
            isMuted ? "home.mute.on" : "home.mute.off",
            bundle: localizationBundle
        )

        sleepTimerView.configure(selected: playerService.sleepTimerOption)
        let status = L10n.text(playerService.status.localizationKey, bundle: localizationBundle)
        let hasError = playerService.status != .ready
        statusLabel.text = hasError ? status : nil
        statusStack.isHidden = !hasError

        if settledBackgroundIndex != selectedIndex {
            settledBackgroundIndex = selectedIndex
            renderSettledBackground(for: sound)
        }
    }

    private func coordinateRecentPlayback() {
        let selectedIndex = playerService.selectedIndex
        if coordinatedRecentSelectionIndex != selectedIndex {
            coordinatedRecentSelectionIndex = selectedIndex
            hasRecordedCoordinatedSelection = false
        }
        guard playerService.isPlaying, !hasRecordedCoordinatedSelection else { return }
        hasRecordedCoordinatedSelection = true
        recentStore.record(playerService.currentSound)
    }

    private func renderBackgroundTransition(from: Int, to: Int, progress: CGFloat) {
        guard Sound.catalog.indices.contains(from), Sound.catalog.indices.contains(to) else { return }
        setBackground(
            Sound.catalog[from],
            on: firstBackgroundImageView,
            currentResource: &firstBackgroundResource
        )
        setBackground(
            Sound.catalog[to],
            on: secondBackgroundImageView,
            currentResource: &secondBackgroundResource
        )
        let clampedProgress = min(max(progress, 0), 1)
        let pageWidth = view.bounds.width
        let minimumScale: CGFloat = 0.9
        let scaleRange = 1 - minimumScale
        let maximumCornerRadius: CGFloat = 28

        let baseImageView: UIImageView
        let incomingImageView: UIImageView
        let incomingProgress: CGFloat
        let incomingTranslation: CGFloat
        if to == displayedSoundIndex, from != displayedSoundIndex {
            baseImageView = secondBackgroundImageView
            incomingImageView = firstBackgroundImageView
            incomingProgress = 1 - clampedProgress
            incomingTranslation = -pageWidth * clampedProgress
        } else {
            baseImageView = firstBackgroundImageView
            incomingImageView = secondBackgroundImageView
            incomingProgress = clampedProgress
            incomingTranslation = pageWidth * (1 - clampedProgress)
        }

        if let baseIndex = view.subviews.firstIndex(of: baseImageView),
           let incomingIndex = view.subviews.firstIndex(of: incomingImageView),
           incomingIndex < baseIndex {
            view.insertSubview(incomingImageView, aboveSubview: baseImageView)
        }

        baseImageView.transform = .identity
        baseImageView.layer.cornerRadius = 0
        baseImageView.alpha = 1

        let incomingScale = minimumScale + scaleRange * incomingProgress
        incomingImageView.transform = CGAffineTransform(
            a: incomingScale,
            b: 0,
            c: 0,
            d: incomingScale,
            tx: incomingTranslation,
            ty: 0
        )
        incomingImageView.layer.cornerRadius = maximumCornerRadius * (1 - incomingProgress)
        incomingImageView.alpha = 1
    }

    private func renderSettledBackground(for sound: Sound) {
        let targetImageView: UIImageView
        let sourceImageView: UIImageView
        if firstBackgroundResource == sound.backgroundResource {
            targetImageView = firstBackgroundImageView
            sourceImageView = secondBackgroundImageView
        } else if secondBackgroundResource == sound.backgroundResource {
            targetImageView = secondBackgroundImageView
            sourceImageView = firstBackgroundImageView
        } else if firstBackgroundImageView.alpha <= secondBackgroundImageView.alpha {
            setBackground(
                sound,
                on: firstBackgroundImageView,
                currentResource: &firstBackgroundResource
            )
            targetImageView = firstBackgroundImageView
            sourceImageView = secondBackgroundImageView
        } else {
            setBackground(
                sound,
                on: secondBackgroundImageView,
                currentResource: &secondBackgroundResource
            )
            targetImageView = secondBackgroundImageView
            sourceImageView = firstBackgroundImageView
        }

        UIView.animate(
            withDuration: Self.backgroundSettleDuration,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut]
        ) {
            targetImageView.alpha = 1
            targetImageView.transform = .identity
            targetImageView.layer.cornerRadius = 0
            sourceImageView.alpha = 0
            sourceImageView.transform = .identity
            sourceImageView.layer.cornerRadius = 0
        }
    }

    private func setBackground(
        _ sound: Sound,
        on imageView: UIImageView,
        currentResource: inout String?
    ) {
        guard currentResource != sound.backgroundResource else { return }
        currentResource = sound.backgroundResource
        imageView.image = SoundArtwork.image(for: sound)
    }

    private func updateContrastAppearance() {
        let increasedContrast = traitCollection.accessibilityContrast == .high
            || UIAccessibility.isDarkerSystemColorsEnabled
        backgroundOverlayView.backgroundColor = increasedContrast
            ? UIColor.black.withAlphaComponent(0.42)
            : AppTheme.homeOverlay
        let actionBackground = UIColor.black.withAlphaComponent(increasedContrast ? 0.48 : 0.26)
        muteButton.backgroundColor = actionBackground
        recentButton.backgroundColor = actionBackground
        controlsView.layer.borderColor = UIColor.white
            .withAlphaComponent(increasedContrast ? 0.28 : 0.10)
            .cgColor
    }

    @objc private func handlePlayerStateDidChange() {
        render()
    }

    @objc private func handleDarkerSystemColorsDidChange() {
        updateContrastAppearance()
    }

    @objc private func didTapMute() {
        playerService.toggleMuted()
    }

    @objc private func didTapOpenFocusPlayback() {
        if !playerService.isPlaying {
            playerService.play()
        }
        guard presentedViewController == nil else { return }

        let controller = FocusPlaybackViewController(
            playerService: playerService,
            localizationBundle: localizationBundle,
            onSelectSound: { [weak self] index in
                self?.selectAndPlaySound(at: index, animated: false)
            }
        )
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true)
    }

    @objc private func didTapRetry() {
        playerService.retry()
    }

    @objc private func didTapRecent() {
        let recentController = RecentSoundsViewController(
            sounds: recentStore.recentSounds,
            selectedSoundID: playerService.currentSound.id,
            localizationBundle: localizationBundle
        )
        recentController.modalPresentationStyle = .overFullScreen
        recentController.modalTransitionStyle = .crossDissolve
        recentController.onSelect = { [weak self, weak recentController] sound in
            guard
                let self,
                let index = Sound.catalog.firstIndex(of: sound)
            else { return }
            self.selectAndPlaySound(at: index, animated: true)
            recentController?.dismiss(animated: false)
        }
        recentController.onClose = { [weak recentController] in
            recentController?.dismiss(animated: false)
        }
        present(recentController, animated: false)
    }
}
