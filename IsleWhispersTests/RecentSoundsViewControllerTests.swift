import UIKit
import XCTest
@testable import IsleWhispers

final class RecentSoundsViewControllerTests: XCTestCase {
    @MainActor
    func testShowsSixRecentSoundsInThreeColumnsAndReportsSelection() throws {
        let sounds = Array(Sound.catalog.prefix(6))
        let controller = RecentSoundsViewController(
            sounds: sounds,
            selectedSoundID: sounds[2].id
        )
        var selected: Sound?
        controller.onSelect = { selected = $0 }
        layout(controller, size: CGSize(width: 390, height: 844))

        let collection = try XCTUnwrap(findCollectionView(in: controller.view))
        XCTAssertEqual(collection.numberOfItems(inSection: 0), 6)
        let frames = (0..<3).compactMap {
            collection.collectionViewLayout.layoutAttributesForItem(
                at: IndexPath(item: $0, section: 0)
            )?.frame
        }
        XCTAssertEqual(frames.count, 3)
        XCTAssertEqual(frames[0].minY, frames[1].minY, accuracy: 1)
        XCTAssertEqual(frames[1].minY, frames[2].minY, accuracy: 1)

        controller.collectionView(collection, didSelectItemAt: IndexPath(item: 4, section: 0))
        XCTAssertEqual(selected, sounds[4])
    }

    @MainActor
    func testEmptyRecentsShowsAccessibleEmptyState() {
        let controller = RecentSoundsViewController(
            sounds: [],
            selectedSoundID: Sound.catalog[2].id
        )
        controller.loadViewIfNeeded()

        XCTAssertNotNil(findLabel(text: "还没有最近播放", in: controller.view))
        XCTAssertNotNil(findButton(label: "关闭最近播放", in: controller.view))
    }

    @MainActor
    private func layout(_ controller: UIViewController, size: CGSize) {
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(origin: .zero, size: size)
        for _ in 0..<3 {
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
        }
    }

    private func findCollectionView(in root: UIView) -> UICollectionView? {
        descendants(in: root).compactMap { $0 as? UICollectionView }.first
    }

    private func findLabel(text: String, in root: UIView) -> UILabel? {
        descendants(in: root)
            .compactMap { $0 as? UILabel }
            .first { $0.text == text }
    }

    private func findButton(label: String, in root: UIView) -> UIButton? {
        descendants(in: root)
            .compactMap { $0 as? UIButton }
            .first { $0.accessibilityLabel == label }
    }

    private func descendants(in root: UIView) -> [UIView] {
        [root] + root.subviews.flatMap(descendants(in:))
    }
}
