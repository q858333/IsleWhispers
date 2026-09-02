import SnapKit
import UIKit

@MainActor
final class SettingsViewController: UIViewController {
    private let gradientLayer = CAGradientLayer()
    private let localizationBundle: Bundle

    init(localizationBundle: Bundle = .main) {
        self.localizationBundle = localizationBundle
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.text("settings.title", bundle: localizationBundle)
        view.backgroundColor = AppTheme.background
        configureBackground()
        buildInterface()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    private func configureBackground() {
        gradientLayer.colors = [
            AppTheme.warmRose.withAlphaComponent(0.72).cgColor,
            AppTheme.warmCream.withAlphaComponent(0.94).cgColor,
            AppTheme.accent.withAlphaComponent(0.55).cgColor
        ]
        gradientLayer.locations = [0, 0.52, 1]
        gradientLayer.startPoint = CGPoint(x: 0.15, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.85, y: 1)
        view.layer.insertSublayer(gradientLayer, at: 0)
    }

    private func buildInterface() {
        let titleLabel = makeLabel(
            L10n.text("settings.title", bundle: localizationBundle),
            style: .largeTitle,
            weight: .bold
        )
        let subtitleLabel = makeLabel(
            L10n.text("settings.subtitle", bundle: localizationBundle),
            style: .body,
            color: .secondaryLabel
        )

        let aboutRow = makeRow(
            title: L10n.text("settings.about.title", bundle: localizationBundle),
            detail: L10n.text("settings.about.detail", bundle: localizationBundle),
            symbolName: "info.circle.fill",
            identifier: "settings.about"
        )
        aboutRow.addTarget(self, action: #selector(didTapAbout), for: .touchUpInside)
        let helpRow = makeRow(
            title: L10n.text("settings.help.title", bundle: localizationBundle),
            detail: L10n.text("settings.help.detail", bundle: localizationBundle),
            symbolName: "questionmark.bubble.fill",
            identifier: "settings.help"
        )
        helpRow.addTarget(self, action: #selector(didTapHelp), for: .touchUpInside)

        let rows = UIStackView(arrangedSubviews: [aboutRow, helpRow])
        rows.axis = .vertical
        rows.spacing = 12

        let content = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, rows])
        content.axis = .vertical
        content.spacing = 12
        content.setCustomSpacing(28, after: subtitleLabel)
        content.accessibilityIdentifier = "settings.content"

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = "settings.scroll"
        view.addSubview(scrollView)
        scrollView.addSubview(content)
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        content.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide).inset(
                UIEdgeInsets(top: 28, left: 20, bottom: 32, right: 20)
            )
            make.width.equalTo(scrollView.frameLayoutGuide).offset(-40)
        }
    }

    private func makeRow(
        title: String,
        detail: String,
        symbolName: String,
        identifier: String
    ) -> UIControl {
        let control = UIControl()
        control.accessibilityIdentifier = identifier
        control.isAccessibilityElement = true
        control.accessibilityLabel = title
        control.accessibilityHint = detail
        control.accessibilityTraits = .button
        control.backgroundColor = AppTheme.surface
        control.applyRoundedCorners(radius: 20)
        control.applySubtleShadow()

        let icon = UIImageView(image: UIImage(systemName: symbolName))
        icon.tintColor = AppTheme.accentForeground
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 22,
            weight: .semibold
        )
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let titleLabel = makeLabel(title, style: .headline, weight: .semibold)
        let detailLabel = makeLabel(detail, style: .subheadline, color: .secondaryLabel)
        let copy = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        copy.axis = .vertical
        copy.spacing = 4

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [icon, copy, chevron])
        row.alignment = .center
        row.spacing = 14
        row.isUserInteractionEnabled = false
        control.addSubview(row)
        row.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(18)
        }
        control.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(88)
        }
        return control
    }

    private func makeLabel(
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

    @objc private func didTapAbout() {
        guard navigationController?.viewControllers.contains(where: { $0 is AboutViewController }) == false else {
            return
        }
        navigationController?.pushViewController(
            AboutViewController(localizationBundle: localizationBundle),
            animated: false
        )
    }

    @objc private func didTapHelp() {
        guard navigationController?.viewControllers.contains(where: { $0 is HelpFeedbackViewController }) == false else {
            return
        }
        navigationController?.pushViewController(
            HelpFeedbackViewController(localizationBundle: localizationBundle),
            animated: false
        )
    }
}
