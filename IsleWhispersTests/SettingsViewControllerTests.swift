import UIKit
import XCTest
@testable import IsleWhispers

@MainActor
final class SettingsViewControllerTests: XCTestCase {
    func testSettingsShowsAboutAndHelpRowsOnGradientBackground() throws {
        let controller = SettingsViewController(
            localizationBundle: try LocalizationTestSupport.bundle("zh-Hans")
        )
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.view.layoutIfNeeded()

        XCTAssertEqual(controller.title, "设置")
        XCTAssertNotNil(view("settings.about", in: controller.view) as? UIControl)
        XCTAssertNotNil(view("settings.help", in: controller.view) as? UIControl)
        XCTAssertTrue(controller.view.layer.sublayers?.contains { $0 is CAGradientLayer } == true)
    }

    func testAboutRowPushesAboutPageOnlyOnce() throws {
        let controller = SettingsViewController(
            localizationBundle: try LocalizationTestSupport.bundle("zh-Hans")
        )
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
        let controller = SettingsViewController(
            localizationBundle: try LocalizationTestSupport.bundle("zh-Hans")
        )
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
            version: "1.2.3",
            localizationBundle: try LocalizationTestSupport.bundle("zh-Hans")
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
            localizationBundle: try LocalizationTestSupport.bundle("zh-Hans"),
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
            copyEmail: { copiedEmail = $0 },
            unavailableHandler: { _ in }
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
            localizationBundle: try LocalizationTestSupport.bundle("zh-Hans"),
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

    func testSettingsAboutAndHelpUseEnglishBundle() throws {
        try assertLocalizedSettingsPages(
            bundle: LocalizationTestSupport.bundle("en"),
            settings: (
                title: "Settings",
                subtitle: "Learn about the app, get help, and contact support.",
                aboutTitle: "About IsleWhispers",
                aboutDetail: "Version, Privacy Policy, and Terms of Use",
                helpTitle: "Help & Feedback",
                helpDetail: "FAQs and Support Email"
            ),
            about: (
                title: "About IsleWhispers",
                tagline: "Ambient sounds for focus, relaxation, and sleep",
                localPrivacy: "Sound selection, recent history, and timer preferences stay on this device. The app does not upload audio, create user accounts, or track you.",
                privacy: "Privacy Policy",
                terms: "Terms of Use"
            ),
            help: (
                title: "Help & Feedback",
                faqTitle: "Frequently Asked Questions",
                faqCopy: [
                    "How do I change sounds?",
                    "Swipe left or right on Home, or choose a sound from the library.",
                    "How does the timer work?",
                    "Choose No Limit, 15, 30, or 60 minutes. The timer pauses when playback pauses.",
                    "How do I play in the background?",
                    "Start playback, then leave the app. You can pause or resume from Control Center.",
                    "Why did I not receive a notification?",
                    "Allow IsleWhispers notifications in System Settings."
                ],
                contactTitle: "Contact Support",
                sendEmail: "Send Email",
                copyEmail: "Copy Email",
                website: "Online Help"
            )
        )
    }

    func testSettingsAboutAndHelpUseSimplifiedChineseBundle() throws {
        try assertLocalizedSettingsPages(
            bundle: LocalizationTestSupport.bundle("zh-Hans"),
            settings: (
                title: "设置",
                subtitle: "了解应用信息，获取帮助与联系支持",
                aboutTitle: "关于 IsleWhispers",
                aboutDetail: "版本、隐私政策与使用条款",
                helpTitle: "帮助与反馈",
                helpDetail: "常见问题与联系邮箱"
            ),
            about: (
                title: "关于 IsleWhispers",
                tagline: "专注、放松与睡眠的环境声音播放器",
                localPrivacy: "声音选择、最近播放和计时偏好仅保存在本机。应用不会上传音频、建立用户账户或用于跟踪。",
                privacy: "隐私政策",
                terms: "使用条款"
            ),
            help: (
                title: "帮助与反馈",
                faqTitle: "常见问题",
                faqCopy: [
                    "如何切换声音？",
                    "在首页左右滑动，或从声音列表选择。",
                    "倒计时如何工作？",
                    "可选择不限时、15、30、60 分钟；暂停时倒计时同步暂停。",
                    "如何后台播放？",
                    "开始播放后可切到后台，也可在控制中心暂停或继续。",
                    "为什么没有通知？",
                    "请在系统设置中允许 IsleWhispers 发送通知。"
                ],
                contactTitle: "联系支持",
                sendEmail: "发送邮件",
                copyEmail: "复制邮箱",
                website: "在线帮助"
            )
        )
    }

    func testSettingsAboutAndHelpUseTraditionalChineseBundle() throws {
        try assertLocalizedSettingsPages(
            bundle: LocalizationTestSupport.bundle("zh-Hant"),
            settings: (
                title: "設定",
                subtitle: "了解 App 資訊、取得協助並聯絡支援。",
                aboutTitle: "關於 IsleWhispers",
                aboutDetail: "版本、隱私權政策與使用者協議",
                helpTitle: "說明與意見回饋",
                helpDetail: "常見問題與支援信箱"
            ),
            about: (
                title: "關於 IsleWhispers",
                tagline: "為專注、放鬆與睡眠而設的環境聲音播放器",
                localPrivacy: "聲音選擇、最近播放和計時偏好只會保留在這部裝置上。App 不會上傳音訊、建立使用者帳號或追蹤你。",
                privacy: "隱私權政策",
                terms: "使用者協議"
            ),
            help: (
                title: "說明與意見回饋",
                faqTitle: "常見問題",
                faqCopy: [
                    "如何切換聲音？",
                    "在首頁向左或向右滑動，或從聲音庫選擇聲音。",
                    "倒數計時如何運作？",
                    "可選擇不限時、15、30 或 60 分鐘；暫停播放時，倒數計時也會暫停。",
                    "如何在背景播放？",
                    "開始播放後即可離開 App，也可從控制中心暫停或繼續播放。",
                    "為什麼沒有收到通知？",
                    "請在系統設定中允許 IsleWhispers 傳送通知。"
                ],
                contactTitle: "聯絡支援",
                sendEmail: "傳送電子郵件",
                copyEmail: "複製電子郵件地址",
                website: "線上說明"
            )
        )
    }

    func testEnglishMailSubjectAndFallbackAlertsAreLocalized() throws {
        try assertMailSubjectAndFallbackAlerts(
            bundle: LocalizationTestSupport.bundle("en"),
            mailSubject: "IsleWhispers Help & Feedback",
            noMailMessage: "No mail app was found. The email address was copied.",
            copiedTitle: "Email Copied",
            copiedMessage: "The email address was copied.",
            unavailableTitle: "Coming Soon",
            websiteMessage: "Online help will be available before release.",
            privacyTitle: "Privacy Policy",
            privacyMessage: "Privacy Policy will be available before release.",
            termsTitle: "Terms of Use",
            termsMessage: "Terms of Use will be available before release.",
            ok: "OK"
        )
    }

    func testTraditionalChineseMailSubjectAndFallbackAlertsAreLocalized() throws {
        try assertMailSubjectAndFallbackAlerts(
            bundle: LocalizationTestSupport.bundle("zh-Hant"),
            mailSubject: "IsleWhispers 說明與意見回饋",
            noMailMessage: "找不到郵件 App，已複製電子郵件地址。",
            copiedTitle: "已複製電子郵件地址",
            copiedMessage: "已複製電子郵件地址。",
            unavailableTitle: "內容準備中",
            websiteMessage: "線上說明將在正式發布前補充。",
            privacyTitle: "隱私權政策",
            privacyMessage: "隱私權政策 將在正式發布前補充。",
            termsTitle: "使用者協議",
            termsMessage: "使用者協議 將在正式發布前補充。",
            ok: "好"
        )
    }

    func testEnglishSettingsPagesRemainScrollableAt320By568WithAccessibilityText() throws {
        try assertSettingsPagesRemainUsableAtAccessibilitySize(
            bundle: LocalizationTestSupport.bundle("en")
        )
    }

    func testTraditionalChineseSettingsPagesRemainScrollableAt320By568WithAccessibilityText() throws {
        try assertSettingsPagesRemainUsableAtAccessibilitySize(
            bundle: LocalizationTestSupport.bundle("zh-Hant")
        )
    }
}

private typealias SettingsCopy = (
    title: String,
    subtitle: String,
    aboutTitle: String,
    aboutDetail: String,
    helpTitle: String,
    helpDetail: String
)

private typealias AboutCopy = (
    title: String,
    tagline: String,
    localPrivacy: String,
    privacy: String,
    terms: String
)

private typealias HelpCopy = (
    title: String,
    faqTitle: String,
    faqCopy: [String],
    contactTitle: String,
    sendEmail: String,
    copyEmail: String,
    website: String
)

@MainActor
private func assertLocalizedSettingsPages(
    bundle: Bundle,
    settings expectedSettings: SettingsCopy,
    about expectedAbout: AboutCopy,
    help expectedHelp: HelpCopy,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    let animationsWereEnabled = UIView.areAnimationsEnabled
    UIView.setAnimationsEnabled(false)
    defer { UIView.setAnimationsEnabled(animationsWereEnabled) }

    let settings = SettingsViewController(localizationBundle: bundle)
    let navigation = UINavigationController(rootViewController: settings)
    navigation.loadViewIfNeeded()
    settings.loadViewIfNeeded()

    XCTAssertEqual(settings.title, expectedSettings.title, file: file, line: line)
    XCTAssertTrue(allLabels(in: settings.view).contains { $0.text == expectedSettings.subtitle }, file: file, line: line)
    let aboutRow = try XCTUnwrap(view("settings.about", in: settings.view) as? UIControl)
    XCTAssertEqual(aboutRow.accessibilityLabel, expectedSettings.aboutTitle, file: file, line: line)
    XCTAssertEqual(aboutRow.accessibilityHint, expectedSettings.aboutDetail, file: file, line: line)
    let helpRow = try XCTUnwrap(view("settings.help", in: settings.view) as? UIControl)
    XCTAssertEqual(helpRow.accessibilityLabel, expectedSettings.helpTitle, file: file, line: line)
    XCTAssertEqual(helpRow.accessibilityHint, expectedSettings.helpDetail, file: file, line: line)

    aboutRow.sendActions(for: .touchUpInside)
    let about = try XCTUnwrap(navigation.topViewController as? AboutViewController)
    about.loadViewIfNeeded()
    let appVersion = Bundle.main.object(
        forInfoDictionaryKey: "CFBundleShortVersionString"
    ) as? String ?? "—"
    let expectedVersion = L10n.format(
        "about.version.format",
        bundle: bundle,
        appVersion
    )
    XCTAssertEqual(about.title, expectedAbout.title, file: file, line: line)
    XCTAssertEqual(
        (view("about.version", in: about.view) as? UILabel)?.text,
        expectedVersion,
        file: file,
        line: line
    )
    XCTAssertEqual((view("about.localPrivacy", in: about.view) as? UILabel)?.text, expectedAbout.localPrivacy, file: file, line: line)
    let aboutLabels = allLabels(in: about.view).compactMap(\.text)
    XCTAssertTrue(aboutLabels.contains(expectedAbout.tagline), file: file, line: line)
    XCTAssertEqual(view("about.privacy", in: about.view)?.accessibilityLabel, expectedAbout.privacy, file: file, line: line)
    XCTAssertEqual(view("about.terms", in: about.view)?.accessibilityLabel, expectedAbout.terms, file: file, line: line)

    navigation.popViewController(animated: false)
    helpRow.sendActions(for: .touchUpInside)
    let help = try XCTUnwrap(navigation.topViewController as? HelpFeedbackViewController)
    help.loadViewIfNeeded()
    XCTAssertEqual(help.title, expectedHelp.title, file: file, line: line)
    XCTAssertEqual((view("help.email", in: help.view) as? UILabel)?.text, "dengcheez@gmail.com", file: file, line: line)
    let helpLabels = allLabels(in: help.view).compactMap(\.text)
    XCTAssertTrue(helpLabels.contains(expectedHelp.faqTitle), file: file, line: line)
    XCTAssertTrue(helpLabels.contains(expectedHelp.contactTitle), file: file, line: line)
    for text in expectedHelp.faqCopy {
        XCTAssertTrue(helpLabels.contains(text), "Missing localized FAQ copy: \(text)", file: file, line: line)
    }
    XCTAssertEqual(buttonTitle("help.sendEmail", in: help.view), expectedHelp.sendEmail, file: file, line: line)
    XCTAssertEqual(buttonTitle("help.copyEmail", in: help.view), expectedHelp.copyEmail, file: file, line: line)
    XCTAssertEqual(buttonTitle("help.supportWebsite", in: help.view), expectedHelp.website, file: file, line: line)
    XCTAssertEqual(view("help.sendEmail", in: help.view)?.accessibilityLabel, expectedHelp.sendEmail, file: file, line: line)
    XCTAssertEqual(view("help.copyEmail", in: help.view)?.accessibilityLabel, expectedHelp.copyEmail, file: file, line: line)
    XCTAssertEqual(view("help.supportWebsite", in: help.view)?.accessibilityLabel, expectedHelp.website, file: file, line: line)
}

@MainActor
private func assertMailSubjectAndFallbackAlerts(
    bundle: Bundle,
    mailSubject: String,
    noMailMessage: String,
    copiedTitle: String,
    copiedMessage: String,
    unavailableTitle: String,
    websiteMessage: String,
    privacyTitle: String,
    privacyMessage: String,
    termsTitle: String,
    termsMessage: String,
    ok: String,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    let animationsWereEnabled = UIView.areAnimationsEnabled
    UIView.setAnimationsEnabled(false)
    defer { UIView.setAnimationsEnabled(animationsWereEnabled) }

    let noLinks = AppSupportLinks(privacyPolicyURL: nil, termsOfUseURL: nil, supportURL: nil)
    var attemptedMailURL: URL?
    var copiedEmail: String?
    func makeHelpController() -> HelpFeedbackViewController {
        HelpFeedbackViewController(
            links: noLinks,
            localizationBundle: bundle,
            openURL: { attemptedMailURL = $0; return false },
            copyEmail: { copiedEmail = $0 }
        )
    }
    let host = try ViewControllerTestHost(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    defer { host.tearDown() }

    try host.withController(makeHelpController()) { noMailHelp in
        try XCTUnwrap(view("help.sendEmail", in: noMailHelp.view) as? UIControl)
            .sendActions(for: .touchUpInside)
        XCTAssertEqual(
            URLComponents(url: try XCTUnwrap(attemptedMailURL), resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "subject" })?.value,
            mailSubject,
            file: file,
            line: line
        )
        XCTAssertEqual(copiedEmail, HelpFeedbackViewController.supportEmail, file: file, line: line)
        try assertAlert(on: noMailHelp, title: copiedTitle, message: noMailMessage, action: ok, file: file, line: line)
        try dismissAlert(on: noMailHelp, file: file, line: line)
    }

    try host.withController(makeHelpController()) { copyHelp in
        try XCTUnwrap(view("help.copyEmail", in: copyHelp.view) as? UIControl)
            .sendActions(for: .touchUpInside)
        try assertAlert(on: copyHelp, title: copiedTitle, message: copiedMessage, action: ok, file: file, line: line)
        try dismissAlert(on: copyHelp, file: file, line: line)
    }

    try host.withController(makeHelpController()) { websiteHelp in
        try XCTUnwrap(view("help.supportWebsite", in: websiteHelp.view) as? UIControl)
            .sendActions(for: .touchUpInside)
        try assertAlert(on: websiteHelp, title: unavailableTitle, message: websiteMessage, action: ok, file: file, line: line)
        try dismissAlert(on: websiteHelp, file: file, line: line)
    }

    let privacyAbout = AboutViewController(
        links: noLinks,
        appName: "IsleWhispers",
        version: "1.2.3",
        localizationBundle: bundle
    )
    try host.withController(privacyAbout) { privacyAbout in
        try XCTUnwrap(view("about.privacy", in: privacyAbout.view) as? UIControl)
            .sendActions(for: .touchUpInside)
        try assertAlert(on: privacyAbout, title: unavailableTitle, message: privacyMessage, action: ok, file: file, line: line)
        XCTAssertEqual(view("about.privacy", in: privacyAbout.view)?.accessibilityLabel, privacyTitle, file: file, line: line)
        try dismissAlert(on: privacyAbout, file: file, line: line)
    }

    let termsAbout = AboutViewController(
        links: noLinks,
        appName: "IsleWhispers",
        version: "1.2.3",
        localizationBundle: bundle
    )
    try host.withController(termsAbout) { termsAbout in
        try XCTUnwrap(view("about.terms", in: termsAbout.view) as? UIControl)
            .sendActions(for: .touchUpInside)
        try assertAlert(on: termsAbout, title: unavailableTitle, message: termsMessage, action: ok, file: file, line: line)
        XCTAssertEqual(view("about.terms", in: termsAbout.view)?.accessibilityLabel, termsTitle, file: file, line: line)
        try dismissAlert(on: termsAbout, file: file, line: line)
    }
}

@MainActor
private func assertAlert(
    on controller: UIViewController,
    title: String,
    message: String,
    action: String,
    file: StaticString,
    line: UInt
) throws {
    let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
    XCTAssertEqual(alert.title, title, file: file, line: line)
    XCTAssertEqual(alert.message, message, file: file, line: line)
    XCTAssertEqual(alert.actions.map(\.title), [action], file: file, line: line)
}

@MainActor
private func dismissAlert(
    on controller: UIViewController,
    file: StaticString,
    line: UInt
) throws {
    let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
    alert.dismiss(animated: false)
    XCTAssertTrue(
        waitForCondition { controller.presentedViewController == nil },
        file: file,
        line: line
    )
}

@MainActor
private func assertSettingsPagesRemainUsableAtAccessibilitySize(
    bundle: Bundle,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    let animationsWereEnabled = UIView.areAnimationsEnabled
    UIView.setAnimationsEnabled(false)
    defer { UIView.setAnimationsEnabled(animationsWereEnabled) }

    let pages: [(UIViewController, String, String)] = [
        (SettingsViewController(localizationBundle: bundle), "settings.scroll", "settings.help"),
        (AboutViewController(localizationBundle: bundle), "about.scroll", "about.terms"),
        (HelpFeedbackViewController(localizationBundle: bundle), "help.scroll", "help.supportWebsite")
    ]
    let host = try ViewControllerTestHost(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
    defer { host.tearDown() }

    for (controller, scrollIdentifier, lastControlIdentifier) in pages {
        let traits = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        try host.withController(controller, traits: traits) { controller in
            let scrollView = try XCTUnwrap(view(scrollIdentifier, in: controller.view) as? UIScrollView)
            let lastControl = try XCTUnwrap(view(lastControlIdentifier, in: controller.view))
            XCTAssertGreaterThan(scrollView.contentSize.height, scrollView.bounds.height, file: file, line: line)
            scrollView.contentOffset = CGPoint(x: 0, y: scrollView.contentSize.height - scrollView.bounds.height)
            scrollView.layoutIfNeeded()
            let lastFrame = lastControl.convert(lastControl.bounds, to: scrollView)
            XCTAssertLessThanOrEqual(lastFrame.maxY, scrollView.bounds.maxY + 0.5, file: file, line: line)

            for button in allButtons(in: controller.view) {
                let titleLabel = try XCTUnwrap(button.titleLabel)
                XCTAssertEqual(titleLabel.numberOfLines, 0, file: file, line: line)
                let fittingSize = titleLabel.sizeThatFits(
                    CGSize(width: titleLabel.bounds.width, height: .greatestFiniteMagnitude)
                )
                XCTAssertLessThanOrEqual(fittingSize.height, titleLabel.bounds.height + 0.5, file: file, line: line)
            }
        }
    }
}

@MainActor
private final class ViewControllerTestHost {
    private let rootViewController: UIViewController
    private let frame: CGRect
    private var currentController: UIViewController?

    init(frame: CGRect) throws {
        let window = try XCTUnwrap(
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive }
                .flatMap(\.windows)
                .first {
                    $0.isKeyWindow
                        && !$0.isHidden
                        && $0.rootViewController?.viewIfLoaded?.window === $0
                }
        )
        rootViewController = try XCTUnwrap(window.rootViewController)
        self.frame = frame
        rootViewController.loadViewIfNeeded()
        rootViewController.view.layoutIfNeeded()
    }

    func withController<T>(
        _ controller: UIViewController,
        traits: UITraitCollection? = nil,
        perform: (UIViewController) throws -> T
    ) rethrows -> T {
        attach(controller, traits: traits)
        defer { detach(controller) }
        return try perform(controller)
    }

    func tearDown() {
        if let currentController {
            detach(currentController)
        }
    }

    private func attach(_ controller: UIViewController, traits: UITraitCollection?) {
        precondition(currentController == nil)
        rootViewController.addChild(controller)
        if let traits {
            rootViewController.setOverrideTraitCollection(traits, forChild: controller)
        }
        if let traits {
            traits.performAsCurrent {
                rootViewController.view.addSubview(controller.view)
            }
        } else {
            rootViewController.view.addSubview(controller.view)
        }
        controller.view.frame = frame
        controller.didMove(toParent: rootViewController)
        controller.view.layoutIfNeeded()
        currentController = controller
    }

    private func detach(_ controller: UIViewController) {
        precondition(currentController === controller)
        rootViewController.setOverrideTraitCollection(nil, forChild: controller)
        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
        currentController = nil
    }
}

@MainActor
private func waitForCondition(
    timeout: TimeInterval = 1,
    condition: () -> Bool
) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
    return condition()
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

@MainActor
private func allButtons(in root: UIView) -> [UIButton] {
    let current = (root as? UIButton).map { [$0] } ?? []
    return current + root.subviews.flatMap(allButtons)
}

@MainActor
private func buttonTitle(_ identifier: String, in root: UIView) -> String? {
    let button = view(identifier, in: root) as? UIButton
    return button?.configuration?.title ?? button?.title(for: .normal)
}
