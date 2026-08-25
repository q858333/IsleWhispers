import SnapKit
import UIKit

final class SleepTimerView: UIView {
    var onSelect: ((SleepTimerOption) -> Void)?

    private let options: [(SleepTimerOption, String)] = [
        (.unlimited, "不限"),
        (.minutes15, "15 分钟"),
        (.minutes30, "30 分钟"),
        (.minutes60, "60 分钟")
    ]
    private var buttons = [SleepTimerOption: UIButton]()

    override init(frame: CGRect = .zero) {
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
            button.setTitleColor(AppTheme.foreground, for: .normal)
            button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }

    private func setupViews() {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = 8

        options.forEach { option, title in
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = AppTheme.font(.subheadline, weight: .semibold)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.setTitleColor(AppTheme.foreground, for: .normal)
            button.backgroundColor = AppTheme.surface
            button.applyRoundedCorners(radius: AppTheme.controlSize / 2)
            button.accessibilityLabel = "睡眠定时：\(title)"
            button.accessibilityTraits = .button
            button.addTarget(self, action: #selector(didTapOption(_:)), for: .touchUpInside)
            buttons[option] = button
            stackView.addArrangedSubview(button)
            button.snp.makeConstraints { make in
                make.height.greaterThanOrEqualTo(44)
            }
        }

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @objc private func didTapOption(_ sender: UIButton) {
        guard let option = buttons.first(where: { $0.value === sender })?.key else { return }
        onSelect?(option)
    }
}
