import UIKit
import XCTest
import YYText
@testable import IsleWhispers

@MainActor
final class AppLaunchCoordinatorTests: XCTestCase {
    func testDeviceRegistrationStartsOnlyAfterAgreementAndOnlyOnce() async throws {
        let suite = "AppLaunchCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let registrationStarted = expectation(description: "设备上报开始")
        var registrationCount = 0
        let launch = LaunchViewController(
            registerDevice: {
                registrationCount += 1
                registrationStarted.fulfill()
            },
            agreementDefaults: defaults,
            scheduleRoute: { _ in },
            onContinue: {}
        )
        launch.loadViewIfNeeded()

        launch.viewDidAppear(false)
        XCTAssertEqual(registrationCount, 0)

        let acceptButton = try XCTUnwrap(
            view("launch.agreement.accept", in: launch.view) as? UIButton
        )
        acceptButton.sendActions(for: .touchUpInside)
        acceptButton.sendActions(for: .touchUpInside)
        await fulfillment(of: [registrationStarted], timeout: 1)
        launch.viewDidAppear(false)
        await Task.yield()

        XCTAssertEqual(registrationCount, 1)
    }

    func testAcceptedColdLaunchStartsDeviceRegistrationOnlyOnce() async {
        let suite = "AppLaunchCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: LaunchViewController.agreementAcceptedDefaultsKey)
        let registrationStarted = expectation(description: "设备上报开始")
        var registrationCount = 0
        let launch = LaunchViewController(
            registerDevice: {
                registrationCount += 1
                registrationStarted.fulfill()
            },
            agreementDefaults: defaults,
            scheduleRoute: { _ in },
            onContinue: {}
        )
        launch.loadViewIfNeeded()

        launch.viewDidAppear(false)
        launch.viewDidAppear(false)
        await fulfillment(of: [registrationStarted], timeout: 1)
        await Task.yield()

        XCTAssertEqual(registrationCount, 1)
    }

    func testStartShowsBrandAgreementAndDefersMainInterface() throws {
        let suite = "AppLaunchCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        var rootCreationCount = 0
        let coordinator = AppLaunchCoordinator(
            window: window,
            agreementDefaults: defaults,
            scheduleRoute: { _ in XCTFail("首次同意前不应安排首页跳转") },
            makeRootViewController: {
                rootCreationCount += 1
                return UIViewController()
            }
        )

        coordinator.start()

        let launch = try XCTUnwrap(window.rootViewController as? LaunchViewController)
        launch.loadViewIfNeeded()
        XCTAssertNotNil(view("launch.logo", in: launch.view) as? UIImageView)
        XCTAssertEqual((view("launch.title", in: launch.view) as? UILabel)?.text, "IsleWhispers")
        XCTAssertEqual((view("launch.subtitle", in: launch.view) as? UILabel)?.text, "聆听自然，放松此刻")
        XCTAssertNotNil(view("launch.agreement", in: launch.view))
        XCTAssertEqual(rootCreationCount, 0)
    }

    func testAcceptPersistsAgreementAndSchedulesRouteOnlyOnce() throws {
        let suite = "AppLaunchCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var scheduledRoutes: [@MainActor () -> Void] = []
        let launch = LaunchViewController(
            agreementDefaults: defaults,
            scheduleRoute: { scheduledRoutes.append($0) },
            onContinue: {}
        )
        launch.loadViewIfNeeded()
        let acceptButton = try XCTUnwrap(view("launch.agreement.accept", in: launch.view) as? UIButton)

        acceptButton.sendActions(for: .touchUpInside)
        acceptButton.sendActions(for: .touchUpInside)

        XCTAssertTrue(defaults.bool(forKey: LaunchViewController.agreementAcceptedDefaultsKey))
        XCTAssertEqual(scheduledRoutes.count, 1)
        XCTAssertNil(view("launch.agreement", in: launch.view)?.superview)
    }

    func testDeclineKeepsAgreementVisibleAndDoesNotScheduleRoute() throws {
        let suite = "AppLaunchCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var routeWasScheduled = false
        let launch = LaunchViewController(
            agreementDefaults: defaults,
            scheduleRoute: { _ in routeWasScheduled = true },
            onContinue: {}
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = launch
        window.makeKeyAndVisible()
        launch.loadViewIfNeeded()
        let declineButton = try XCTUnwrap(view("launch.agreement.decline", in: launch.view) as? UIButton)

        declineButton.sendActions(for: .touchUpInside)

        XCTAssertFalse(defaults.bool(forKey: LaunchViewController.agreementAcceptedDefaultsKey))
        XCTAssertFalse(routeWasScheduled)
        XCTAssertNotNil(view("launch.agreement", in: launch.view)?.superview)
        XCTAssertEqual((launch.presentedViewController as? UIAlertController)?.title, "需要同意后继续")
    }

    func testAcceptedStartSchedulesOneSecondRouteAndCreatesMainInterfaceOnlyOnCompletion() throws {
        let suite = "AppLaunchCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: LaunchViewController.agreementAcceptedDefaultsKey)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        var scheduledRoutes: [@MainActor () -> Void] = []
        var rootCreationCount = 0
        let expectedRoot = UIViewController()
        let coordinator = AppLaunchCoordinator(
            window: window,
            agreementDefaults: defaults,
            scheduleRoute: { scheduledRoutes.append($0) },
            makeRootViewController: {
                rootCreationCount += 1
                return expectedRoot
            }
        )

        coordinator.start()
        let launch = try XCTUnwrap(window.rootViewController as? LaunchViewController)
        launch.viewDidAppear(false)
        launch.viewDidAppear(false)

        XCTAssertEqual(LaunchViewController.minimumDisplayDuration, 1, accuracy: 0.001)
        XCTAssertEqual(scheduledRoutes.count, 1)
        XCTAssertEqual(rootCreationCount, 0)

        scheduledRoutes[0]()
        scheduledRoutes[0]()

        XCTAssertEqual(rootCreationCount, 1)
        XCTAssertTrue(window.rootViewController === expectedRoot)
    }

    func testMissingAgreementLinksReportContentAsUnavailable() throws {
        let suite = "AppLaunchCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var unavailableTitles: [String] = []
        let launch = LaunchViewController(
            agreementDefaults: defaults,
            links: AppSupportLinks(privacyPolicyURL: nil, termsOfUseURL: nil, supportURL: nil),
            scheduleRoute: { _ in },
            unavailableHandler: { unavailableTitles.append($0) },
            onContinue: {}
        )
        launch.loadViewIfNeeded()

        let copyLabel = try XCTUnwrap(
            view("launch.agreement.copy", in: launch.view) as? YYLabel
        )
        let attributedText = try XCTUnwrap(copyLabel.attributedText)
        let highlightKey = NSAttributedString.Key(rawValue: "YYTextHighlight")
        for title in ["用户协议", "隐私政策"] {
            let range = (attributedText.string as NSString).range(of: title)
            let highlight = try XCTUnwrap(
                attributedText.attribute(highlightKey, at: range.location, effectiveRange: nil)
                    as? YYTextHighlight
            )
            highlight.tapAction?(copyLabel, attributedText, range, .zero)
        }

        XCTAssertEqual(unavailableTitles, ["用户协议", "隐私政策"])
    }

    func testAgreementActionsRemainReachableOnSmallScreenWithAccessibilityText() throws {
        let suite = "AppLaunchCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let launch = LaunchViewController(
            agreementDefaults: defaults,
            scheduleRoute: { _ in },
            onContinue: {}
        )
        let parent = UIViewController()
        let accessibilityTraits = UITraitCollection(
            preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
        window.rootViewController = parent
        window.makeKeyAndVisible()
        parent.addChild(launch)
        parent.setOverrideTraitCollection(accessibilityTraits, forChild: launch)
        accessibilityTraits.performAsCurrent {
            parent.view.addSubview(launch.view)
        }
        launch.view.frame = parent.view.bounds
        launch.didMove(toParent: parent)
        launch.view.layoutIfNeeded()

        let acceptButton = try XCTUnwrap(view("launch.agreement.accept", in: launch.view))
        let declineButton = try XCTUnwrap(view("launch.agreement.decline", in: launch.view))
        let actions = try XCTUnwrap(
            view("launch.agreement.actions", in: launch.view) as? UIStackView
        )
        let titleLabel = try XCTUnwrap(
            label("欢迎使用 IsleWhispers", in: launch.view)
        )
        let acceptFrame = acceptButton.convert(acceptButton.bounds, to: launch.view)
        let declineFrame = declineButton.convert(declineButton.bounds, to: launch.view)
        let naturalTitleWidth = titleLabel.sizeThatFits(
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        ).width

        XCTAssertEqual(actions.axis, .vertical)
        XCTAssertTrue(
            naturalTitleWidth <= titleLabel.bounds.width + 0.5 || titleLabel.numberOfLines == 0,
            "标题超出可用宽度时必须允许换行"
        )
        XCTAssertGreaterThanOrEqual(acceptFrame.minY, 0)
        XCTAssertLessThanOrEqual(declineFrame.maxY, launch.view.bounds.maxY)
        XCTAssertGreaterThanOrEqual(acceptFrame.height, 52)
        XCTAssertGreaterThanOrEqual(declineFrame.height, 44)
    }

    func testAgreementVoiceOverActionsOpenBothDocuments() throws {
        let suite = "AppLaunchCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var unavailableTitles: [String] = []
        let launch = LaunchViewController(
            agreementDefaults: defaults,
            links: AppSupportLinks(privacyPolicyURL: nil, termsOfUseURL: nil, supportURL: nil),
            scheduleRoute: { _ in },
            unavailableHandler: { unavailableTitles.append($0) },
            onContinue: {}
        )
        launch.loadViewIfNeeded()

        let copyLabel = try XCTUnwrap(
            view("launch.agreement.copy", in: launch.view) as? YYLabel
        )
        let actions = try XCTUnwrap(copyLabel.accessibilityCustomActions)
        XCTAssertEqual(actions.map(\.name), ["打开用户协议", "打开隐私政策"])
        for action in actions {
            XCTAssertEqual(action.actionHandler?(action), true)
        }

        XCTAssertEqual(unavailableTitles, ["用户协议", "隐私政策"])
    }

    func testAgreementEmbedsDocumentActionsInInteractiveRichText() throws {
        let suite = "AppLaunchCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let launch = LaunchViewController(
            agreementDefaults: defaults,
            scheduleRoute: { _ in },
            onContinue: {}
        )
        launch.loadViewIfNeeded()
        launch.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        launch.view.layoutIfNeeded()

        let copyView = try XCTUnwrap(view("launch.agreement.copy", in: launch.view))
        XCTAssertEqual(String(describing: type(of: copyView)), "YYLabel")
        XCTAssertEqual(
            copyView.accessibilityCustomActions?.map(\.name),
            ["打开用户协议", "打开隐私政策"]
        )
        XCTAssertEqual(
            (view("launch.agreement.actions", in: launch.view) as? UIStackView)?.axis,
            .horizontal
        )
        let attributedText = try XCTUnwrap(
            copyView.value(forKey: "attributedText") as? NSAttributedString
        )
        let highlightKey = NSAttributedString.Key(rawValue: "YYTextHighlight")
        for title in ["用户协议", "隐私政策"] {
            let range = (attributedText.string as NSString).range(of: title)
            XCTAssertNotEqual(range.location, NSNotFound, title)
            XCTAssertNotNil(
                attributedText.attribute(highlightKey, at: range.location, effectiveRange: nil),
                title
            )
            XCTAssertEqual(
                attributedText.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor,
                AppTheme.accentForeground,
                title
            )
        }

        XCTAssertNil(view("launch.agreement.terms", in: launch.view))
        XCTAssertNil(view("launch.agreement.privacy", in: launch.view))
    }
}

@MainActor
private func view(_ identifier: String, in root: UIView) -> UIView? {
    if root.accessibilityIdentifier == identifier {
        return root
    }
    return root.subviews.lazy.compactMap { view(identifier, in: $0) }.first
}

@MainActor
private func label(_ text: String, in root: UIView) -> UILabel? {
    if let label = root as? UILabel, label.text == text {
        return label
    }
    return root.subviews.lazy.compactMap { label(text, in: $0) }.first
}
