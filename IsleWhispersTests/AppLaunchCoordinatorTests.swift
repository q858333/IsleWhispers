import UIKit
import XCTest
import YYText
import SafariServices
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
        XCTAssertEqual(
            (view("launch.subtitle", in: launch.view) as? UILabel)?.text,
            L10n.text("launch.subtitle")
        )
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
        XCTAssertEqual(
            (launch.presentedViewController as? UIAlertController)?.title,
            L10n.text("launch.agreement.required.title")
        )
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
        for title in [L10n.text("launch.agreement.terms"), L10n.text("launch.agreement.privacy")] {
            let range = (attributedText.string as NSString).range(of: title)
            let highlight = try XCTUnwrap(
                attributedText.attribute(highlightKey, at: range.location, effectiveRange: nil)
                    as? YYTextHighlight
            )
            highlight.tapAction?(copyLabel, attributedText, range, .zero)
        }

        XCTAssertEqual(
            unavailableTitles,
            [L10n.text("launch.agreement.terms"), L10n.text("launch.agreement.privacy")]
        )
    }

    func testEnglishAgreementActionsRemainReachableAt320By568WithAccessibilityText() throws {
        let suite = "AppLaunchCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let english = try LocalizationTestSupport.bundle("en")
        let launch = LaunchViewController(
            agreementDefaults: defaults,
            localizationBundle: english,
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
        let scrollView = try XCTUnwrap(scrollView(in: launch.view))
        let scrollContent = try XCTUnwrap(scrollView.subviews.first)

        XCTAssertEqual(actions.axis, .vertical)
        XCTAssertTrue(acceptButton.isDescendant(of: scrollContent))
        XCTAssertTrue(declineButton.isDescendant(of: scrollContent))
        XCTAssertGreaterThan(scrollView.contentSize.height, scrollView.bounds.height)
        scrollView.contentOffset = CGPoint(
            x: 0,
            y: max(0, scrollView.contentSize.height - scrollView.bounds.height)
        )
        scrollView.layoutIfNeeded()
        let acceptFrame = acceptButton.convert(acceptButton.bounds, to: scrollView)
        XCTAssertLessThanOrEqual(acceptFrame.maxY, scrollView.bounds.maxY)
        XCTAssertGreaterThanOrEqual(acceptFrame.height, 52)
        XCTAssertGreaterThanOrEqual(declineButton.bounds.height, 44)
    }

    func testEnglishLaunchCopyFitsAt320By568WithAccessibilityText() throws {
        let suite = "AppLaunchCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let launch = LaunchViewController(
            agreementDefaults: defaults,
            localizationBundle: try LocalizationTestSupport.bundle("en"),
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

        let brandTitle = try XCTUnwrap(view("launch.title", in: launch.view) as? UILabel)
        let subtitle = try XCTUnwrap(view("launch.subtitle", in: launch.view) as? UILabel)
        let acceptButton = try XCTUnwrap(view("launch.agreement.accept", in: launch.view) as? UIButton)
        let declineButton = try XCTUnwrap(view("launch.agreement.decline", in: launch.view) as? UIButton)
        let scrollView = try XCTUnwrap(scrollView(in: launch.view))

        for label in [brandTitle, subtitle, try XCTUnwrap(acceptButton.titleLabel), try XCTUnwrap(declineButton.titleLabel)] {
            assertMultilineTextFits(label)
        }
        for label in [brandTitle, subtitle] {
            let frame = label.convert(label.bounds, to: launch.view)
            XCTAssertGreaterThanOrEqual(frame.minX, launch.view.safeAreaLayoutGuide.layoutFrame.minX)
            XCTAssertLessThanOrEqual(frame.maxX, launch.view.safeAreaLayoutGuide.layoutFrame.maxX)
        }

        scrollView.contentOffset = CGPoint(
            x: 0,
            y: max(0, scrollView.contentSize.height - scrollView.bounds.height)
        )
        scrollView.layoutIfNeeded()
        let acceptFrame = acceptButton.convert(acceptButton.bounds, to: scrollView)
        XCTAssertLessThanOrEqual(acceptFrame.maxY, scrollView.bounds.maxY)
    }

    func testAgreementCopyAndActionsAreLocalizedInAllThreeLanguages() throws {
        let expectations = [
            ("en", "Terms of Use", "Privacy Policy"),
            ("zh-Hans", "用户协议", "隐私政策"),
            ("zh-Hant", "使用者協議", "隱私權政策")
        ]

        for (language, expectedTerms, expectedPrivacy) in expectations {
            let suite = "AppLaunchCoordinatorTests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let bundle = try LocalizationTestSupport.bundle(language)
            let launch = LaunchViewController(
                agreementDefaults: defaults,
                localizationBundle: bundle,
                scheduleRoute: { _ in },
                onContinue: {}
            )
            launch.loadViewIfNeeded()

            let copy = try XCTUnwrap(view("launch.agreement.copy", in: launch.view) as? YYLabel)
            XCTAssertEqual(copy.text, L10n.text("launch.agreement.body", bundle: bundle))
            XCTAssertTrue(copy.text?.contains(expectedTerms) == true)
            XCTAssertTrue(copy.text?.contains(expectedPrivacy) == true)
            XCTAssertEqual(L10n.text("launch.agreement.terms", bundle: bundle), expectedTerms)
            XCTAssertEqual(L10n.text("launch.agreement.privacy", bundle: bundle), expectedPrivacy)
            XCTAssertEqual(
                (view("launch.agreement.accept", in: launch.view) as? UIButton)?.title(for: .normal),
                L10n.text("launch.agreement.accept", bundle: bundle)
            )
            XCTAssertEqual(
                (view("launch.agreement.decline", in: launch.view) as? UIButton)?.title(for: .normal),
                L10n.text("launch.agreement.decline", bundle: bundle)
            )
        }
    }

    func testAgreementHighlightsBothLocalizedDocumentNames() throws {
        let highlightKey = NSAttributedString.Key(rawValue: "YYTextHighlight")
        for language in ["en", "zh-Hans", "zh-Hant"] {
            let suite = "AppLaunchCoordinatorTests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let bundle = try LocalizationTestSupport.bundle(language)
            var unavailableTitles: [String] = []
            let launch = LaunchViewController(
                agreementDefaults: defaults,
                localizationBundle: bundle,
                links: AppSupportLinks(privacyPolicyURL: nil, termsOfUseURL: nil, supportURL: nil),
                scheduleRoute: { _ in },
                unavailableHandler: { unavailableTitles.append($0) },
                onContinue: {}
            )
            launch.loadViewIfNeeded()

            let copy = try XCTUnwrap(view("launch.agreement.copy", in: launch.view) as? YYLabel)
            let attributedText = try XCTUnwrap(copy.attributedText)
            for title in [
                L10n.text("launch.agreement.terms", bundle: bundle),
                L10n.text("launch.agreement.privacy", bundle: bundle)
            ] {
                let range = (attributedText.string as NSString).range(of: title)
                XCTAssertNotEqual(range.location, NSNotFound, "\(language): \(title)")
                let highlight = try XCTUnwrap(
                    attributedText.attribute(highlightKey, at: range.location, effectiveRange: nil)
                        as? YYTextHighlight
                )
                highlight.tapAction?(copy, attributedText, range, .zero)
            }
            XCTAssertEqual(
                unavailableTitles,
                [
                    L10n.text("launch.agreement.terms", bundle: bundle),
                    L10n.text("launch.agreement.privacy", bundle: bundle)
                ]
            )
        }
    }

    func testAgreementVoiceOverActionsUseLocalizedNames() throws {
        for language in ["en", "zh-Hans", "zh-Hant"] {
            let suite = "AppLaunchCoordinatorTests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let bundle = try LocalizationTestSupport.bundle(language)
            var unavailableTitles: [String] = []
            let launch = LaunchViewController(
                agreementDefaults: defaults,
                localizationBundle: bundle,
                links: AppSupportLinks(privacyPolicyURL: nil, termsOfUseURL: nil, supportURL: nil),
                scheduleRoute: { _ in },
                unavailableHandler: { unavailableTitles.append($0) },
                onContinue: {}
            )
            launch.loadViewIfNeeded()

            let copy = try XCTUnwrap(view("launch.agreement.copy", in: launch.view) as? YYLabel)
            let actions = try XCTUnwrap(copy.accessibilityCustomActions)
            XCTAssertEqual(
                actions.map(\.name),
                [
                    L10n.text("launch.agreement.open_terms", bundle: bundle),
                    L10n.text("launch.agreement.open_privacy", bundle: bundle)
                ]
            )
            for action in actions {
                XCTAssertEqual(action.actionHandler?(action), true)
            }
            XCTAssertEqual(
                unavailableTitles,
                [
                    L10n.text("launch.agreement.terms", bundle: bundle),
                    L10n.text("launch.agreement.privacy", bundle: bundle)
                ]
            )
        }
    }

    func testAgreementHighlightAndVoiceOverActionsUseCorrectDocumentURLs() throws {
        let termsURL = URL(string: "https://example.com/terms")!
        let privacyURL = URL(string: "https://example.com/privacy")!

        for entry in AgreementDocumentEntry.allCases {
            try assertAgreementAction(
                entry: entry,
                document: .terms,
                links: AppSupportLinks(
                    privacyPolicyURL: nil,
                    termsOfUseURL: termsURL,
                    supportURL: nil
                ),
                expectsSafari: true
            )
            try assertAgreementAction(
                entry: entry,
                document: .privacy,
                links: AppSupportLinks(
                    privacyPolicyURL: nil,
                    termsOfUseURL: termsURL,
                    supportURL: nil
                ),
                expectsSafari: false
            )
            try assertAgreementAction(
                entry: entry,
                document: .terms,
                links: AppSupportLinks(
                    privacyPolicyURL: privacyURL,
                    termsOfUseURL: nil,
                    supportURL: nil
                ),
                expectsSafari: false
            )
            try assertAgreementAction(
                entry: entry,
                document: .privacy,
                links: AppSupportLinks(
                    privacyPolicyURL: privacyURL,
                    termsOfUseURL: nil,
                    supportURL: nil
                ),
                expectsSafari: true
            )
        }
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
        XCTAssertEqual(
            actions.map(\.name),
            [L10n.text("launch.agreement.open_terms"), L10n.text("launch.agreement.open_privacy")]
        )
        for action in actions {
            XCTAssertEqual(action.actionHandler?(action), true)
        }

        XCTAssertEqual(
            unavailableTitles,
            [L10n.text("launch.agreement.terms"), L10n.text("launch.agreement.privacy")]
        )
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
            [L10n.text("launch.agreement.open_terms"), L10n.text("launch.agreement.open_privacy")]
        )
        XCTAssertEqual(
            (view("launch.agreement.actions", in: launch.view) as? UIStackView)?.axis,
            .horizontal
        )
        let attributedText = try XCTUnwrap(
            copyView.value(forKey: "attributedText") as? NSAttributedString
        )
        let highlightKey = NSAttributedString.Key(rawValue: "YYTextHighlight")
        for title in [L10n.text("launch.agreement.terms"), L10n.text("launch.agreement.privacy")] {
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
private func scrollView(in root: UIView) -> UIScrollView? {
    if let scrollView = root as? UIScrollView {
        return scrollView
    }
    return root.subviews.lazy.compactMap { scrollView(in: $0) }.first
}

private enum AgreementDocument {
    case terms
    case privacy

    var localizationKey: String {
        switch self {
        case .terms: "launch.agreement.terms"
        case .privacy: "launch.agreement.privacy"
        }
    }

    var actionLocalizationKey: String {
        switch self {
        case .terms: "launch.agreement.open_terms"
        case .privacy: "launch.agreement.open_privacy"
        }
    }
}

private enum AgreementDocumentEntry: CaseIterable {
    case highlight
    case voiceOver
}

@MainActor
private func assertAgreementAction(
    entry: AgreementDocumentEntry,
    document: AgreementDocument,
    links: AppSupportLinks,
    expectsSafari: Bool
) throws {
    let suite = "AppLaunchCoordinatorTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    var unavailableTitles: [String] = []
    let launch = LaunchViewController(
        agreementDefaults: defaults,
        links: links,
        scheduleRoute: { _ in },
        unavailableHandler: { unavailableTitles.append($0) },
        onContinue: {}
    )
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = launch
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    launch.loadViewIfNeeded()

    let copy = try XCTUnwrap(view("launch.agreement.copy", in: launch.view) as? YYLabel)
    switch entry {
    case .highlight:
        let attributedText = try XCTUnwrap(copy.attributedText)
        let title = L10n.text(document.localizationKey)
        let range = (attributedText.string as NSString).range(of: title)
        XCTAssertNotEqual(range.location, NSNotFound, title)
        guard range.location != NSNotFound else { return }
        let highlightKey = NSAttributedString.Key(rawValue: "YYTextHighlight")
        let highlight = try XCTUnwrap(
            attributedText.attribute(highlightKey, at: range.location, effectiveRange: nil)
                as? YYTextHighlight
        )
        highlight.tapAction?(copy, attributedText, range, .zero)
    case .voiceOver:
        let actionName = L10n.text(document.actionLocalizationKey)
        let action = try XCTUnwrap(
            copy.accessibilityCustomActions?.first(where: { $0.name == actionName })
        )
        XCTAssertEqual(action.actionHandler?(action), true)
    }

    XCTAssertEqual(launch.presentedViewController is SFSafariViewController, expectsSafari)
    XCTAssertEqual(
        unavailableTitles,
        expectsSafari ? [] : [L10n.text(document.localizationKey)]
    )
}

@MainActor
private func assertMultilineTextFits(
    _ label: UILabel,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual(label.numberOfLines, 0, file: file, line: line)
    XCTAssertEqual(label.textAlignment, .center, file: file, line: line)
    XCTAssertGreaterThan(label.bounds.width, 0, file: file, line: line)
    let fittingSize = label.sizeThatFits(
        CGSize(width: label.bounds.width, height: CGFloat.greatestFiniteMagnitude)
    )
    XCTAssertLessThanOrEqual(fittingSize.width, label.bounds.width + 0.5, file: file, line: line)
    XCTAssertLessThanOrEqual(fittingSize.height, label.bounds.height + 0.5, file: file, line: line)
}
