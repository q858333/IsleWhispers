import UIKit
import XCTest
@testable import IsleWhispers

final class LibraryViewControllerTests: XCTestCase {
    @MainActor
    func testAccentBackedLibraryControlsMeetContrastInLightAndDark() throws {
        let (controller, _, cleanup) = makeController()
        defer { cleanup() }
        let host = UIViewController()
        host.addChild(controller)
        host.view.addSubview(controller.view)
        controller.didMove(toParent: host)
        layout(controller: controller, host: host, size: CGSize(width: 720, height: 900))

        let accentButtons = [
            try XCTUnwrap(button(labelled: "播放", in: controller.view)),
            try XCTUnwrap(button(labelled: "睡眠定时：不限", in: controller.view))
        ]
        for button in accentButtons {
            XCTAssertTrue(button.backgroundColor?.isEqual(AppTheme.accent) == true)
        }

        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let background = AppTheme.accent.resolvedColor(with: traits)
            for button in accentButtons {
                let foreground: UIColor
                if button.currentImage == nil {
                    foreground = try XCTUnwrap(button.titleColor(for: .normal))
                } else {
                    foreground = try XCTUnwrap(button.tintColor)
                }
                XCTAssertGreaterThanOrEqual(
                    contrastRatio(foreground.resolvedColor(with: traits), background),
                    4.5
                )
            }
        }
    }

    @MainActor
    func testLayoutSwitchesFromThreeColumnsToOneColumnAtRegularWidth() throws {
        let (controller, _, cleanup) = makeController()
        defer { cleanup() }

        let host = UIViewController()
        host.addChild(controller)
        host.view.addSubview(controller.view)
        controller.didMove(toParent: host)

        layout(controller: controller, host: host, size: CGSize(width: 719, height: 900))
        let collectionView = try XCTUnwrap(findSubview(of: UICollectionView.self, in: controller.view))
        let compactFrames = try frames(for: 0...3, in: collectionView)
        XCTAssertEqual(compactFrames[0].minY, compactFrames[1].minY, accuracy: 1)
        XCTAssertEqual(compactFrames[1].minY, compactFrames[2].minY, accuracy: 1)
        XCTAssertGreaterThan(compactFrames[3].minY, compactFrames[0].minY)
        XCTAssertEqual(activeConstraintCount(constant: 290, in: controller.view), 0)

        layout(controller: controller, host: host, size: CGSize(width: 720, height: 900))
        let regularFrames = try frames(for: 0...1, in: collectionView)
        XCTAssertGreaterThan(regularFrames[1].minY, regularFrames[0].minY)
        XCTAssertEqual(activeConstraintCount(constant: 290, in: controller.view), 1)

        layout(controller: controller, host: host, size: CGSize(width: 719, height: 900))
        XCTAssertEqual(activeConstraintCount(constant: 290, in: controller.view), 0)
        let returnedCompactFrames = try frames(for: 0...3, in: collectionView)
        XCTAssertEqual(returnedCompactFrames[0].minY, returnedCompactFrames[1].minY, accuracy: 1)
        XCTAssertEqual(returnedCompactFrames[1].minY, returnedCompactFrames[2].minY, accuracy: 1)
        XCTAssertGreaterThan(returnedCompactFrames[3].minY, returnedCompactFrames[0].minY)
    }

    @MainActor
    func testContentSizeCategoryNotificationRefreshesVisibleSoundCells() throws {
        let (controller, _, cleanup) = makeController()
        defer { cleanup() }

        let host = UIViewController()
        host.addChild(controller)
        host.view.addSubview(controller.view)
        controller.didMove(toParent: host)
        layout(controller: controller, host: host, size: CGSize(width: 390, height: 844))

        let collectionView = try XCTUnwrap(findSubview(of: UICollectionView.self, in: controller.view))
        let indexPath = IndexPath(item: 0, section: 0)
        let visibleCell = try XCTUnwrap(collectionView.cellForItem(at: indexPath))
        visibleCell.accessibilityLabel = "stale"

        NotificationCenter.default.post(
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
        layout(controller: controller, host: host, size: CGSize(width: 390, height: 844))

        let refreshedCell = try XCTUnwrap(collectionView.cellForItem(at: indexPath))
        XCTAssertEqual(
            refreshedCell.accessibilityLabel,
            "\(Sound.catalog[0].title)：\(Sound.catalog[0].subtitle)"
        )
    }

    @MainActor
    func testAccessibilityFontChangeIncreasesCompactSoundCellHeightAfterProductionRefresh() throws {
        let (controller, _, cleanup) = makeController()
        defer { cleanup() }

        let host = UIViewController()
        host.addChild(controller)
        host.view.addSubview(controller.view)
        controller.didMove(toParent: host)
        layout(controller: controller, host: host, size: CGSize(width: 390, height: 844))

        let collectionView = try XCTUnwrap(findSubview(of: UICollectionView.self, in: controller.view))
        let normalHeight = try itemHeight(at: 0, in: collectionView)

        host.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            forChild: controller
        )
        layout(controller: controller, host: host, size: CGSize(width: 390, height: 844))
        XCTAssertEqual(
            controller.traitCollection.preferredContentSizeCategory,
            .accessibilityExtraExtraExtraLarge
        )
        descendants(in: collectionView).compactMap { $0 as? UILabel }.forEach {
            $0.font = UIFont.systemFont(ofSize: 44, weight: .semibold)
        }

        NotificationCenter.default.post(
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
        layout(controller: controller, host: host, size: CGSize(width: 390, height: 844))

        let accessibilityHeight = try itemHeight(at: 0, in: collectionView)
        XCTAssertGreaterThan(accessibilityHeight, normalHeight)
    }

    @MainActor
    func testRegularPlayerPaneScrollsInShortAccessibilityHeight() throws {
        let (controller, service, cleanup) = makeController()
        defer { cleanup() }

        let host = UIViewController()
        host.addChild(controller)
        host.view.addSubview(controller.view)
        controller.didMove(toParent: host)
        host.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            forChild: controller
        )
        layout(controller: controller, host: host, size: CGSize(width: 720, height: 360))
        XCTAssertEqual(
            controller.traitCollection.preferredContentSizeCategory,
            .accessibilityExtraExtraExtraLarge
        )

        let playerScrollView = try XCTUnwrap(
            descendants(in: controller.view)
                .compactMap { $0 as? UIScrollView }
                .first { !($0 is UICollectionView) }
        )
        XCTAssertGreaterThan(playerScrollView.contentSize.height, playerScrollView.bounds.height)

        for label in ["上一种声音", "播放", "下一种声音", "睡眠定时：60 分钟"] {
            let control = try XCTUnwrap(button(labelled: label, in: controller.view))
            XCTAssertTrue(control.isDescendant(of: playerScrollView))
        }
        let status = try XCTUnwrap(
            descendants(in: controller.view)
                .compactMap { $0 as? UILabel }
                .first { $0.text == service.statusMessage }
        )
        XCTAssertTrue(status.isDescendant(of: playerScrollView))
    }

    @MainActor
    func testSelectingSoundUpdatesServiceAndPushesPlayerScreen() throws {
        let (controller, service, cleanup) = makeController()
        defer { cleanup() }
        let navigationController = UINavigationController(rootViewController: controller)

        layout(controller: controller, host: navigationController, size: CGSize(width: 390, height: 844))
        let collectionView = try XCTUnwrap(findSubview(of: UICollectionView.self, in: controller.view))
        controller.collectionView(collectionView, didSelectItemAt: IndexPath(item: 4, section: 0))

        XCTAssertEqual(service.selectedIndex, 4)
        XCTAssertTrue(navigationController.topViewController is PlayerViewController)
    }

    @MainActor
    func testPreviousAndNextControlsChangeSelection() throws {
        let (controller, service, cleanup) = makeController()
        defer { cleanup() }
        let host = UIViewController()
        host.addChild(controller)
        host.view.addSubview(controller.view)
        controller.didMove(toParent: host)
        layout(controller: controller, host: host, size: CGSize(width: 390, height: 844))

        let previousButton = try XCTUnwrap(button(labelled: "上一种声音", in: controller.view))
        let nextButton = try XCTUnwrap(button(labelled: "下一种声音", in: controller.view))
        previousButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(service.selectedIndex, 1)
        nextButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(service.selectedIndex, 2)
    }

    @MainActor
    private func makeController() -> (
        LibraryViewController,
        AudioPlayerService,
        () -> Void
    ) {
        let suite = "LibraryViewControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false
        )
        return (
            LibraryViewController(playerService: service),
            service,
            { defaults.removePersistentDomain(forName: suite) }
        )
    }

    @MainActor
    private func layout(
        controller: UIViewController,
        host: UIViewController,
        size: CGSize
    ) {
        host.loadViewIfNeeded()
        host.view.frame = CGRect(origin: .zero, size: size)
        controller.view.frame = host.view.bounds
        for _ in 0..<4 {
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
        }
    }

    private func frames(
        for items: ClosedRange<Int>,
        in collectionView: UICollectionView
    ) throws -> [CGRect] {
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.layoutIfNeeded()
        return try items.map { item in
            try XCTUnwrap(
                collectionView.collectionViewLayout.layoutAttributesForItem(
                    at: IndexPath(item: item, section: 0)
                )?.frame
            )
        }
    }

    private func itemHeight(at item: Int, in collectionView: UICollectionView) throws -> CGFloat {
        collectionView.layoutIfNeeded()
        return try XCTUnwrap(
            collectionView.collectionViewLayout.layoutAttributesForItem(
                at: IndexPath(item: item, section: 0)
            )?.frame.height
        )
    }

    private func activeConstraintCount(constant: CGFloat, in root: UIView) -> Int {
        descendants(in: root)
            .flatMap(\.constraints)
            .filter { $0.isActive && abs($0.constant - constant) < 0.01 }
            .count
    }

    private func button(labelled label: String, in root: UIView) -> UIButton? {
        descendants(in: root)
            .compactMap { $0 as? UIButton }
            .first { $0.accessibilityLabel == label }
    }

    private func findSubview<T: UIView>(of type: T.Type, in root: UIView) -> T? {
        descendants(in: root).compactMap { $0 as? T }.first
    }

    private func descendants(in root: UIView) -> [UIView] {
        [root] + root.subviews.flatMap(descendants(in:))
    }

    private func contrastRatio(_ foreground: UIColor, _ background: UIColor) -> CGFloat {
        let lighter = max(relativeLuminance(foreground), relativeLuminance(background))
        let darker = min(relativeLuminance(foreground), relativeLuminance(background))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return 0.2126 * linearized(red) + 0.7152 * linearized(green) + 0.0722 * linearized(blue)
    }

    private func linearized(_ component: CGFloat) -> CGFloat {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}
