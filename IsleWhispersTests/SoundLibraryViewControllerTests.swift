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
}
