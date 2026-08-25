import SnapKit
import UIKit

private final class ContentSizedCollectionView: UICollectionView {
    var usesIntrinsicContentHeight = false {
        didSet {
            guard usesIntrinsicContentHeight != oldValue else { return }
            invalidateIntrinsicContentSize()
        }
    }

    override var contentSize: CGSize {
        didSet {
            guard usesIntrinsicContentHeight, contentSize != oldValue else { return }
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        guard usesIntrinsicContentHeight else { return super.intrinsicContentSize }
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: max(collectionViewLayout.collectionViewContentSize.height, 1)
        )
    }

    func invalidateSelfSizingLayout() {
        collectionViewLayout.invalidateLayout()
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }
}

final class PlayerViewController: UIViewController {
    private enum LayoutMode {
        case compact
        case regular
    }

    private static let regularWidthThreshold: CGFloat = 720
    private static let readyStatus = "准备就绪"
    private let playerService: AudioPlayerService
    private var layoutMode: LayoutMode?
    private var layoutRootView: UIView?
    private var adaptiveConstraints: [Constraint] = []
    private weak var compactScrollView: UIScrollView?
    private var renderedBackgroundResource: String?

    private let backgroundImageView = UIImageView()
    private let backgroundBlurView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemUltraThinMaterialDark)
    )
    private let gradientLayer = CAGradientLayer()

    private let navigationBar = UIStackView()
    private let backButton = UIButton(type: .system)
    private let timerShortcutButton = UIButton(type: .system)

    private let heroPanel = UIView()
    private let eyebrowLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let controlsView = PlayerControlsView()
    private let statusLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    private let timerSectionView = UIView()
    private let timerTitleLabel = UILabel()
    private let sleepTimerView = SleepTimerView()
    private let soundsTitleLabel = UILabel()

    private lazy var soundsCollectionView: ContentSizedCollectionView = {
        let collectionView = ContentSizedCollectionView(
            frame: .zero,
            collectionViewLayout: makeCollectionLayout(for: .compact)
        )
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            SoundCell.self,
            forCellWithReuseIdentifier: SoundCell.reuseIdentifier
        )
        return collectionView
    }()

    init(playerService: AudioPlayerService) {
        self.playerService = playerService
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
        setupNavigationBar()
        setupHeroPanel()
        setupTimerSection()
        setupInteractions()
        observePlayerState()
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds

        let nextMode: LayoutMode = view.bounds.width >= Self.regularWidthThreshold
            ? .regular
            : .compact
        guard nextMode != layoutMode else { return }
        rebuildLayout(for: nextMode)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard
            previousTraitCollection?.preferredContentSizeCategory
                != traitCollection.preferredContentSizeCategory
        else { return }

        refreshForContentSizeCategory()
    }

    private func refreshForContentSizeCategory() {
        soundsCollectionView.visibleCells.forEach(styleImmersiveSoundCell)
        soundsCollectionView.reloadData()
        soundsCollectionView.invalidateSelfSizingLayout()
        applyImmersiveControlColors()
    }

    private func setupBackground() {
        view.backgroundColor = UIColor(red: 0.035, green: 0.055, blue: 0.075, alpha: 1)

        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        backgroundImageView.backgroundColor = view.backgroundColor
        backgroundImageView.isAccessibilityElement = false

        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.12).cgColor,
            UIColor.black.withAlphaComponent(0.78).cgColor
        ]
        gradientLayer.locations = [0, 1]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)

        let gradientView = UIView()
        gradientView.isUserInteractionEnabled = false
        gradientView.layer.addSublayer(gradientLayer)

        view.addSubview(backgroundImageView)
        view.addSubview(backgroundBlurView)
        view.addSubview(gradientView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        backgroundBlurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupNavigationBar() {
        navigationBar.axis = .horizontal
        navigationBar.alignment = .center
        navigationBar.distribution = .equalSpacing

        backButton.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        backButton.tintColor = .white
        backButton.applyRoundedCorners(radius: 24)
        backButton.setImage(
            UIImage(
                systemName: "chevron.left",
                withConfiguration: AppTheme.symbolConfiguration(pointSize: 19, weight: .semibold)
            ),
            for: .normal
        )
        backButton.accessibilityLabel = "返回"

        timerShortcutButton.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        timerShortcutButton.tintColor = .white
        var timerConfiguration = UIButton.Configuration.plain()
        timerConfiguration.contentInsets = NSDirectionalEdgeInsets(
            top: 10,
            leading: 16,
            bottom: 10,
            trailing: 16
        )
        timerShortcutButton.configuration = timerConfiguration
        timerShortcutButton.setTitle("睡眠定时", for: .normal)
        timerShortcutButton.titleLabel?.font = AppTheme.font(.subheadline, weight: .semibold)
        timerShortcutButton.titleLabel?.adjustsFontForContentSizeCategory = true
        timerShortcutButton.applyRoundedCorners(radius: 22)
        timerShortcutButton.accessibilityHint = "滚动到睡眠定时选项"

        let spacer = UIView()
        navigationBar.addArrangedSubview(backButton)
        navigationBar.addArrangedSubview(spacer)
        navigationBar.addArrangedSubview(timerShortcutButton)
        backButton.snp.makeConstraints { make in
            make.size.equalTo(48)
        }
        timerShortcutButton.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(44)
        }
        navigationBar.snp.makeConstraints { make in
            make.height.equalTo(48)
        }
    }

    private func setupHeroPanel() {
        heroPanel.backgroundColor = UIColor.black.withAlphaComponent(0.22)
        heroPanel.applyRoundedCorners(radius: 32)
        heroPanel.layer.borderWidth = 1
        heroPanel.layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor
        heroPanel.clipsToBounds = true

        eyebrowLabel.text = "环境声 · 独立播放"
        eyebrowLabel.font = AppTheme.font(.subheadline, weight: .semibold)
        eyebrowLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        eyebrowLabel.adjustsFontForContentSizeCategory = true
        eyebrowLabel.textAlignment = .center

        titleLabel.font = AppTheme.font(.largeTitle, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        subtitleLabel.font = AppTheme.font(.title3)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.76)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        statusLabel.font = AppTheme.font(.footnote, weight: .medium)
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.76)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        var retryConfiguration = UIButton.Configuration.plain()
        retryConfiguration.contentInsets = NSDirectionalEdgeInsets(
            top: 8,
            leading: 14,
            bottom: 8,
            trailing: 14
        )
        retryButton.configuration = retryConfiguration
        retryButton.setTitle("重试", for: .normal)
        retryButton.titleLabel?.font = AppTheme.font(.footnote, weight: .semibold)
        retryButton.titleLabel?.adjustsFontForContentSizeCategory = true
        retryButton.tintColor = .white
        retryButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.82)
        retryButton.applyRoundedCorners(radius: 17)
        retryButton.accessibilityHint = "重新载入当前声音"

        let statusStack = UIStackView(arrangedSubviews: [statusLabel, retryButton])
        statusStack.axis = .vertical
        statusStack.alignment = .center
        statusStack.spacing = 10

        let contentStack = UIStackView(
            arrangedSubviews: [
                eyebrowLabel,
                titleLabel,
                subtitleLabel,
                controlsView,
                statusStack
            ]
        )
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 14
        contentStack.setCustomSpacing(24, after: subtitleLabel)
        contentStack.setCustomSpacing(20, after: controlsView)

        heroPanel.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(32)
            make.top.greaterThanOrEqualToSuperview().inset(36)
            make.bottom.lessThanOrEqualToSuperview().inset(36)
        }
    }

    private func setupTimerSection() {
        timerSectionView.backgroundColor = UIColor.black.withAlphaComponent(0.22)
        timerSectionView.applyRoundedCorners()
        timerSectionView.layer.borderWidth = 1
        timerSectionView.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor

        timerTitleLabel.text = "睡眠定时"
        timerTitleLabel.font = AppTheme.font(.headline, weight: .semibold)
        timerTitleLabel.textColor = .white
        timerTitleLabel.adjustsFontForContentSizeCategory = true

        let timerStack = UIStackView(arrangedSubviews: [timerTitleLabel, sleepTimerView])
        timerStack.axis = .vertical
        timerStack.spacing = 14
        timerSectionView.addSubview(timerStack)
        timerStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(18)
        }

        soundsTitleLabel.text = "切换声音"
        soundsTitleLabel.font = AppTheme.font(.title3, weight: .semibold)
        soundsTitleLabel.textColor = .white
        soundsTitleLabel.adjustsFontForContentSizeCategory = true
    }

    private func setupInteractions() {
        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        timerShortcutButton.addTarget(
            self,
            action: #selector(didTapTimerShortcut),
            for: .touchUpInside
        )
        retryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)

        controlsView.onPrevious = { [weak self] in
            self?.playerService.previous()
        }
        controlsView.onToggle = { [weak self] in
            self?.playerService.togglePlayback()
        }
        controlsView.onNext = { [weak self] in
            self?.playerService.next()
        }
        sleepTimerView.onSelect = { [weak self] option in
            self?.playerService.setSleepTimer(option)
        }
    }

    private func observePlayerState() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlayerStateDidChange),
            name: .audioPlayerStateDidChange,
            object: playerService
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleContentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }

    private func rebuildLayout(for mode: LayoutMode) {
        detachAdaptiveViews()

        let rootView = UIView()
        view.addSubview(rootView)
        rootView.snp.makeConstraints { make in
            adaptiveConstraints.append(make.edges.equalToSuperview().constraint)
        }
        layoutRootView = rootView

        soundsCollectionView.setCollectionViewLayout(
            makeCollectionLayout(for: mode),
            animated: false
        )
        soundsCollectionView.isScrollEnabled = mode == .regular
        soundsCollectionView.usesIntrinsicContentHeight = mode == .compact
        soundsCollectionView.setContentCompressionResistancePriority(
            mode == .compact ? .required : .defaultHigh,
            for: .vertical
        )

        switch mode {
        case .compact:
            buildCompactLayout(in: rootView)
        case .regular:
            buildRegularLayout(in: rootView)
        }

        timerShortcutButton.isHidden = mode == .regular
        layoutMode = mode
        soundsCollectionView.reloadData()
        soundsCollectionView.invalidateSelfSizingLayout()
    }

    private func detachAdaptiveViews() {
        adaptiveConstraints.forEach { $0.deactivate() }
        adaptiveConstraints.removeAll()
        navigationBar.removeFromSuperview()
        heroPanel.removeFromSuperview()
        timerSectionView.removeFromSuperview()
        soundsTitleLabel.removeFromSuperview()
        soundsCollectionView.removeFromSuperview()
        layoutRootView?.removeFromSuperview()
        layoutRootView = nil
        compactScrollView = nil
    }

    private func buildCompactLayout(in rootView: UIView) {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        rootView.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            adaptiveConstraints.append(make.edges.equalToSuperview().constraint)
        }
        compactScrollView = scrollView

        let contentStack = UIStackView(
            arrangedSubviews: [
                navigationBar,
                heroPanel,
                timerSectionView,
                soundsTitleLabel,
                soundsCollectionView
            ]
        )
        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.setCustomSpacing(28, after: heroPanel)
        contentStack.setCustomSpacing(28, after: timerSectionView)
        contentStack.setCustomSpacing(12, after: soundsTitleLabel)
        scrollView.addSubview(contentStack)

        contentStack.snp.makeConstraints { make in
            adaptiveConstraints.append(
                make.top.equalTo(scrollView.contentLayoutGuide).offset(16).constraint
            )
            adaptiveConstraints.append(
                make.leading.trailing.equalTo(scrollView.frameLayoutGuide).inset(20).constraint
            )
            adaptiveConstraints.append(
                make.bottom.equalTo(scrollView.contentLayoutGuide).inset(32).constraint
            )
        }
        heroPanel.snp.makeConstraints { make in
            adaptiveConstraints.append(make.height.greaterThanOrEqualTo(548).constraint)
        }
    }

    private func buildRegularLayout(in rootView: UIView) {
        let sidebarView = UIView()
        sidebarView.backgroundColor = UIColor.black.withAlphaComponent(0.24)
        sidebarView.applyRoundedCorners(radius: 28)
        sidebarView.layer.borderWidth = 1
        sidebarView.layer.borderColor = UIColor.white.withAlphaComponent(0.14).cgColor

        let mainScrollView = UIScrollView()
        mainScrollView.alwaysBounceVertical = true
        mainScrollView.showsVerticalScrollIndicator = false

        rootView.addSubview(mainScrollView)
        rootView.addSubview(sidebarView)

        let mainStack = UIStackView(arrangedSubviews: [navigationBar, heroPanel])
        mainStack.axis = .vertical
        mainStack.spacing = 16
        mainScrollView.addSubview(mainStack)

        soundsCollectionView.isScrollEnabled = false
        soundsCollectionView.usesIntrinsicContentHeight = true
        let sidebarScrollView = UIScrollView()
        sidebarScrollView.alwaysBounceVertical = true
        sidebarScrollView.showsVerticalScrollIndicator = false
        sidebarView.addSubview(sidebarScrollView)
        let sidebarStack = UIStackView(
            arrangedSubviews: [timerSectionView, soundsTitleLabel, soundsCollectionView]
        )
        sidebarStack.axis = .vertical
        sidebarStack.spacing = 12
        sidebarStack.setCustomSpacing(24, after: timerSectionView)
        sidebarScrollView.addSubview(sidebarStack)

        sidebarView.snp.makeConstraints { make in
            adaptiveConstraints.append(
                make.top.bottom.equalTo(rootView.safeAreaLayoutGuide).inset(16).constraint
            )
            adaptiveConstraints.append(
                make.trailing.equalTo(rootView.safeAreaLayoutGuide).inset(24).constraint
            )
            adaptiveConstraints.append(make.width.equalTo(300).constraint)
        }
        mainScrollView.snp.makeConstraints { make in
            adaptiveConstraints.append(
                make.top.bottom.equalTo(rootView.safeAreaLayoutGuide).constraint
            )
            adaptiveConstraints.append(
                make.leading.equalTo(rootView.safeAreaLayoutGuide).offset(24).constraint
            )
            adaptiveConstraints.append(
                make.trailing.equalTo(sidebarView.snp.leading).offset(-24).constraint
            )
        }
        mainStack.snp.makeConstraints { make in
            adaptiveConstraints.append(
                make.top.equalTo(mainScrollView.contentLayoutGuide).offset(16).constraint
            )
            adaptiveConstraints.append(
                make.leading.trailing.equalTo(mainScrollView.frameLayoutGuide).constraint
            )
            adaptiveConstraints.append(
                make.bottom.equalTo(mainScrollView.contentLayoutGuide).inset(16).constraint
            )
        }
        heroPanel.snp.makeConstraints { make in
            adaptiveConstraints.append(make.height.greaterThanOrEqualTo(500).constraint)
        }
        sidebarScrollView.snp.makeConstraints { make in
            adaptiveConstraints.append(
                make.edges.equalToSuperview().inset(12).constraint
            )
        }
        sidebarStack.snp.makeConstraints { make in
            adaptiveConstraints.append(
                make.top.bottom.equalTo(sidebarScrollView.contentLayoutGuide).constraint
            )
            adaptiveConstraints.append(
                make.leading.trailing.equalTo(sidebarScrollView.frameLayoutGuide).constraint
            )
        }
    }

    private func makeCollectionLayout(for mode: LayoutMode) -> UICollectionViewLayout {
        let estimatedHeight: CGFloat = mode == .compact ? 96 : 64
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(estimatedHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(estimatedHeight)
        )
        let group: NSCollectionLayoutGroup
        switch mode {
        case .compact:
            group = .horizontal(layoutSize: groupSize, subitem: item, count: 3)
            group.interItemSpacing = .fixed(12)
        case .regular:
            group = .horizontal(layoutSize: groupSize, subitems: [item])
        }

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        return UICollectionViewCompositionalLayout(section: section)
    }

    private func render() {
        let sound = playerService.currentSound
        titleLabel.text = sound.title
        subtitleLabel.text = sound.subtitle
        controlsView.configure(isPlaying: playerService.isPlaying)
        sleepTimerView.configure(selected: playerService.sleepTimerOption)
        applyImmersiveControlColors()

        let status = playerService.statusMessage
        let hasError = status != Self.readyStatus
        statusLabel.text = status
        statusLabel.textColor = hasError
            ? UIColor.systemRed.withAlphaComponent(0.92)
            : UIColor.white.withAlphaComponent(0.76)
        retryButton.isHidden = !hasError

        updateBackground(for: sound)
        soundsCollectionView.reloadData()
    }

    private func applyImmersiveControlColors() {
        buttons(in: controlsView).forEach(styleImmersiveButton)
        buttons(in: sleepTimerView).forEach(styleImmersiveButton)
    }

    private func buttons(in rootView: UIView) -> [UIButton] {
        rootView.subviews.flatMap { subview -> [UIButton] in
            let button = subview as? UIButton
            return (button.map { [$0] } ?? []) + buttons(in: subview)
        }
    }

    private func labels(in rootView: UIView) -> [UILabel] {
        rootView.subviews.flatMap { subview -> [UILabel] in
            let label = subview as? UILabel
            return (label.map { [$0] } ?? []) + labels(in: subview)
        }
    }

    private func styleImmersiveButton(_ button: UIButton) {
        let usesAccentBackground = button.backgroundColor?.isEqual(AppTheme.accent) == true
        let foreground = usesAccentBackground ? AppTheme.accentForeground : UIColor.white
        button.tintColor = foreground
        button.setTitleColor(foreground, for: .normal)
    }

    private func styleImmersiveSoundCell(_ cell: UICollectionViewCell) {
        for label in labels(in: cell.contentView) {
            label.textColor = .white
        }
    }

    private func updateBackground(for sound: Sound) {
        guard renderedBackgroundResource != sound.backgroundResource else { return }
        renderedBackgroundResource = sound.backgroundResource

        let imageURL = Bundle.main.url(
            forResource: sound.backgroundResource,
            withExtension: "png",
            subdirectory: "Backgrounds"
        ) ?? Bundle.main.url(
            forResource: sound.backgroundResource,
            withExtension: "png"
        )
        let image = imageURL.flatMap { UIImage(contentsOfFile: $0.path) }

        UIView.transition(
            with: backgroundImageView,
            duration: 0.25,
            options: [.transitionCrossDissolve, .allowAnimatedContent]
        ) {
            self.backgroundImageView.image = image
        }
    }

    @objc private func handlePlayerStateDidChange() {
        render()
    }

    @objc private func handleContentSizeCategoryDidChange() {
        refreshForContentSizeCategory()
    }

    @objc private func didTapBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func didTapTimerShortcut() {
        guard let scrollView = compactScrollView else { return }
        let timerRect = timerSectionView.convert(timerSectionView.bounds, to: scrollView)
        scrollView.scrollRectToVisible(
            timerRect.insetBy(dx: 0, dy: -16),
            animated: true
        )
    }

    @objc private func didTapRetry() {
        playerService.retry()
    }
}

extension PlayerViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        Sound.catalog.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: SoundCell.reuseIdentifier,
            for: indexPath
        ) as? SoundCell else {
            return UICollectionViewCell()
        }
        cell.configure(
            sound: Sound.catalog[indexPath.item],
            selected: indexPath.item == playerService.selectedIndex
        )
        styleImmersiveSoundCell(cell)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        playerService.selectSound(at: indexPath.item)
    }
}
