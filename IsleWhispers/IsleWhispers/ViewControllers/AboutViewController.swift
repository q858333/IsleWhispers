import SafariServices
import SnapKit
import UIKit

@MainActor
final class AboutViewController: UIViewController {
    private let links: AppSupportLinks
    private let appName: String
    private let version: String
    private let unavailableHandler: ((String) -> Void)?

    init(
        links: AppSupportLinks = .current,
        appName: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "IsleWhispers",
        version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "—",
        unavailableHandler: ((String) -> Void)? = nil
    ) {
        self.links = links
        self.appName = appName
        self.version = version
        self.unavailableHandler = unavailableHandler
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "关于 IsleWhispers"
        view.backgroundColor = AppTheme.background
        buildInterface()
    }

    private func buildInterface() {
        let logo = UIImageView(image: UIImage(named: "logo-300"))
        logo.accessibilityIdentifier = "about.logo"
        logo.contentMode = .scaleAspectFill
        logo.clipsToBounds = true
        logo.applyRoundedCorners(radius: 28)
        logo.snp.makeConstraints { $0.size.equalTo(112) }

        let nameLabel = aboutLabel(appName, style: .title1, weight: .bold)
        nameLabel.accessibilityIdentifier = "about.name"
        nameLabel.textAlignment = .center
        let introLabel = aboutLabel(
            "专注、放松与睡眠的环境声音播放器",
            style: .body,
            color: .secondaryLabel
        )
        introLabel.textAlignment = .center
        let versionLabel = aboutLabel("版本 \(version)", style: .footnote, color: .secondaryLabel)
        versionLabel.accessibilityIdentifier = "about.version"
        versionLabel.textAlignment = .center

        let identity = UIStackView(arrangedSubviews: [logo, nameLabel, introLabel, versionLabel])
        identity.axis = .vertical
        identity.alignment = .center
        identity.spacing = 10

        let privacyText = aboutLabel(
            "声音选择、最近播放和计时偏好仅保存在本机。应用不会上传音频、建立用户账户或用于跟踪。",
            style: .subheadline,
            color: .secondaryLabel
        )
        privacyText.accessibilityIdentifier = "about.localPrivacy"
        let privacyCard = UIView()
        privacyCard.backgroundColor = AppTheme.surface
        privacyCard.applyRoundedCorners(radius: 18)
        privacyCard.addSubview(privacyText)
        privacyText.snp.makeConstraints { $0.edges.equalToSuperview().inset(18) }

        let privacyRow = linkRow(
            title: "隐私政策",
            symbol: "hand.raised.fill",
            identifier: "about.privacy",
            action: #selector(didTapPrivacy)
        )
        let termsRow = linkRow(
            title: "使用条款",
            symbol: "doc.text.fill",
            identifier: "about.terms",
            action: #selector(didTapTerms)
        )
        let linksStack = UIStackView(arrangedSubviews: [privacyRow, termsRow])
        linksStack.axis = .vertical
        linksStack.spacing = 12

        let content = UIStackView(arrangedSubviews: [identity, privacyCard, linksStack])
        content.axis = .vertical
        content.spacing = 24
        content.accessibilityIdentifier = "about.content"

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = "about.scroll"
        view.addSubview(scrollView)
        scrollView.addSubview(content)
        scrollView.snp.makeConstraints { $0.edges.equalTo(view.safeAreaLayoutGuide) }
        content.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide).inset(
                UIEdgeInsets(top: 28, left: 20, bottom: 32, right: 20)
            )
            make.width.equalTo(scrollView.frameLayoutGuide).offset(-40)
        }
    }

    private func linkRow(
        title: String,
        symbol: String,
        identifier: String,
        action: Selector
    ) -> UIControl {
        let control = UIControl()
        control.accessibilityIdentifier = identifier
        control.isAccessibilityElement = true
        control.accessibilityLabel = title
        control.accessibilityTraits = .button
        control.backgroundColor = AppTheme.surface
        control.applyRoundedCorners(radius: 18)
        control.applySubtleShadow()
        control.addTarget(self, action: action, for: .touchUpInside)

        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = AppTheme.accentForeground
        let label = aboutLabel(title, style: .headline, weight: .semibold)
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        let row = UIStackView(arrangedSubviews: [icon, label, chevron])
        row.alignment = .center
        row.spacing = 14
        row.isUserInteractionEnabled = false
        control.addSubview(row)
        row.snp.makeConstraints { $0.edges.equalToSuperview().inset(18) }
        control.snp.makeConstraints { $0.height.greaterThanOrEqualTo(60) }
        return control
    }

    @objc private func didTapPrivacy() {
        open(links.privacyPolicyURL, title: "隐私政策")
    }

    @objc private func didTapTerms() {
        open(links.termsOfUseURL, title: "使用条款")
    }

    private func open(_ url: URL?, title: String) {
        guard let url else {
            if let unavailableHandler {
                unavailableHandler(title)
            } else {
                let alert = UIAlertController(
                    title: "内容准备中",
                    message: "\(title)将在正式发布前补充。",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "知道了", style: .default))
                present(alert, animated: true)
            }
            return
        }
        present(SFSafariViewController(url: url), animated: true)
    }
}

private func aboutLabel(
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
