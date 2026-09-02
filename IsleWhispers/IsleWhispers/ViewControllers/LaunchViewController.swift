import SafariServices
import SnapKit
import UIKit
import YYText

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
    private weak var agreementActionsStackView: UIStackView?
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateAgreementActionsAxis()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.preferredContentSizeCategory
            != traitCollection.preferredContentSizeCategory else { return }
        updateAgreementActionsAxis()
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
        card.backgroundColor = UIColor {
            $0.userInterfaceStyle == .dark
                ? UIColor(red: 0.13, green: 0.12, blue: 0.12, alpha: 1)
                : UIColor(red: 1, green: 0.98, blue: 0.95, alpha: 1)
        }
        card.applyRoundedCorners(radius: 28)
        card.applySubtleShadow()
        scrollContentView.addSubview(card)

        let titleLabel = UILabel()
        titleLabel.text = "欢迎使用 IsleWhispers"
        titleLabel.font = AppTheme.font(.title2, weight: .bold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center

        let messageLabel = makeAgreementCopy()

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
        declineButton.backgroundColor = AppTheme.warmCream.withAlphaComponent(0.48)
        declineButton.applyRoundedCorners(radius: 14)
        declineButton.addTarget(self, action: #selector(declineAgreement), for: .touchUpInside)

        let actionsStackView = UIStackView(arrangedSubviews: [declineButton, acceptButton])
        actionsStackView.accessibilityIdentifier = "launch.agreement.actions"
        agreementActionsStackView = actionsStackView
        actionsStackView.axis = agreementActionsAxis
        actionsStackView.alignment = .fill
        actionsStackView.distribution = .fillEqually
        actionsStackView.spacing = 12

        let stackView = UIStackView(arrangedSubviews: [
            titleLabel,
            messageLabel,
            actionsStackView
        ])
        stackView.axis = .vertical
        stackView.spacing = 18
        stackView.setCustomSpacing(24, after: messageLabel)
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
            make.width.lessThanOrEqualTo(420)
            make.top.greaterThanOrEqualToSuperview().offset(24)
            make.bottom.lessThanOrEqualToSuperview().offset(-24)
        }
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(
                UIEdgeInsets(top: 28, left: 24, bottom: 24, right: 24)
            )
        }
        acceptButton.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(52)
        }
        declineButton.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(44)
        }
    }

    private var agreementActionsAxis: NSLayoutConstraint.Axis {
        let usesAccessibilityText = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            || UITraitCollection.current.preferredContentSizeCategory.isAccessibilityCategory
        let isNarrow = view.bounds.width > 0 && view.bounds.width < 360
        return usesAccessibilityText || isNarrow ? .vertical : .horizontal
    }

    private func updateAgreementActionsAxis() {
        let desiredAxis = agreementActionsAxis
        guard agreementActionsStackView?.axis != desiredAxis else { return }
        agreementActionsStackView?.axis = desiredAxis
    }

    private func makeAgreementCopy() -> YYLabel {
        let message = "请阅读并同意《用户协议》和《隐私政策》后继续使用。"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 5
        let text = NSMutableAttributedString(
            string: message,
            attributes: [
                .font: AppTheme.font(.body),
                .foregroundColor: AppTheme.muted,
                .paragraphStyle: paragraphStyle
            ]
        )
        addAgreementHighlight("用户协议", to: text) { [weak self] in
            self?.showTerms()
        }
        addAgreementHighlight("隐私政策", to: text) { [weak self] in
            self?.showPrivacy()
        }

        let label = YYLabel()
        label.accessibilityIdentifier = "launch.agreement.copy"
        label.attributedText = text
        label.numberOfLines = 0
        label.textAlignment = .center
        label.preferredMaxLayoutWidth = 360
        label.isAccessibilityElement = true
        label.accessibilityLabel = message
        label.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "打开用户协议") { [weak self] _ in
                guard let self else { return false }
                self.showTerms()
                return true
            },
            UIAccessibilityCustomAction(name: "打开隐私政策") { [weak self] _ in
                guard let self else { return false }
                self.showPrivacy()
                return true
            }
        ]
        return label
    }

    private func addAgreementHighlight(
        _ title: String,
        to text: NSMutableAttributedString,
        action: @escaping () -> Void
    ) {
        let range = (text.string as NSString).range(of: title)
        guard range.location != NSNotFound else { return }

        text.addAttributes(
            [
                .foregroundColor: AppTheme.accentForeground,
                .font: AppTheme.font(.body, weight: .semibold)
            ],
            range: range
        )
        let highlight = YYTextHighlight()
        highlight.setColor(AppTheme.accentForeground)
        highlight.tapAction = { _, _, _, _ in action() }
        text.yy_setTextHighlight(highlight, range: range)
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
