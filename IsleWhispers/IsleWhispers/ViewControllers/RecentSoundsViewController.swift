import SnapKit
import UIKit

final class RecentSoundsViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    var onSelect: ((Sound) -> Void)?
    var onClose: (() -> Void)?

    private let sounds: [Sound]
    private let selectedSoundID: String
    private let localizationBundle: Bundle
    private let backgroundGradient = CAGradientLayer()
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let emptyTitleLabel = UILabel()
    private let emptyDetailLabel = UILabel()
    private let emptyStack = UIStackView()
    private let emptyScrollView = UIScrollView()
    private let emptyContentView = UIView()

    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: makeCollectionLayout()
        )
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.accessibilityLabel = L10n.text(
            "recent.list.label",
            bundle: localizationBundle
        )
        collectionView.register(
            RecentSoundCell.self,
            forCellWithReuseIdentifier: RecentSoundCell.reuseIdentifier
        )
        return collectionView
    }()

    init(
        sounds: [Sound],
        selectedSoundID: String,
        localizationBundle: Bundle = .main
    ) {
        self.sounds = sounds
        self.selectedSoundID = selectedSoundID
        self.localizationBundle = localizationBundle
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor(red: 0.16, green: 0.09, blue: 0.06, alpha: 1)
        view.accessibilityViewIsModal = true
        setupBackground()
        setupHeader()
        setupCollectionView()
        setupEmptyState()
        render()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradient.frame = view.bounds
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.preferredContentSizeCategory
            != traitCollection.preferredContentSizeCategory
        else { return }

        collectionView.setCollectionViewLayout(makeCollectionLayout(), animated: false)
        collectionView.reloadData()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sounds.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: RecentSoundCell.reuseIdentifier,
            for: indexPath
        )
        guard let recentCell = cell as? RecentSoundCell else { return cell }
        let sound = sounds[indexPath.item]
        recentCell.configure(
            sound: sound,
            selected: sound.id == selectedSoundID,
            localizationBundle: localizationBundle
        )
        return recentCell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelect?(sounds[indexPath.item])
    }

    @objc private func closeButtonTapped() {
        onClose?()
    }

    private func setupBackground() {
        backgroundGradient.colors = [
            UIColor(red: 0.38, green: 0.22, blue: 0.14, alpha: 1).cgColor,
            UIColor(red: 0.12, green: 0.06, blue: 0.04, alpha: 1).cgColor
        ]
        backgroundGradient.startPoint = CGPoint(x: 0, y: 0)
        backgroundGradient.endPoint = CGPoint(x: 1, y: 1)

        let gradientView = UIView()
        gradientView.isUserInteractionEnabled = false
        gradientView.layer.addSublayer(backgroundGradient)
        view.addSubview(gradientView)
        gradientView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    private func setupHeader() {
        titleLabel.text = L10n.text("recent.title", bundle: localizationBundle)
        titleLabel.font = AppTheme.font(.largeTitle, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping

        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        closeButton.applyRoundedCorners(radius: 22)
        closeButton.setImage(
            UIImage(
                systemName: "xmark",
                withConfiguration: AppTheme.symbolConfiguration(pointSize: 17, weight: .bold)
            ),
            for: .normal
        )
        closeButton.accessibilityLabel = L10n.text("recent.close", bundle: localizationBundle)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)

        view.addSubview(titleLabel)
        view.addSubview(closeButton)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.trailing.lessThanOrEqualTo(closeButton.snp.leading).offset(-12)
        }
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(14)
            make.trailing.equalTo(view.safeAreaLayoutGuide).inset(20)
            make.size.equalTo(44)
        }
    }

    private func setupCollectionView() {
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(24)
            make.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func setupEmptyState() {
        emptyTitleLabel.text = L10n.text("recent.empty.title", bundle: localizationBundle)
        emptyTitleLabel.font = AppTheme.font(.title2, weight: .bold)
        emptyTitleLabel.textColor = .white
        emptyTitleLabel.adjustsFontForContentSizeCategory = true
        emptyTitleLabel.textAlignment = .center
        emptyTitleLabel.numberOfLines = 0
        emptyTitleLabel.lineBreakMode = .byWordWrapping

        emptyDetailLabel.text = L10n.text("recent.empty.detail", bundle: localizationBundle)
        emptyDetailLabel.font = AppTheme.font(.body)
        emptyDetailLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        emptyDetailLabel.adjustsFontForContentSizeCategory = true
        emptyDetailLabel.textAlignment = .center
        emptyDetailLabel.numberOfLines = 0

        emptyStack.axis = .vertical
        emptyStack.alignment = .fill
        emptyStack.spacing = 8
        emptyStack.addArrangedSubview(emptyTitleLabel)
        emptyStack.addArrangedSubview(emptyDetailLabel)
        emptyScrollView.alwaysBounceVertical = true
        view.addSubview(emptyScrollView)
        emptyScrollView.addSubview(emptyContentView)
        emptyContentView.addSubview(emptyStack)
        emptyScrollView.snp.makeConstraints { make in
            make.edges.equalTo(collectionView)
        }
        emptyContentView.snp.makeConstraints { make in
            make.edges.equalTo(emptyScrollView.contentLayoutGuide)
            make.width.equalTo(emptyScrollView.frameLayoutGuide)
            make.height.greaterThanOrEqualTo(emptyScrollView.frameLayoutGuide)
            make.height.equalTo(emptyScrollView.frameLayoutGuide).priority(.low)
        }
        emptyStack.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.greaterThanOrEqualToSuperview().offset(32)
            make.bottom.lessThanOrEqualToSuperview().offset(-32)
        }
    }

    private func render() {
        let isEmpty = sounds.isEmpty
        collectionView.isHidden = isEmpty
        emptyScrollView.isHidden = !isEmpty
    }

    private func makeCollectionLayout() -> UICollectionViewLayout {
        let isAccessibilityCategory = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / 3.0),
            heightDimension: .fractionalHeight(1)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalWidth(isAccessibilityCategory ? 0.76 : 0.62)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 3)
        group.interItemSpacing = .fixed(10)

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 16
        section.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        return UICollectionViewCompositionalLayout(section: section)
    }
}
