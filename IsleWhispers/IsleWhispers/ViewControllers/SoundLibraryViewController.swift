import SnapKit
import UIKit

final class SoundLibraryViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private struct Section {
        let category: SoundCategory
        let sounds: [Sound]
    }

    var onSelect: ((Int) -> Void)?
    private(set) var selectedSoundID: String
    private let localizationBundle: Bundle

    var sectionTitles: [String] { sections.map { $0.category.title(bundle: localizationBundle) } }
    var sectionItemCounts: [Int] { sections.map { $0.sounds.count } }

    private let sections: [Section] = SoundCategory.allCases.map { category in
        Section(category: category, sounds: Sound.catalogByCategory[category] ?? [])
    }
    private let backgroundGradient = CAGradientLayer()
    private let warmForeground = UIColor(red: 0.27, green: 0.18, blue: 0.18, alpha: 1)
    private let titleLabel = UILabel()

    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: makeCollectionLayout()
        )
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.accessibilityLabel = L10n.text("library.list.label", bundle: localizationBundle)
        collectionView.register(
            LibrarySoundCardCell.self,
            forCellWithReuseIdentifier: LibrarySoundCardCell.reuseIdentifier
        )
        collectionView.register(
            UICollectionReusableView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "SoundLibrarySectionHeader"
        )
        return collectionView
    }()

    init(selectedSoundID: String, localizationBundle: Bundle = .main) {
        self.selectedSoundID = selectedSoundID
        self.localizationBundle = localizationBundle
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
        view.backgroundColor = UIColor(red: 250 / 255, green: 242 / 255, blue: 217 / 255, alpha: 1)
        setupBackground()
        setupHeader()
        setupCollectionView()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradient.frame = view.bounds
    }

    func updateSelectedSound(id: String) {
        guard selectedSoundID != id else { return }
        selectedSoundID = id
        collectionView.reloadData()
    }

    func columnCount(for category: UIContentSizeCategory) -> Int {
        category.isAccessibilityCategory ? 1 : 2
    }

    func selectItemForTesting(section: Int, item: Int) {
        selectSound(at: IndexPath(item: item, section: section))
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].sounds.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: LibrarySoundCardCell.reuseIdentifier,
            for: indexPath
        )
        guard let soundCell = cell as? LibrarySoundCardCell else { return cell }

        let sound = sections[indexPath.section].sounds[indexPath.item]
        soundCell.configure(
            sound: sound,
            selected: sound.id == selectedSoundID,
            localizationBundle: localizationBundle
        )
        return soundCell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: "SoundLibrarySectionHeader",
            for: indexPath
        )
        let label: UILabel
        if let existingLabel = header.subviews.compactMap({ $0 as? UILabel }).first {
            label = existingLabel
        } else {
            label = UILabel()
            label.font = AppTheme.font(.title2, weight: .bold)
            label.textColor = warmForeground
            label.adjustsFontForContentSizeCategory = true
            header.addSubview(label)
            label.snp.makeConstraints { make in
                make.top.equalToSuperview().inset(8)
                make.leading.trailing.bottom.equalToSuperview().inset(16)
            }
        }
        label.text = sectionTitles[indexPath.section]
        return header
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectSound(at: indexPath)
    }

    @objc private func contentSizeCategoryDidChange() {
        collectionView.setCollectionViewLayout(makeCollectionLayout(), animated: false)
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
    }

    private func selectSound(at indexPath: IndexPath) {
        guard
            sections.indices.contains(indexPath.section),
            sections[indexPath.section].sounds.indices.contains(indexPath.item),
            let catalogIndex = Sound.catalog.firstIndex(of: sections[indexPath.section].sounds[indexPath.item])
        else { return }

        onSelect?(catalogIndex)
    }

    private func setupHeader() {
        titleLabel.text = L10n.text("library.title", bundle: localizationBundle)
        titleLabel.font = AppTheme.font(.largeTitle, weight: .bold)
        titleLabel.textColor = warmForeground
        titleLabel.adjustsFontForContentSizeCategory = true

        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(20)
        }
    }

    private func setupBackground() {
        backgroundGradient.colors = [
            UIColor(red: 186 / 255, green: 141 / 255, blue: 142 / 255, alpha: 1).cgColor,
            UIColor(red: 250 / 255, green: 242 / 255, blue: 217 / 255, alpha: 1).cgColor
        ]
        backgroundGradient.startPoint = CGPoint(x: 0.5, y: 0)
        backgroundGradient.endPoint = CGPoint(x: 0.5, y: 1)
        view.layer.insertSublayer(backgroundGradient, at: 0)
    }

    private func setupCollectionView() {
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func makeCollectionLayout() -> UICollectionViewLayout {
        let isAccessibilityCategory = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let columns = columnCount(for: traitCollection.preferredContentSizeCategory)
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / CGFloat(columns)),
            heightDimension: isAccessibilityCategory ? .estimated(280) : .fractionalHeight(1)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: isAccessibilityCategory ? .estimated(280) : .fractionalWidth(0.78)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: columns)
        group.interItemSpacing = .fixed(12)

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(44)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 24, trailing: 16)
        section.boundarySupplementaryItems = [header]
        return UICollectionViewCompositionalLayout(section: section)
    }
}
