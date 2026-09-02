import UIKit
import XCTest
@testable import IsleWhispers

final class SoundLibraryViewControllerTests: XCTestCase {
    @MainActor
    func testShowsOrderedGroupsAndAllFifteenSounds() {
        let controller = SoundLibraryViewController(selectedSoundID: Sound.catalog[2].id)
        controller.loadViewIfNeeded()

        XCTAssertEqual(controller.sectionTitles, ["nature", "life", "atmosphere"])
        XCTAssertEqual(controller.sectionItemCounts, [7, 5, 3])
        XCTAssertEqual(controller.sectionItemCounts.reduce(0, +), 15)
    }

    @MainActor
    func testSelectingCardReportsCatalogIndex() {
        let controller = SoundLibraryViewController(selectedSoundID: Sound.catalog[2].id)
        var selectedIndex: Int?
        controller.onSelect = { selectedIndex = $0 }
        controller.loadViewIfNeeded()

        controller.selectItemForTesting(section: 1, item: 2)

        XCTAssertEqual(selectedIndex, Sound.catalog.firstIndex { $0.title == "游艇" })
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
}
