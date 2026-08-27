import UIKit
import XCTest
@testable import IsleWhispers

final class SoundLibraryViewControllerTests: XCTestCase {
    @MainActor
    func testShowsOrderedGroupsAndAllFifteenSounds() {
        let controller = SoundLibraryViewController(selectedSoundID: Sound.catalog[2].id)
        controller.loadViewIfNeeded()

        XCTAssertEqual(controller.sectionTitles, ["自然", "生活", "氛围"])
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

    private func findCollectionView(in view: UIView) -> UICollectionView? {
        if let collectionView = view as? UICollectionView {
            return collectionView
        }
        return view.subviews.lazy.compactMap(findCollectionView(in:)).first
    }
}
