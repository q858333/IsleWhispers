import UIKit
import XCTest
@testable import IsleWhispers

final class RecentSoundsViewControllerTests: XCTestCase {
    @MainActor
    func testRecentPageAndCellsUseInjectedLanguageBundle() throws {
        let expectations: [(String, String, String, String, String, String, String, String)] = [
            (
                "en", "Recent Sounds", "Recent sounds list", "Close Recent Sounds",
                "No Recent Sounds Yet", "Sounds you play will appear here.",
                "Rain", "Rain: A steady rhythm against the window"
            ),
            (
                "zh-Hans", "最近播放", "最近播放列表", "关闭最近播放",
                "还没有最近播放", "播放声音后会出现在这里",
                "雨声", "雨声：均匀落在窗边"
            ),
            (
                "zh-Hant", "最近播放", "最近播放列表", "關閉最近播放",
                "尚無最近播放", "你播放過的聲音會顯示在這裡。",
                "雨聲", "雨聲：均勻落在窗邊"
            )
        ]

        for expectation in expectations {
            let bundle = try LocalizationTestSupport.bundle(expectation.0)
            let controller = RecentSoundsViewController(
                sounds: [Sound.catalog[2]],
                selectedSoundID: Sound.catalog[2].id,
                localizationBundle: bundle
            )
            layout(controller, size: CGSize(width: 390, height: 844))
            let collection = try XCTUnwrap(findCollectionView(in: controller.view))
            let cell = try XCTUnwrap(
                controller.collectionView(
                    collection,
                    cellForItemAt: IndexPath(item: 0, section: 0)
                ) as? RecentSoundCell
            )

            XCTAssertNotNil(findLabel(text: expectation.1, in: controller.view), expectation.0)
            XCTAssertEqual(collection.accessibilityLabel, expectation.2, expectation.0)
            XCTAssertNotNil(findButton(label: expectation.3, in: controller.view), expectation.0)
            XCTAssertNotNil(findLabel(text: expectation.6, in: cell), expectation.0)
            XCTAssertEqual(cell.accessibilityLabel, expectation.7, expectation.0)
            XCTAssertTrue(
                cell.accessibilityTraits.contains(UIAccessibilityTraits.selected),
                expectation.0
            )

            let emptyController = RecentSoundsViewController(
                sounds: [],
                selectedSoundID: Sound.catalog[2].id,
                localizationBundle: bundle
            )
            emptyController.loadViewIfNeeded()
            XCTAssertNotNil(
                findLabel(text: expectation.4, in: emptyController.view),
                expectation.0
            )
            XCTAssertNotNil(
                findLabel(text: expectation.5, in: emptyController.view),
                expectation.0
            )
        }
    }

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
    func testEmptyRecentsShowsAccessibleEmptyState() throws {
        let controller = RecentSoundsViewController(
            sounds: [],
            selectedSoundID: Sound.catalog[2].id,
            localizationBundle: try LocalizationTestSupport.bundle("zh-Hans")
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
