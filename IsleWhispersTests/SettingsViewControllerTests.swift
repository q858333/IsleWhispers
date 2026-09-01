import UIKit
import XCTest
@testable import IsleWhispers

@MainActor
final class SettingsViewControllerTests: XCTestCase {
    func testSettingsShowsAboutAndHelpRowsOnGradientBackground() throws {
        let controller = SettingsViewController()
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.view.layoutIfNeeded()

        XCTAssertEqual(controller.title, "设置")
        XCTAssertNotNil(view("settings.about", in: controller.view) as? UIControl)
        XCTAssertNotNil(view("settings.help", in: controller.view) as? UIControl)
        XCTAssertTrue(controller.view.layer.sublayers?.contains { $0 is CAGradientLayer } == true)
    }

    func testAboutRowPushesAboutPageOnlyOnce() throws {
        let controller = SettingsViewController()
        let navigation = UINavigationController(rootViewController: controller)
        navigation.loadViewIfNeeded()
        controller.loadViewIfNeeded()
        let row = try XCTUnwrap(view("settings.about", in: controller.view) as? UIControl)

        row.sendActions(for: .touchUpInside)
        row.sendActions(for: .touchUpInside)
        navigation.topViewController?.loadViewIfNeeded()

        XCTAssertEqual(navigation.viewControllers.count, 2)
        XCTAssertEqual(navigation.topViewController?.title, "关于 IsleWhispers")
    }

    func testHelpRowPushesHelpPageOnlyOnce() throws {
        let controller = SettingsViewController()
        let navigation = UINavigationController(rootViewController: controller)
        navigation.loadViewIfNeeded()
        controller.loadViewIfNeeded()
        let row = try XCTUnwrap(view("settings.help", in: controller.view) as? UIControl)

        row.sendActions(for: .touchUpInside)
        row.sendActions(for: .touchUpInside)
        navigation.topViewController?.loadViewIfNeeded()

        XCTAssertEqual(navigation.viewControllers.count, 2)
        XCTAssertEqual(navigation.topViewController?.title, "帮助与反馈")
    }

    func testAboutShowsAppIdentityVersionAndComplianceLinks() throws {
        let controller = AboutViewController(
            links: AppSupportLinks(privacyPolicyURL: nil, termsOfUseURL: nil, supportURL: nil),
            appName: "IsleWhispers",
            version: "1.2.3"
        )
        controller.loadViewIfNeeded()

        XCTAssertNotNil(view("about.logo", in: controller.view) as? UIImageView)
        XCTAssertEqual((view("about.name", in: controller.view) as? UILabel)?.text, "IsleWhispers")
        XCTAssertEqual((view("about.version", in: controller.view) as? UILabel)?.text, "版本 1.2.3")
        XCTAssertNotNil(view("about.privacy", in: controller.view) as? UIControl)
        XCTAssertNotNil(view("about.terms", in: controller.view) as? UIControl)
        XCTAssertNotNil(view("about.localPrivacy", in: controller.view) as? UILabel)
    }

    func testMissingAboutLinkShowsContentPreparingInsteadOfOpeningBlankPage() throws {
        var unavailableTitle: String?
        let controller = AboutViewController(
            links: AppSupportLinks(privacyPolicyURL: nil, termsOfUseURL: nil, supportURL: nil),
            unavailableHandler: { unavailableTitle = $0 }
        )
        controller.loadViewIfNeeded()
        let privacy = try XCTUnwrap(view("about.privacy", in: controller.view) as? UIControl)

        privacy.sendActions(for: .touchUpInside)

        XCTAssertEqual(unavailableTitle, "隐私政策")
        XCTAssertNil(controller.presentedViewController)
    }

    func testHelpShowsFAQsAndFeedbackEmail() throws {
        let controller = HelpFeedbackViewController()
        controller.loadViewIfNeeded()

        XCTAssertEqual(
            (view("help.email", in: controller.view) as? UILabel)?.text,
            "dengcheez@gmail.com"
        )
        XCTAssertNotNil(view("help.faq.playback", in: controller.view))
        XCTAssertNotNil(view("help.faq.timer", in: controller.view))
        XCTAssertNotNil(view("help.faq.background", in: controller.view))
        XCTAssertNotNil(view("help.faq.notifications", in: controller.view))
        XCTAssertNotNil(view("help.sendEmail", in: controller.view) as? UIControl)
        XCTAssertNotNil(view("help.copyEmail", in: controller.view) as? UIControl)
    }

    func testFeedbackActionsUseConfiguredEmail() throws {
        var openedURL: URL?
        var copiedEmail: String?
        let controller = HelpFeedbackViewController(
            openURL: { openedURL = $0; return true },
            copyEmail: { copiedEmail = $0 }
        )
        controller.loadViewIfNeeded()

        try XCTUnwrap(view("help.sendEmail", in: controller.view) as? UIControl)
            .sendActions(for: .touchUpInside)
        try XCTUnwrap(view("help.copyEmail", in: controller.view) as? UIControl)
            .sendActions(for: .touchUpInside)

        XCTAssertEqual(openedURL?.scheme, "mailto")
        XCTAssertTrue(openedURL?.absoluteString.contains("dengcheez@gmail.com") == true)
        XCTAssertEqual(copiedEmail, "dengcheez@gmail.com")
    }

    func testMissingSupportWebsiteShowsContentPreparing() throws {
        var unavailableTitle: String?
        let controller = HelpFeedbackViewController(
            links: AppSupportLinks(privacyPolicyURL: nil, termsOfUseURL: nil, supportURL: nil),
            unavailableHandler: { unavailableTitle = $0 }
        )
        controller.loadViewIfNeeded()

        try XCTUnwrap(view("help.supportWebsite", in: controller.view) as? UIControl)
            .sendActions(for: .touchUpInside)

        XCTAssertEqual(unavailableTitle, "在线帮助")
        XCTAssertNil(controller.presentedViewController)
    }

    func testAboutAndHelpRemainScrollableOnSmallScreenWithDynamicTypeLabels() throws {
        for controller in [AboutViewController(), HelpFeedbackViewController()] {
            controller.loadViewIfNeeded()
            controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 360)
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()

            let scrollView = try XCTUnwrap(firstScrollView(in: controller.view))
            XCTAssertGreaterThan(scrollView.contentSize.height, scrollView.bounds.height)
            XCTAssertTrue(allLabels(in: controller.view).allSatisfy(\.adjustsFontForContentSizeCategory))
        }
    }
}

@MainActor
private func view(_ identifier: String, in root: UIView) -> UIView? {
    if root.accessibilityIdentifier == identifier {
        return root
    }
    for subview in root.subviews {
        if let match = view(identifier, in: subview) {
            return match
        }
    }
    return nil
}

@MainActor
private func firstScrollView(in root: UIView) -> UIScrollView? {
    if let scrollView = root as? UIScrollView {
        return scrollView
    }
    return root.subviews.lazy.compactMap(firstScrollView).first
}

@MainActor
private func allLabels(in root: UIView) -> [UILabel] {
    let current = (root as? UILabel).map { [$0] } ?? []
    return current + root.subviews.flatMap(allLabels)
}
