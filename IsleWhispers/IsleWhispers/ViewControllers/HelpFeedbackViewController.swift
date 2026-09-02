import SafariServices
import SnapKit
import UIKit

@MainActor
final class HelpFeedbackViewController: UIViewController {
    static let supportEmail = "dengcheez@gmail.com"

    private let links: AppSupportLinks
    private let localizationBundle: Bundle
    private let openURL: (URL) -> Bool
    private let copyEmail: (String) -> Void
    private let unavailableHandler: ((String) -> Void)?

    init(
        links: AppSupportLinks = .current,
        localizationBundle: Bundle = .main,
        openURL: @escaping (URL) -> Bool = { url in
            guard UIApplication.shared.canOpenURL(url) else { return false }
            UIApplication.shared.open(url)
            return true
        },
        copyEmail: @escaping (String) -> Void = { UIPasteboard.general.string = $0 },
        unavailableHandler: ((String) -> Void)? = nil
    ) {
        self.links = links
        self.localizationBundle = localizationBundle
        self.openURL = openURL
        self.copyEmail = copyEmail
        self.unavailableHandler = unavailableHandler
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.text("help.title", bundle: localizationBundle)
        view.backgroundColor = AppTheme.background
        buildInterface()
    }

    private func buildInterface() {
        let intro = helpLabel(
            L10n.text("help.faq.title", bundle: localizationBundle),
            style: .title2,
            weight: .bold
        )
        let faqStack = UIStackView(arrangedSubviews: [
            faq(
                title: L10n.text("help.faq.playback.question", bundle: localizationBundle),
                answer: L10n.text("help.faq.playback.answer", bundle: localizationBundle),
                identifier: "help.faq.playback"
            ),
            faq(
                title: L10n.text("help.faq.timer.question", bundle: localizationBundle),
                answer: L10n.text("help.faq.timer.answer", bundle: localizationBundle),
                identifier: "help.faq.timer"
            ),
            faq(
                title: L10n.text("help.faq.background.question", bundle: localizationBundle),
                answer: L10n.text("help.faq.background.answer", bundle: localizationBundle),
                identifier: "help.faq.background"
            ),
            faq(
                title: L10n.text("help.faq.notifications.question", bundle: localizationBundle),
                answer: L10n.text("help.faq.notifications.answer", bundle: localizationBundle),
                identifier: "help.faq.notifications"
            )
        ])
        faqStack.axis = .vertical
        faqStack.spacing = 12

        let contactTitle = helpLabel(
            L10n.text("help.contact.title", bundle: localizationBundle),
            style: .title2,
            weight: .bold
        )
        let emailLabel = helpLabel(Self.supportEmail, style: .body, color: .secondaryLabel)
        emailLabel.accessibilityIdentifier = "help.email"
        emailLabel.textAlignment = .center

        let sendButton = actionButton(
            title: L10n.text("help.action.email", bundle: localizationBundle),
            symbol: "envelope.fill",
            identifier: "help.sendEmail",
            action: #selector(didTapSendEmail)
        )
        let copyButton = actionButton(
            title: L10n.text("help.action.copy_email", bundle: localizationBundle),
            symbol: "doc.on.doc.fill",
            identifier: "help.copyEmail",
            action: #selector(didTapCopyEmail)
        )
        let websiteButton = actionButton(
            title: L10n.text("help.action.website", bundle: localizationBundle),
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
        configuration.titleLineBreakMode = .byWordWrapping
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = identifier
        button.accessibilityLabel = title
        button.titleLabel?.font = AppTheme.font(.headline, weight: .semibold)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.addTarget(self, action: action, for: .touchUpInside)
        button.snp.makeConstraints { $0.height.greaterThanOrEqualTo(54) }
        return button
    }

    @objc private func didTapSendEmail() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.supportEmail
        components.queryItems = [
            URLQueryItem(
                name: "subject",
                value: L10n.text("help.email.subject", bundle: localizationBundle)
            )
        ]
        guard let url = components.url, openURL(url) else {
            copyAndConfirm(
                message: L10n.text("help.email.no_app", bundle: localizationBundle)
            )
            return
        }
    }

    @objc private func didTapCopyEmail() {
        copyAndConfirm(
            message: L10n.text("help.email.copied", bundle: localizationBundle)
        )
    }

    @objc private func didTapSupportWebsite() {
        guard let url = links.supportURL else {
            if let unavailableHandler {
                unavailableHandler(
                    L10n.text("help.action.website", bundle: localizationBundle)
                )
            } else {
                showAlert(
                    title: L10n.text(
                        "common.content_unavailable.title",
                        bundle: localizationBundle
                    ),
                    message: L10n.text("help.website.unavailable", bundle: localizationBundle)
                )
            }
            return
        }
        present(SFSafariViewController(url: url), animated: true)
    }

    private func copyAndConfirm(message: String) {
        copyEmail(Self.supportEmail)
        showAlert(
            title: L10n.text("help.email.copied.title", bundle: localizationBundle),
            message: message
        )
    }

    private func showAlert(title: String, message: String) {
        guard unavailableHandler == nil else { return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(
                title: L10n.text("common.ok", bundle: localizationBundle),
                style: .default
            )
        )
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
