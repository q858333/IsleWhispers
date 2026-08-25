import SnapKit
import UIKit

private final class LibraryContentSizedCollectionView: UICollectionView {
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

final class LibraryViewController: UIViewController {
    private enum LayoutMode {
        case compact
        case regular
    }

    private static let regularWidthThreshold: CGFloat = 720

    private let playerService: AudioPlayerService
    private var layoutMode: LayoutMode?
    private var layoutRootView: UIView?
    private var adaptiveConstraints: [Constraint] = []

    private let greetingLabel = UILabel()
    private let titleLabel = UILabel()
    private let compactPlayerCard = UIView()
    private let playingLabel = UILabel()
    private let waveVisual = UIView()
    private let waveImageView = UIImageView()
    private let soundTitleLabel = UILabel()
    private let soundSubtitleLabel = UILabel()
    private let controlsView = PlayerControlsView()
    private let statusLabel = UILabel()
    private let libraryTitleLabel = UILabel()
    private let libraryCountLabel = UILabel()
    private let sleepTimerTitleLabel = UILabel()
    private let sleepTimerView = SleepTimerView()

    private lazy var collectionView: LibraryContentSizedCollectionView = {
        let collectionView = LibraryContentSizedCollectionView(
            frame: .zero,
            collectionViewLayout: makeCollectionLayout(for: .compact)
        )
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = false
        collectionView.showsVerticalScrollIndicator = false
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
        setupViews()
        setupInteractions()
        observePlayerState()
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

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

    private func setupViews() {
        view.backgroundColor = AppTheme.background

        greetingLabel.text = "今天 · 给自己一点安静"
        greetingLabel.font = AppTheme.font(.caption1, weight: .medium)
        greetingLabel.textColor = AppTheme.muted
        greetingLabel.adjustsFontForContentSizeCategory = true
        greetingLabel.numberOfLines = 0

        titleLabel.text = "让声音慢下来。"
        titleLabel.font = AppTheme.font(.largeTitle, weight: .bold)
        titleLabel.textColor = AppTheme.foreground
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0

        compactPlayerCard.backgroundColor = UIColor(
            red: 0.055,
            green: 0.065,
            blue: 0.072,
            alpha: 1
        )
        compactPlayerCard.applyRoundedCorners(radius: 28)
        compactPlayerCard.applySubtleShadow()

        playingLabel.text = "正在播放"
        playingLabel.font = AppTheme.font(.caption1, weight: .semibold)
        playingLabel.adjustsFontForContentSizeCategory = true
        playingLabel.numberOfLines = 0

        waveVisual.clipsToBounds = true
        waveImageView.image = UIImage(
            systemName: "waveform",
            withConfiguration: AppTheme.symbolConfiguration(pointSize: 58, weight: .light)
        )
        waveImageView.contentMode = .scaleAspectFit
        waveImageView.isAccessibilityElement = false
        waveVisual.addSubview(waveImageView)
        waveImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.lessThanOrEqualToSuperview().multipliedBy(0.48)
        }

        soundTitleLabel.font = AppTheme.font(.largeTitle, weight: .bold)
        soundTitleLabel.adjustsFontForContentSizeCategory = true
        soundTitleLabel.textAlignment = .center
        soundTitleLabel.numberOfLines = 0

        soundSubtitleLabel.font = AppTheme.font(.body)
        soundSubtitleLabel.adjustsFontForContentSizeCategory = true
        soundSubtitleLabel.textAlignment = .center
        soundSubtitleLabel.numberOfLines = 0

        statusLabel.font = AppTheme.font(.footnote, weight: .medium)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityTraits = .updatesFrequently

        libraryTitleLabel.text = "全部声音"
        libraryTitleLabel.font = AppTheme.font(.title2, weight: .bold)
        libraryTitleLabel.textColor = AppTheme.foreground
        libraryTitleLabel.adjustsFontForContentSizeCategory = true
        libraryTitleLabel.numberOfLines = 0

        libraryCountLabel.text = "15 种"
        libraryCountLabel.font = AppTheme.font(.caption1, weight: .medium)
        libraryCountLabel.textColor = AppTheme.muted
        libraryCountLabel.adjustsFontForContentSizeCategory = true

        sleepTimerTitleLabel.text = "睡眠定时"
        sleepTimerTitleLabel.font = AppTheme.font(.headline, weight: .semibold)
        sleepTimerTitleLabel.textColor = AppTheme.foreground
        sleepTimerTitleLabel.adjustsFontForContentSizeCategory = true
    }

    private func setupInteractions() {
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
            adaptiveConstraints.append(
                make.edges.equalTo(view.safeAreaLayoutGuide).constraint
            )
        }
        layoutRootView = rootView

        collectionView.setCollectionViewLayout(
            makeCollectionLayout(for: mode),
            animated: false
        )
        collectionView.usesIntrinsicContentHeight = mode == .compact
        collectionView.isScrollEnabled = mode == .regular
        collectionView.alwaysBounceVertical = mode == .regular

        switch mode {
        case .compact:
            buildCompactLayout(in: rootView)
        case .regular:
            buildRegularLayout(in: rootView)
        }

        layoutMode = mode
        collectionView.reloadData()
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.invalidateIntrinsicContentSize()
    }

    private func detachAdaptiveViews() {
        adaptiveConstraints.forEach { $0.deactivate() }
        adaptiveConstraints.removeAll()
        layoutRootView?.removeFromSuperview()
        layoutRootView = nil
    }

    private func buildCompactLayout(in rootView: UIView) {
        applyCompactStyle()
        compactPlayerCard.subviews.forEach { $0.removeFromSuperview() }

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        rootView.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            adaptiveConstraints.append(make.edges.equalToSuperview().constraint)
        }

        let headerStack = UIStackView(arrangedSubviews: [greetingLabel, titleLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 6

        let playerStack = UIStackView(
            arrangedSubviews: [
                playingLabel,
                waveVisual,
                soundTitleLabel,
                soundSubtitleLabel,
                controlsView
            ]
        )
        playerStack.axis = .vertical
        playerStack.alignment = .center
        playerStack.spacing = 12
        playerStack.setCustomSpacing(16, after: playingLabel)
        playerStack.setCustomSpacing(16, after: soundSubtitleLabel)
        compactPlayerCard.addSubview(playerStack)
        playerStack.snp.makeConstraints { make in
            adaptiveConstraints.append(make.edges.equalToSuperview().inset(22).constraint)
        }
        waveVisual.snp.makeConstraints { make in
            adaptiveConstraints.append(make.size.equalTo(112).constraint)
        }

        let libraryHeader = makeLibraryHeader()
        let contentStack = UIStackView(
            arrangedSubviews: [
                headerStack,
                compactPlayerCard,
                statusLabel,
                libraryHeader,
                collectionView
            ]
        )
        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.setCustomSpacing(20, after: headerStack)
        contentStack.setCustomSpacing(10, after: compactPlayerCard)
        contentStack.setCustomSpacing(24, after: statusLabel)
        contentStack.setCustomSpacing(10, after: libraryHeader)
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
    }

    private func buildRegularLayout(in rootView: UIView) {
        applyRegularStyle()

        let libraryPane = UIView()
        libraryPane.backgroundColor = AppTheme.surface
        libraryPane.applyRoundedCorners()

        let libraryHeader = makeLibraryHeader(title: "声音")
        libraryPane.addSubview(libraryHeader)
        libraryPane.addSubview(collectionView)
        libraryHeader.snp.makeConstraints { make in
            adaptiveConstraints.append(
                make.top.leading.trailing.equalToSuperview().inset(18).constraint
            )
        }
        collectionView.snp.makeConstraints { make in
            adaptiveConstraints.append(
                make.top.equalTo(libraryHeader.snp.bottom).offset(12).constraint
            )
            adaptiveConstraints.append(
                make.leading.trailing.bottom.equalToSuperview().inset(12).constraint
            )
        }

        let playerPane = UIView()
        playerPane.backgroundColor = AppTheme.background
        playerPane.applyRoundedCorners()
        playerPane.layer.borderWidth = 1
        playerPane.layer.borderColor = AppTheme.muted.withAlphaComponent(0.18).cgColor

        let timerStack = UIStackView(arrangedSubviews: [sleepTimerTitleLabel, sleepTimerView])
        timerStack.axis = .vertical
        timerStack.spacing = 10

        let trackStack = UIStackView(arrangedSubviews: [soundTitleLabel, soundSubtitleLabel])
        trackStack.axis = .vertical
        trackStack.alignment = .leading
        trackStack.spacing = 8

        let playerStack = UIStackView(
            arrangedSubviews: [
                playingLabel,
                trackStack,
                waveVisual,
                controlsView,
                timerStack,
                statusLabel
            ]
        )
        playerStack.axis = .vertical
        playerStack.alignment = .fill
        playerStack.spacing = 18
        playerStack.setCustomSpacing(12, after: playingLabel)
        playerStack.setCustomSpacing(24, after: trackStack)
        playerStack.setCustomSpacing(22, after: waveVisual)
        playerStack.setCustomSpacing(20, after: controlsView)

        let playerScrollView = UIScrollView()
        playerScrollView.alwaysBounceVertical = true
        playerScrollView.showsVerticalScrollIndicator = false
        playerPane.addSubview(playerScrollView)
        playerScrollView.snp.makeConstraints { make in
            adaptiveConstraints.append(make.edges.equalToSuperview().constraint)
        }
        playerScrollView.addSubview(playerStack)
        playerStack.snp.makeConstraints { make in
            adaptiveConstraints.append(
                make.top.equalTo(playerScrollView.contentLayoutGuide).offset(28).constraint
            )
            adaptiveConstraints.append(
                make.leading.trailing.equalTo(playerScrollView.frameLayoutGuide).inset(28).constraint
            )
            adaptiveConstraints.append(
                make.bottom.equalTo(playerScrollView.contentLayoutGuide).inset(28).constraint
            )
        }
        waveVisual.snp.makeConstraints { make in
            adaptiveConstraints.append(make.height.greaterThanOrEqualTo(180).constraint)
        }
        controlsView.snp.makeConstraints { make in
            adaptiveConstraints.append(make.centerX.equalToSuperview().constraint)
        }

        let workspace = UIStackView(arrangedSubviews: [libraryPane, playerPane])
        workspace.axis = .horizontal
        workspace.alignment = .fill
        workspace.spacing = 14
        rootView.addSubview(workspace)
        workspace.snp.makeConstraints { make in
            adaptiveConstraints.append(make.edges.equalToSuperview().inset(16).constraint)
        }
        libraryPane.snp.makeConstraints { make in
            adaptiveConstraints.append(make.width.equalTo(290).constraint)
        }
    }

    private func makeLibraryHeader(title: String = "全部声音") -> UIStackView {
        libraryTitleLabel.text = title
        let header = UIStackView(arrangedSubviews: [libraryTitleLabel, libraryCountLabel])
        header.axis = .horizontal
        header.alignment = .firstBaseline
        header.distribution = .equalSpacing
        header.spacing = 12
        return header
    }

    private func applyCompactStyle() {
        playingLabel.textColor = UIColor.white.withAlphaComponent(0.70)
        soundTitleLabel.textColor = .white
        soundTitleLabel.textAlignment = .center
        soundSubtitleLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        soundSubtitleLabel.textAlignment = .center
        statusLabel.textColor = AppTheme.muted
        waveVisual.backgroundColor = UIColor.white.withAlphaComponent(0.09)
        waveVisual.applyRoundedCorners(radius: 56)
        waveImageView.tintColor = .white
    }

    private func applyRegularStyle() {
        playingLabel.textColor = AppTheme.muted
        soundTitleLabel.textColor = AppTheme.foreground
        soundTitleLabel.textAlignment = .left
        soundSubtitleLabel.textColor = AppTheme.muted
        soundSubtitleLabel.textAlignment = .left
        statusLabel.textColor = AppTheme.muted
        waveVisual.backgroundColor = UIColor(
            red: 0.055,
            green: 0.065,
            blue: 0.072,
            alpha: 1
        )
        waveVisual.applyRoundedCorners(radius: 28)
        waveImageView.tintColor = UIColor.white.withAlphaComponent(0.90)
    }

    private func makeCollectionLayout(for mode: LayoutMode) -> UICollectionViewLayout {
        let rowHeight: CGFloat = mode == .compact ? 96 : 52
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(rowHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(rowHeight)
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
        section.interGroupSpacing = mode == .compact ? 12 : 5
        return UICollectionViewCompositionalLayout(section: section)
    }

    private func render() {
        let sound = playerService.currentSound
        soundTitleLabel.text = sound.title
        soundSubtitleLabel.text = sound.subtitle
        statusLabel.text = playerService.statusMessage
        controlsView.configure(isPlaying: playerService.isPlaying)
        sleepTimerView.configure(selected: playerService.sleepTimerOption)
        collectionView.reloadData()
    }

    private func refreshForContentSizeCategory() {
        collectionView.reloadData()
        collectionView.invalidateSelfSizingLayout()
    }

    @objc private func handlePlayerStateDidChange() {
        render()
    }

    @objc private func handleContentSizeCategoryDidChange() {
        refreshForContentSizeCategory()
    }
}

extension LibraryViewController: UICollectionViewDataSource, UICollectionViewDelegate {
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
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        playerService.selectSound(at: indexPath.item)
        navigationController?.pushViewController(
            PlayerViewController(playerService: playerService),
            animated: true
        )
    }
}
