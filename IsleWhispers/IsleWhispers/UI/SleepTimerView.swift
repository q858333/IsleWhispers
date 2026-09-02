import SnapKit
import UIKit

final class SleepTimerView: UIView {
    private enum LayoutStyle {
        case horizontal
        case grid
        case vertical
    }

    var onSelect: ((SleepTimerOption) -> Void)?

    private let localizationBundle: Bundle
    private var buttons = [SleepTimerOption: UIButton]()
    private var stackView: UIStackView?
    private var layoutStyle: LayoutStyle?

    private var options: [(SleepTimerOption, String)] {
        [
            (.unlimited, L10n.text("timer.option.unlimited", bundle: localizationBundle)),
            (.minutes15, L10n.text("timer.option.minutes15", bundle: localizationBundle)),
            (.minutes30, L10n.text("timer.option.minutes30", bundle: localizationBundle)),
            (.minutes60, L10n.text("timer.option.minutes60", bundle: localizationBundle))
        ]
    }

    init(frame: CGRect = .zero, localizationBundle: Bundle = .main) {
        self.localizationBundle = localizationBundle
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(selected: SleepTimerOption) {
        for (option, button) in buttons {
            let isSelected = option == selected
            button.backgroundColor = isSelected ? AppTheme.accent : AppTheme.surface
            button.setTitleColor(
                isSelected ? AppTheme.accentForeground : AppTheme.foreground,
                for: .normal
            )
            button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }

    private func setupViews() {
        options.forEach { option, title in
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = AppTheme.font(.subheadline, weight: .semibold)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.textAlignment = .center
            button.setTitleColor(AppTheme.foreground, for: .normal)
            button.backgroundColor = AppTheme.surface
            button.applyRoundedCorners(radius: AppTheme.controlSize / 2)
            button.accessibilityLabel = L10n.format(
                "timer.accessibility.option.format",
                bundle: localizationBundle,
                title
            )
            button.accessibilityTraits = .button
            button.addTarget(self, action: #selector(didTapOption(_:)), for: .touchUpInside)
            buttons[option] = button
            button.snp.makeConstraints { make in
                make.height.greaterThanOrEqualTo(44)
            }
        }

        rebuildStack(for: desiredLayoutStyle)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let desiredStyle = desiredLayoutStyle
        if desiredStyle != layoutStyle {
            rebuildStack(for: desiredStyle)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.preferredContentSizeCategory
            != traitCollection.preferredContentSizeCategory else { return }
        rebuildStack(for: desiredLayoutStyle)
    }

    private var desiredLayoutStyle: LayoutStyle {
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            return .vertical
        }
        return bounds.width > 0 && bounds.width < 320 ? .grid : .horizontal
    }

    private func rebuildStack(for style: LayoutStyle) {
        guard style != layoutStyle || stackView == nil else { return }
        stackView?.removeFromSuperview()

        let orderedButtons = options.compactMap { buttons[$0.0] }
        let rootStack: UIStackView
        switch style {
        case .horizontal:
            rootStack = makeStack(arrangedSubviews: orderedButtons, axis: .horizontal)
        case .grid:
            let firstRow = makeStack(
                arrangedSubviews: Array(orderedButtons.prefix(2)),
                axis: .horizontal
            )
            let secondRow = makeStack(
                arrangedSubviews: Array(orderedButtons.suffix(2)),
                axis: .horizontal
            )
            rootStack = makeStack(arrangedSubviews: [firstRow, secondRow], axis: .vertical)
        case .vertical:
            rootStack = makeStack(arrangedSubviews: orderedButtons, axis: .vertical)
        }

        addSubview(rootStack)
        rootStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        stackView = rootStack
        layoutStyle = style
        invalidateIntrinsicContentSize()
    }

    private func makeStack(
        arrangedSubviews: [UIView],
        axis: NSLayoutConstraint.Axis
    ) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: arrangedSubviews)
        stack.axis = axis
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 8
        return stack
    }

    @objc private func didTapOption(_ sender: UIButton) {
        guard let option = buttons.first(where: { $0.value === sender })?.key else { return }
        onSelect?(option)
    }
}
