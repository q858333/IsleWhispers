import SafariServices
import SnapKit
import UIKit

@MainActor
final class HelpFeedbackViewController: UIViewController {
    static let supportEmail = "dengcheez@gmail.com"

    private let links: AppSupportLinks
    private let openURL: (URL) -> Bool
    private let copyEmail: (String) -> Void
    private let unavailableHandler: ((String) -> Void)?

    init(
        links: AppSupportLinks = .current,
        openURL: @escaping (URL) -> Bool = { url in
            guard UIApplication.shared.canOpenURL(url) else { return false }
            UIApplication.shared.open(url)
            return true
        },
        copyEmail: @escaping (String) -> Void = { UIPasteboard.general.string = $0 },
        unavailableHandler: ((String) -> Void)? = nil
    ) {
        self.links = links
        self.openURL = openURL
        self.copyEmail = copyEmail
        self.unavailableHandler = unavailableHandler
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "帮助与反馈"
        view.backgroundColor = AppTheme.background
        buildInterface()
    }

    private func buildInterface() {
        let intro = helpLabel("常见问题", style: .title2, weight: .bold)
        let faqStack = UIStackView(arrangedSubviews: [
            faq(
                title: "如何切换声音？",
                answer: "在首页左右滑动，或从声音列表选择。",
                identifier: "help.faq.playback"
            ),
            faq(
                title: "倒计时如何工作？",
                answer: "可选择不限时、15、30、60 分钟；暂停时倒计时同步暂停。",
                identifier: "help.faq.timer"
            ),
            faq(
                title: "如何后台播放？",
                answer: "开始播放后可切到后台，也可在控制中心暂停或继续。",
                identifier: "help.faq.background"
            ),
            faq(
                title: "为什么没有通知？",
                answer: "请在系统设置中允许 IsleWhispers 发送通知。",
                identifier: "help.faq.notifications"
            )
        ])
        faqStack.axis = .vertical
        faqStack.spacing = 12

        let contactTitle = helpLabel("联系支持", style: .title2, weight: .bold)
        let emailLabel = helpLabel(Self.supportEmail, style: .body, color: .secondaryLabel)
        emailLabel.accessibilityIdentifier = "help.email"
        emailLabel.textAlignment = .center

        let sendButton = actionButton(
            title: "发送邮件",
            symbol: "envelope.fill",
            identifier: "help.sendEmail",
            action: #selector(didTapSendEmail)
        )
        let copyButton = actionButton(
            title: "复制邮箱",
            symbol: "doc.on.doc.fill",
            identifier: "help.copyEmail",
            action: #selector(didTapCopyEmail)
        )
        let websiteButton = actionButton(
            title: "在线帮助",
            symbol: "safari.fill",
            identifier: "help.supportWebsite",
            action: #selector(didTapSupportWebsite)
        )
        let buttons = UIStackView(arrangedSubviews: [sendButton, copyButton, websiteButton])
        buttons.axis = .vertical
        buttons.spacing = 12

        let content = UIStackView(arrangedSubviews: [intro, faqStack, contactTitle, emailLabel, buttons])
        content.axis = .vertical
        content.spacing = 16
        content.setCustomSpacing(28, after: faqStack)
        content.accessibilityIdentifier = "help.content"

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = "help.scroll"
        view.addSubview(scrollView)
        scrollView.addSubview(content)
        scrollView.snp.makeConstraints { $0.edges.equalTo(view.safeAreaLayoutGuide) }
        content.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide).inset(
                UIEdgeInsets(top: 24, left: 20, bottom: 32, right: 20)
            )
            make.width.equalTo(scrollView.frameLayoutGuide).offset(-40)
        }
    }

    private func faq(title: String, answer: String, identifier: String) -> UIView {
        let titleLabel = helpLabel(title, style: .headline, weight: .semibold)
        let answerLabel = helpLabel(answer, style: .subheadline, color: .secondaryLabel)
        let stack = UIStackView(arrangedSubviews: [titleLabel, answerLabel])
        stack.axis = .vertical
        stack.spacing = 6
        let card = UIView()
        card.accessibilityIdentifier = identifier
        card.backgroundColor = AppTheme.surface
        card.applyRoundedCorners(radius: 18)
        card.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(18) }
        return card
    }

    private func actionButton(
        title: String,
        symbol: String,
        identifier: String,
        action: Selector
    ) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePadding = 10
        configuration.baseBackgroundColor = AppTheme.surface
        configuration.baseForegroundColor = AppTheme.accentForeground
        configuration.cornerStyle = .large
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = identifier
        button.titleLabel?.font = AppTheme.font(.headline, weight: .semibold)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.addTarget(self, action: action, for: .touchUpInside)
        button.snp.makeConstraints { $0.height.greaterThanOrEqualTo(54) }
        return button
    }

    @objc private func didTapSendEmail() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.supportEmail
        components.queryItems = [URLQueryItem(name: "subject", value: "IsleWhispers 帮助与反馈")]
        guard let url = components.url, openURL(url) else {
            copyAndConfirm(message: "未找到邮件应用，邮箱地址已复制。")
            return
        }
    }

    @objc private func didTapCopyEmail() {
        copyAndConfirm(message: "邮箱地址已复制。")
    }

    @objc private func didTapSupportWebsite() {
        guard let url = links.supportURL else {
            if let unavailableHandler {
                unavailableHandler("在线帮助")
            } else {
                showAlert(title: "内容准备中", message: "在线帮助将在正式发布前补充。")
            }
            return
        }
        present(SFSafariViewController(url: url), animated: true)
    }

    private func copyAndConfirm(message: String) {
        copyEmail(Self.supportEmail)
        showAlert(title: "邮箱已复制", message: message)
    }

    private func showAlert(title: String, message: String) {
        guard unavailableHandler == nil else { return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}

private func helpLabel(
    _ text: String,
    style: UIFont.TextStyle,
    weight: UIFont.Weight = .regular,
    color: UIColor = .label
) -> UILabel {
    let label = UILabel()
    label.text = text
    label.font = AppTheme.font(style, weight: weight)
    label.adjustsFontForContentSizeCategory = true
    label.textColor = color
    label.numberOfLines = 0
    return label
}
