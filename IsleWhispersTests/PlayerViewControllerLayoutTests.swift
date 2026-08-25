import UIKit
import XCTest
@testable import IsleWhispers

final class PlayerViewControllerLayoutTests: XCTestCase {
    @MainActor
    func testRegularMainAreaScrollsAtShortAccessibilityHeight() throws {
        let suite = "PlayerViewControllerLayoutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let service = AudioPlayerService(defaults: defaults, configureSystemIntegration: false)
        let player = PlayerViewController(playerService: service)
        let host = UIViewController()
        host.addChild(player)
        host.view.addSubview(player.view)
        player.didMove(toParent: host)
        host.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            forChild: player
        )

        layout(player: player, host: host, size: CGSize(width: 720, height: 360))

        let playButton = try XCTUnwrap(button(labelled: "播放", in: player.view))
        let mainScrollView = try XCTUnwrap(
            ancestors(of: playButton).compactMap { $0 as? UIScrollView }.first
        )
        XCTAssertGreaterThan(mainScrollView.contentSize.height, mainScrollView.bounds.height)
        XCTAssertTrue(playButton.isDescendant(of: mainScrollView))
        XCTAssertTrue(try XCTUnwrap(button(labelled: "返回", in: player.view)).isDescendant(of: mainScrollView))
    }

    @MainActor
    func testSleepTimerButtonsReflowAndFitAtNarrowAccessibilityWidth() throws {
        let suite = "PlayerViewControllerLayoutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let service = AudioPlayerService(defaults: defaults, configureSystemIntegration: false)
        let player = PlayerViewController(playerService: service)
        let host = UIViewController()
        host.addChild(player)
        host.view.addSubview(player.view)
        player.didMove(toParent: host)
        host.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            forChild: player
        )
        layout(player: player, host: host, size: CGSize(width: 720, height: 360))

        let timerView = try XCTUnwrap(
            descendants(in: player.view).compactMap { $0 as? SleepTimerView }.first
        )
        XCTAssertLessThan(timerView.bounds.width, 320)
        timerView.setNeedsLayout()
        timerView.layoutIfNeeded()

        let buttons = descendants(in: timerView).compactMap { $0 as? UIButton }
        XCTAssertEqual(buttons.count, 4)
        let rowPositions = Set(buttons.map {
            round($0.convert($0.bounds, to: timerView).minY)
        })
        XCTAssertGreaterThanOrEqual(rowPositions.count, 2)
        for button in buttons {
            XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
            let titleLabel = try XCTUnwrap(button.titleLabel)
            XCTAssertGreaterThanOrEqual(titleLabel.bounds.width + 1, titleLabel.intrinsicContentSize.width)
            XCTAssertFalse(titleLabel.text?.isEmpty ?? true)
        }
    }

    @MainActor
    func testAccentForegroundMeetsContrastInLightAndDarkTraits() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let foreground = AppTheme.accentForeground.resolvedColor(with: traits)
            let background = AppTheme.accent.resolvedColor(with: traits)
            XCTAssertGreaterThanOrEqual(contrastRatio(foreground, background), 4.5)
        }
    }

    @MainActor
    func testAdaptiveLayoutReleasesModeConstraintsAndSelfSizesForAccessibilityText() throws {
        let suite = "PlayerViewControllerLayoutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let service = AudioPlayerService(
            defaults: defaults,
            configureSystemIntegration: false
        )
        let player = PlayerViewController(playerService: service)
        let host = UIViewController()
        host.addChild(player)
        host.view.addSubview(player.view)
        player.didMove(toParent: host)

        host.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: .large),
            forChild: player
        )
        layout(player: player, host: host, size: CGSize(width: 390, height: 844))

        let collectionView = try XCTUnwrap(findSubview(of: UICollectionView.self, in: player.view))
        let normalContentHeight = collectionView.bounds.height
        XCTAssertEqual(activeConstraintCount(constant: 548, in: player.view), 1)

        host.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            forChild: player
        )
        NotificationCenter.default.post(
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
        player.traitCollectionDidChange(
            UITraitCollection(preferredContentSizeCategory: .large)
        )
        descendants(in: collectionView).compactMap { $0 as? UILabel }.forEach {
            $0.font = UIFont.systemFont(ofSize: 44, weight: .semibold)
        }
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.invalidateIntrinsicContentSize()
        layout(player: player, host: host, size: CGSize(width: 390, height: 844))
        XCTAssertEqual(
            player.traitCollection.preferredContentSizeCategory,
            .accessibilityExtraExtraExtraLarge
        )
        XCTAssertGreaterThan(collectionView.bounds.height, normalContentHeight)

        layout(player: player, host: host, size: CGSize(width: 1_024, height: 768))
        XCTAssertEqual(activeConstraintCount(constant: 548, in: player.view), 0)

        layout(player: player, host: host, size: CGSize(width: 390, height: 844))
        XCTAssertEqual(activeConstraintCount(constant: 548, in: player.view), 1)

        let accentButtons = descendants(in: player.view)
            .compactMap { $0 as? UIButton }
            .filter { $0.backgroundColor?.isEqual(AppTheme.accent) == true }
        XCTAssertFalse(accentButtons.isEmpty)
        for button in accentButtons {
            let foreground = try XCTUnwrap(button.titleColor(for: .normal) ?? button.tintColor)
            XCTAssertGreaterThanOrEqual(contrastRatio(foreground, AppTheme.accent), 4.5)
        }
    }

    @MainActor
    private func layout(player: UIViewController, host: UIViewController, size: CGSize) {
        host.view.frame = CGRect(origin: .zero, size: size)
        player.view.frame = host.view.bounds
        for _ in 0..<3 {
            player.view.setNeedsLayout()
            player.view.layoutIfNeeded()
        }
    }

    private func activeConstraintCount(constant: CGFloat, in root: UIView) -> Int {
        descendants(in: root)
            .flatMap(\.constraints)
            .filter { $0.isActive && abs($0.constant - constant) < 0.01 }
            .count
    }

    private func findSubview<T: UIView>(of type: T.Type, in root: UIView) -> T? {
        descendants(in: root).compactMap { $0 as? T }.first
    }

    private func descendants(in root: UIView) -> [UIView] {
        [root] + root.subviews.flatMap(descendants(in:))
    }

    private func ancestors(of view: UIView) -> [UIView] {
        guard let superview = view.superview else { return [] }
        return [superview] + ancestors(of: superview)
    }

    private func button(labelled label: String, in root: UIView) -> UIButton? {
        descendants(in: root)
            .compactMap { $0 as? UIButton }
            .first { $0.accessibilityLabel == label }
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
        color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: &alpha
        )
        return 0.2126 * linearized(red) + 0.7152 * linearized(green) + 0.0722 * linearized(blue)
    }

    private func linearized(_ component: CGFloat) -> CGFloat {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}
