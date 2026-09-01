import SafariServices
import SnapKit
import UIKit

@MainActor
final class LaunchViewController: UIViewController {
    typealias LaunchAction = @MainActor () async -> Void
    typealias RouteScheduler = @MainActor (@escaping @MainActor () -> Void) -> Void

    static let agreementAcceptedDefaultsKey = "app.launch.agreementAccepted"
    static let minimumDisplayDuration: TimeInterval = 1

    private let registerDevice: LaunchAction
    private let agreementDefaults: UserDefaults
    private let links: AppSupportLinks
    private let scheduleRoute: RouteScheduler
    private let unavailableHandler: ((String) -> Void)?
    private let onContinue: @MainActor () -> Void
    private weak var agreementView: UIView?
    private var routeWasScheduled = false

    init(
        registerDevice: LaunchAction? = nil,
        agreementDefaults: UserDefaults,
        links: AppSupportLinks? = nil,
        scheduleRoute: @escaping RouteScheduler,
        unavailableHandler: ((String) -> Void)? = nil,
        onContinue: @escaping @MainActor () -> Void
    ) {
        self.registerDevice = registerDevice ?? {
            try? await DeviceRegistrationService.shared.registerWithRetry()
        }
        self.agreementDefaults = agreementDefaults
        self.links = links ?? .current
        self.scheduleRoute = scheduleRoute
        self.unavailableHandler = unavailableHandler
        self.onContinue = onContinue
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureBrandView()
        if !agreementDefaults.bool(forKey: Self.agreementAcceptedDefaultsKey) {
            configureAgreementView()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if agreementDefaults.bool(forKey: Self.agreementAcceptedDefaultsKey) {
            startRoutingIfNeeded()
        }
    }

    static func scheduleRoute(_ route: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            let nanoseconds = UInt64(Self.minimumDisplayDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            route()
        }
    }

    private func configureBrandView() {
        view.backgroundColor = AppTheme.warmCream

        let logoView = UIImageView(image: UIImage(named: "logo-300"))
        logoView.accessibilityIdentifier = "launch.logo"
        logoView.contentMode = .scaleAspectFit
        logoView.isAccessibilityElement = true
        logoView.accessibilityLabel = "IsleWhispers"

        let titleLabel = UILabel()
        titleLabel.accessibilityIdentifier = "launch.title"
        titleLabel.text = "IsleWhispers"
        titleLabel.textAlignment = .center
        titleLabel.textColor = AppTheme.accentForeground
        titleLabel.font = AppTheme.font(.title1, weight: .bold)
        titleLabel.adjustsFontForContentSizeCategory = true

        let subtitleLabel = UILabel()
        subtitleLabel.accessibilityIdentifier = "launch.subtitle"
        subtitleLabel.text = "聆听自然，放松此刻"
        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = AppTheme.accentForeground.withAlphaComponent(0.72)
        subtitleLabel.font = AppTheme.font(.body)
        subtitleLabel.adjustsFontForContentSizeCategory = true

        let stackView = UIStackView(arrangedSubviews: [logoView, titleLabel, subtitleLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 12
        stackView.setCustomSpacing(22, after: logoView)
        view.addSubview(stackView)

        logoView.snp.makeConstraints { make in
            make.size.equalTo(120)
        }
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualTo(view.safeAreaLayoutGuide).offset(24)
            make.trailing.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-24)
        }
    }

    private func configureAgreementView() {
        let overlay = UIView()
        overlay.accessibilityIdentifier = "launch.agreement"
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        view.addSubview(overlay)
        agreementView = overlay

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        overlay.addSubview(scrollView)

        let scrollContentView = UIView()
        scrollView.addSubview(scrollContentView)

        let card = UIView()
        card.backgroundColor = AppTheme.surface
        card.applyRoundedCorners()
        scrollContentView.addSubview(card)

        let titleLabel = UILabel()
        titleLabel.text = "欢迎使用 IsleWhispers"
        titleLabel.font = AppTheme.font(.title2, weight: .bold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.text = "请阅读并同意用户协议和隐私政策后继续使用。"
        messageLabel.font = AppTheme.font(.body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center

        let termsButton = UIButton(type: .system)
        termsButton.accessibilityIdentifier = "launch.agreement.terms"
        termsButton.setTitle("用户协议", for: .normal)
        termsButton.titleLabel?.font = AppTheme.font(.body, weight: .semibold)
        termsButton.titleLabel?.adjustsFontForContentSizeCategory = true
        termsButton.addTarget(self, action: #selector(showTerms), for: .touchUpInside)

        let privacyButton = UIButton(type: .system)
        privacyButton.accessibilityIdentifier = "launch.agreement.privacy"
        privacyButton.setTitle("隐私政策", for: .normal)
        privacyButton.titleLabel?.font = AppTheme.font(.body, weight: .semibold)
        privacyButton.titleLabel?.adjustsFontForContentSizeCategory = true
        privacyButton.addTarget(self, action: #selector(showPrivacy), for: .touchUpInside)

        let linksStackView = UIStackView(arrangedSubviews: [termsButton, privacyButton])
        linksStackView.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            ? .vertical
            : .horizontal
        linksStackView.alignment = .fill
        linksStackView.distribution = .fillEqually

        let acceptButton = UIButton(type: .system)
        acceptButton.accessibilityIdentifier = "launch.agreement.accept"
        acceptButton.setTitle("同意并继续", for: .normal)
        acceptButton.titleLabel?.font = AppTheme.font(.headline, weight: .semibold)
        acceptButton.titleLabel?.adjustsFontForContentSizeCategory = true
        acceptButton.setTitleColor(.white, for: .normal)
        acceptButton.backgroundColor = AppTheme.accentForeground
        acceptButton.applyRoundedCorners(radius: 14)
        acceptButton.addTarget(self, action: #selector(acceptAgreement), for: .touchUpInside)

        let declineButton = UIButton(type: .system)
        declineButton.accessibilityIdentifier = "launch.agreement.decline"
        declineButton.setTitle("暂不同意", for: .normal)
        declineButton.titleLabel?.font = AppTheme.font(.body, weight: .semibold)
        declineButton.titleLabel?.adjustsFontForContentSizeCategory = true
        declineButton.setTitleColor(AppTheme.accentForeground, for: .normal)
        declineButton.addTarget(self, action: #selector(declineAgreement), for: .touchUpInside)

        let stackView = UIStackView(arrangedSubviews: [
            titleLabel,
            messageLabel,
            linksStackView,
            acceptButton,
            declineButton
        ])
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.setCustomSpacing(20, after: messageLabel)
        stackView.setCustomSpacing(20, after: linksStackView)
        card.addSubview(stackView)

        overlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        scrollContentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
            make.height.greaterThanOrEqualTo(scrollView.frameLayoutGuide)
        }
        card.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.top.greaterThanOrEqualToSuperview().offset(24)
            make.bottom.lessThanOrEqualToSuperview().offset(-24)
        }
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(24)
        }
        linksStackView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(44)
        }
        termsButton.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(44)
        }
        privacyButton.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(44)
        }
        acceptButton.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(52)
        }
        declineButton.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(44)
        }
    }

    @objc private func acceptAgreement() {
        guard !routeWasScheduled else { return }
        agreementDefaults.set(true, forKey: Self.agreementAcceptedDefaultsKey)
        agreementView?.removeFromSuperview()
        startRoutingIfNeeded()
    }

    @objc private func declineAgreement() {
        let alert = UIAlertController(
            title: "需要同意后继续",
            message: "请阅读并同意用户协议和隐私政策后继续使用 IsleWhispers。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: false)
    }

    @objc private func showTerms() {
        open(links.termsOfUseURL, title: "用户协议")
    }

    @objc private func showPrivacy() {
        open(links.privacyPolicyURL, title: "隐私政策")
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

    private func startRoutingIfNeeded() {
        guard !routeWasScheduled else { return }
        routeWasScheduled = true
        let registerDevice = registerDevice
        Task { await registerDevice() }
        scheduleRoute(onContinue)
    }
}
