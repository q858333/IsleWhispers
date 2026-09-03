import UIKit
import XCTest
@testable import IsleWhispers

final class SoundLibraryViewControllerTests: XCTestCase {
    @MainActor
    func testShowsOrderedGroupsAndAllFifteenSounds() throws {
        let controller = SoundLibraryViewController(
            selectedSoundID: Sound.catalog[2].id,
            localizationBundle: try LocalizationTestSupport.bundle("zh-Hans")
        )
        controller.loadViewIfNeeded()

        XCTAssertEqual(controller.sectionTitles, ["自然", "生活", "氛围"])
        XCTAssertEqual(controller.sectionItemCounts, [7, 5, 3])
        XCTAssertEqual(controller.sectionItemCounts.reduce(0, +), 15)
    }

    @MainActor
    func testEnglishLibraryUsesLocalizedTitleGroupsAndCards() throws {
        let bundle = try LocalizationTestSupport.bundle("en")
        let controller = SoundLibraryViewController(
            selectedSoundID: Sound.catalog[2].id,
            localizationBundle: bundle
        )

        try assertLocalizedLibrary(
            controller,
            title: "Sound Library",
            listLabel: "Sound library",
            groups: ["Nature", "Everyday", "Atmosphere"],
            firstCard: ("Thunder", "A deep rumble in the distance"),
            firstAccessibilityLabel: "Thunder: A deep rumble in the distance",
            lastCard: ("Space", "A wide, weightless ambience"),
            lastAccessibilityLabel: "Space: A wide, weightless ambience"
        )
    }

    @MainActor
    func testSimplifiedChineseLibraryUsesLocalizedTitleGroupsAndCards() throws {
        let bundle = try LocalizationTestSupport.bundle("zh-Hans")
        let controller = SoundLibraryViewController(
            selectedSoundID: Sound.catalog[2].id,
            localizationBundle: bundle
        )

        try assertLocalizedLibrary(
            controller,
            title: "声音库",
            listLabel: "声音库",
            groups: ["自然", "生活", "氛围"],
            firstCard: ("雷声", "低沉而遥远"),
            firstAccessibilityLabel: "雷声：低沉而遥远",
            lastCard: ("太空", "宽阔漂浮氛围"),
            lastAccessibilityLabel: "太空：宽阔漂浮氛围"
        )
    }

    @MainActor
    func testTraditionalChineseLibraryUsesLocalizedTitleGroupsAndCards() throws {
        let bundle = try LocalizationTestSupport.bundle("zh-Hant")
        let controller = SoundLibraryViewController(
            selectedSoundID: Sound.catalog[2].id,
            localizationBundle: bundle
        )

        try assertLocalizedLibrary(
            controller,
            title: "聲音庫",
            listLabel: "聲音庫",
            groups: ["自然", "日常", "氛圍"],
            firstCard: ("雷聲", "低沉而遙遠"),
            firstAccessibilityLabel: "雷聲：低沉而遙遠",
            lastCard: ("太空", "寬闊無重力的氛圍"),
            lastAccessibilityLabel: "太空：寬闊無重力的氛圍"
        )
    }

    @MainActor
    func testEnglishCardsRemainReadableAt320WidthAndAccessibilitySize() throws {
        for language in ["en", "zh-Hant"] {
            let controller = SoundLibraryViewController(
                selectedSoundID: Sound.catalog[2].id,
                localizationBundle: try LocalizationTestSupport.bundle(language)
            )
            let host = UIViewController()
            host.loadViewIfNeeded()
            host.addChild(controller)
            host.setOverrideTraitCollection(
                UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
                forChild: controller
            )
            host.view.addSubview(controller.view)
            controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
            controller.didMove(toParent: host)
            controller.view.layoutIfNeeded()

            let collectionView = try XCTUnwrap(findCollectionView(in: controller.view))
            collectionView.layoutIfNeeded()
            XCTAssertGreaterThan(collectionView.contentSize.height, collectionView.bounds.height)

            let expectedPageTitle = language == "en" ? "Sound Library" : "聲音庫"
            let pageTitle = try XCTUnwrap(
                labels(in: controller.view).first { $0.text == expectedPageTitle }
            )
            XCTAssertEqual(pageTitle.numberOfLines, 0)
            XCTAssertEqual(pageTitle.lineBreakMode, .byWordWrapping)
            assertLabelFits(pageTitle, inside: controller.view)

            let firstCell: UICollectionViewCell = try XCTUnwrap(
                collectionView.cellForItem(at: IndexPath(item: 0, section: 0))
            )
            let cardLabels = labels(in: firstCell.contentView)
            XCTAssertEqual(cardLabels.count, 2)
            XCTAssertTrue(cardLabels.allSatisfy { $0.numberOfLines == 0 })
            for label in cardLabels {
                assertLabelFits(label, inside: firstCell.contentView)
            }
        }
    }

    @MainActor
    func testSelectingCardReportsCatalogIndex() {
        let controller = SoundLibraryViewController(selectedSoundID: Sound.catalog[2].id)
        var selectedIndex: Int?
        controller.onSelect = { selectedIndex = $0 }
        controller.loadViewIfNeeded()

        controller.selectItemForTesting(section: 1, item: 2)

        XCTAssertEqual(selectedIndex, 10)
    }

    @MainActor
    func testDefaultUsesTwoColumnsAndAccessibilityUsesOne() {
        let controller = SoundLibraryViewController(selectedSoundID: Sound.catalog[2].id)

        XCTAssertEqual(controller.columnCount(for: .large), 2)
        XCTAssertEqual(controller.columnCount(for: .accessibilityExtraExtraExtraLarge), 1)
    }

    @MainActor
    func testTwoColumnCardContentMatchesCellBounds() throws {
        let controller = SoundLibraryViewController(selectedSoundID: Sound.catalog[2].id)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.view.layoutIfNeeded()

        let collectionView = try XCTUnwrap(findCollectionView(in: controller.view))
        collectionView.layoutIfNeeded()
        let firstCell = try XCTUnwrap(collectionView.cellForItem(at: IndexPath(item: 0, section: 0)))

        XCTAssertEqual(firstCell.contentView.frame.minX, firstCell.bounds.minX, accuracy: 0.5)
        XCTAssertEqual(firstCell.contentView.frame.minY, firstCell.bounds.minY, accuracy: 0.5)
        XCTAssertEqual(firstCell.contentView.frame.width, firstCell.bounds.width, accuracy: 0.5)
        XCTAssertEqual(firstCell.contentView.frame.height, firstCell.bounds.height, accuracy: 0.5)
    }

    @MainActor
    func testLogoGradientFillsLibraryBackground() throws {
        let controller = SoundLibraryViewController(selectedSoundID: Sound.catalog[2].id)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.view.layoutIfNeeded()

        let gradient = try XCTUnwrap(
            controller.view.layer.sublayers?.compactMap { $0 as? CAGradientLayer }.first
        )
        let colors = try XCTUnwrap(gradient.colors as? [CGColor])

        XCTAssertEqual(gradient.frame, controller.view.bounds)
        XCTAssertEqual(gradient.startPoint, CGPoint(x: 0.5, y: 0))
        XCTAssertEqual(gradient.endPoint, CGPoint(x: 0.5, y: 1))
        XCTAssertEqual(colors.count, 2)
        XCTAssertEqual(colors[0], UIColor(red: 186 / 255, green: 141 / 255, blue: 142 / 255, alpha: 1).cgColor)
        XCTAssertEqual(colors[1], UIColor(red: 250 / 255, green: 242 / 255, blue: 217 / 255, alpha: 1).cgColor)
    }

    private func findCollectionView(in view: UIView) -> UICollectionView? {
        if let collectionView = view as? UICollectionView {
            return collectionView
        }
        return view.subviews.lazy.compactMap(findCollectionView(in:)).first
    }

    @MainActor
    private func assertLocalizedLibrary(
        _ controller: SoundLibraryViewController,
        title: String,
        listLabel: String,
        groups: [String],
        firstCard: (String, String),
        firstAccessibilityLabel: String,
        lastCard: (String, String),
        lastAccessibilityLabel: String
    ) throws {
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.view.layoutIfNeeded()

        XCTAssertTrue(labels(in: controller.view).contains { $0.text == title })
        let collectionView = try XCTUnwrap(findCollectionView(in: controller.view))
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        XCTAssertEqual(collectionView.accessibilityLabel, listLabel)
        XCTAssertEqual(controller.sectionTitles, groups)
        XCTAssertEqual(try sectionHeaderTitles(for: controller), groups)

        assertCard(
            controller,
            collectionView: collectionView,
            indexPath: IndexPath(item: 0, section: 0),
            expected: firstCard,
            accessibilityLabel: firstAccessibilityLabel
        )
        assertCard(
            controller,
            collectionView: collectionView,
            indexPath: IndexPath(item: 2, section: 2),
            expected: lastCard,
            accessibilityLabel: lastAccessibilityLabel
        )
    }

    @MainActor
    private func assertCard(
        _ controller: SoundLibraryViewController,
        collectionView: UICollectionView,
        indexPath: IndexPath,
        expected: (String, String),
        accessibilityLabel: String
    ) {
        let cell = controller.collectionView(collectionView, cellForItemAt: indexPath)
        let expectedTexts = Set([expected.0, expected.1])

        XCTAssertEqual(Set(labels(in: cell.contentView).compactMap(\.text)), expectedTexts)
        XCTAssertEqual(cell.accessibilityLabel, accessibilityLabel)
    }

    private func labels(in view: UIView) -> [UILabel] {
        let directLabels = view.subviews.compactMap { $0 as? UILabel }
        return directLabels + view.subviews.flatMap(labels(in:))
    }

    @MainActor
    private func sectionHeaderTitles(for controller: SoundLibraryViewController) throws -> [String] {
        let collectionView = SupplementaryViewCollection()
        return try SoundCategory.allCases.indices.map { section in
            let header = controller.collectionView(
                collectionView,
                viewForSupplementaryElementOfKind: UICollectionView.elementKindSectionHeader,
                at: IndexPath(item: 0, section: section)
            )
            return try XCTUnwrap(header.subviews.compactMap { $0 as? UILabel }.first?.text)
        }
    }

    private func assertLabelFits(_ label: UILabel, inside container: UIView) {
        let labelFrame = container.convert(label.bounds, from: label)
        XCTAssertTrue(container.bounds.contains(labelFrame))
        let fittingSize = label.sizeThatFits(
            CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)
        )
        XCTAssertLessThanOrEqual(fittingSize.height, label.bounds.height + 0.5)
    }
}

private final class SupplementaryViewCollection: UICollectionView {
    init() {
        super.init(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func dequeueReusableSupplementaryView(
        ofKind elementKind: String,
        withReuseIdentifier identifier: String,
        for indexPath: IndexPath
    ) -> UICollectionReusableView {
        UICollectionReusableView()
    }
}
