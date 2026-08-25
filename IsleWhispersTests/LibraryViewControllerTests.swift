import UIKit
import XCTest
@testable import IsleWhispers

final class LibraryViewControllerTests: XCTestCase {
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
}
