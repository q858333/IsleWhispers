import SnapKit
import UIKit

final class PlayerControlsView: UIView {
    var onPrevious: (() -> Void)?
    var onToggle: (() -> Void)?
    var onNext: (() -> Void)?

    private let previousButton = PlayerControlsView.makeButton(
        symbolName: "backward.end.fill",
        size: AppTheme.controlSize,
        accessibilityLabel: "上一种声音"
    )
    private let toggleButton = PlayerControlsView.makeButton(
        symbolName: "play.fill",
        size: AppTheme.primaryControlSize,
        accessibilityLabel: "播放"
    )
    private let nextButton = PlayerControlsView.makeButton(
        symbolName: "forward.end.fill",
        size: AppTheme.controlSize,
        accessibilityLabel: "下一种声音"
    )

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(isPlaying: Bool) {
        let symbolName = isPlaying ? "pause.fill" : "play.fill"
        toggleButton.setImage(
            UIImage(systemName: symbolName, withConfiguration: AppTheme.symbolConfiguration(pointSize: 24, weight: .semibold)),
            for: .normal
        )
        toggleButton.accessibilityLabel = isPlaying ? "暂停" : "播放"
    }

    private func setupViews() {
        let stackView = UIStackView(arrangedSubviews: [previousButton, toggleButton, nextButton])
        stackView.alignment = .center
        stackView.distribution = .equalSpacing
        stackView.spacing = 24
        addSubview(stackView)

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        previousButton.snp.makeConstraints { make in
            make.size.equalTo(AppTheme.controlSize)
        }
        toggleButton.snp.makeConstraints { make in
            make.size.equalTo(AppTheme.primaryControlSize)
        }
        nextButton.snp.makeConstraints { make in
            make.size.equalTo(AppTheme.controlSize)
        }

        previousButton.addTarget(self, action: #selector(didTapPrevious), for: .touchUpInside)
        toggleButton.addTarget(self, action: #selector(didTapToggle), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(didTapNext), for: .touchUpInside)
    }

    @objc private func didTapPrevious() {
        onPrevious?()
    }

    @objc private func didTapToggle() {
        onToggle?()
    }

    @objc private func didTapNext() {
        onNext?()
    }

    private static func makeButton(symbolName: String, size: CGFloat, accessibilityLabel: String) -> UIButton {
        let button = UIButton(type: .system)
        button.tintColor = AppTheme.foreground
        button.backgroundColor = symbolName == "play.fill" ? AppTheme.accent : AppTheme.surface
        button.applyRoundedCorners(radius: size / 2)
        button.applySubtleShadow()
        button.accessibilityLabel = accessibilityLabel
        button.accessibilityTraits = .button
        button.setImage(
            UIImage(systemName: symbolName, withConfiguration: AppTheme.symbolConfiguration(pointSize: size == AppTheme.primaryControlSize ? 24 : 20, weight: .semibold)),
            for: .normal
        )
        return button
    }
}
