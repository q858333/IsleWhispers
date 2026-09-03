import UIKit
import XCTest
@testable import IsleWhispers

final class RecentSoundsViewControllerTests: XCTestCase {
    @MainActor
    func testAllLanguagesTitlesFitAndEmptyStateRemainsReachableAt320By568WithAXXXL() throws {
        let expectations = [
            ("en", "Recent Sounds", "Close Recent Sounds", "No Recent Sounds Yet", "Sounds you play will appear here."),
            ("zh-Hans", "最近播放", "关闭最近播放", "还没有最近播放", "播放声音后会出现在这里"),
            ("zh-Hant", "最近播放", "關閉最近播放", "尚無最近播放", "你播放過的聲音會顯示在這裡。")
        ]

        for (language, pageTitle, closeLabel, emptyTitle, emptyDetail) in expectations {
            let controller = RecentSoundsViewController(
                sounds: [],
                selectedSoundID: Sound.catalog[2].id,
                localizationBundle: try LocalizationTestSupport.bundle(language)
            )
            let host = UIViewController()
            let traits = UITraitCollection(
                preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge
            )
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer { window.isHidden = true }

            host.addChild(controller)
            host.setOverrideTraitCollection(traits, forChild: controller)
            traits.performAsCurrent {
                host.view.addSubview(controller.view)
            }
            controller.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                controller.view.topAnchor.constraint(equalTo: host.view.topAnchor),
                controller.view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
                controller.view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
                controller.view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor)
            ])
            controller.didMove(toParent: host)
            layout(host, size: window.bounds.size)

            XCTAssertEqual(
                controller.traitCollection.preferredContentSizeCategory,
                .accessibilityExtraExtraExtraLarge,
                language
            )
            let titleLabel = try XCTUnwrap(findLabel(text: pageTitle, in: controller.view))
            let closeButton = try XCTUnwrap(findButton(label: closeLabel, in: controller.view))
            let emptyTitleLabel = try XCTUnwrap(findLabel(text: emptyTitle, in: controller.view))
            let emptyDetailLabel = try XCTUnwrap(findLabel(text: emptyDetail, in: controller.view))

            assertMultilineLabelFits(titleLabel, language: language)
            assertMultilineLabelFits(emptyTitleLabel, language: language)
            assertLabelFits(emptyDetailLabel, language: language)

            let titleFrame = titleLabel.convert(titleLabel.bounds, to: controller.view)
            let closeFrame = closeButton.convert(closeButton.bounds, to: controller.view)
            XCTAssertFalse(
                titleFrame.intersects(closeFrame),
                "\(language) page title intersects close button"
            )

            let emptyScrollView = try XCTUnwrap(
                ancestor(UIScrollView.self, of: emptyTitleLabel),
                "\(language) empty state must live in a scroll view"
            )
            XCTAssertTrue(emptyDetailLabel.isDescendant(of: emptyScrollView), language)
            XCTAssertTrue(emptyScrollView.alwaysBounceVertical, language)
            XCTAssertGreaterThanOrEqual(
                emptyScrollView.contentSize.height,
                emptyScrollView.bounds.height,
                language
            )
            emptyScrollView.contentOffset = CGPoint(
                x: 0,
                y: max(0, emptyScrollView.contentSize.height - emptyScrollView.bounds.height)
            )
            emptyScrollView.layoutIfNeeded()
            let detailFrame = emptyDetailLabel.convert(emptyDetailLabel.bounds, to: emptyScrollView)
            XCTAssertLessThanOrEqual(
                detailFrame.maxY,
                emptyScrollView.bounds.maxY + 0.5,
                "\(language) empty-state detail is unreachable after scrolling"
            )
        }
    }

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

    private func ancestor<T: UIView>(_ type: T.Type, of view: UIView) -> T? {
        var candidate = view.superview
        while let current = candidate {
            if let match = current as? T { return match }
            candidate = current.superview
        }
        return nil
    }

    private func assertMultilineLabelFits(
        _ label: UILabel,
        language: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(label.numberOfLines, 0, language, file: file, line: line)
        XCTAssertEqual(label.lineBreakMode, .byWordWrapping, language, file: file, line: line)
        assertLabelFits(label, language: language, file: file, line: line)
    }

    private func assertLabelFits(
        _ label: UILabel,
        language: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThan(label.bounds.width, 0, language, file: file, line: line)
        let fittingSize = label.sizeThatFits(
            CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)
        )
        XCTAssertLessThanOrEqual(
            fittingSize.width,
            label.bounds.width + 0.5,
            language,
            file: file,
            line: line
        )
        XCTAssertLessThanOrEqual(
            fittingSize.height,
            label.bounds.height + 0.5,
            language,
            file: file,
            line: line
        )
    }

    private func descendants(in root: UIView) -> [UIView] {
        [root] + root.subviews.flatMap(descendants(in:))
    }
}
