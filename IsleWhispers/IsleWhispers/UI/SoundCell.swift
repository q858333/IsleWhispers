import SnapKit
import UIKit

final class SoundCell: UICollectionViewCell {
    static let reuseIdentifier = "SoundCell"

    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(sound: Sound, selected: Bool) {
        titleLabel.text = sound.title
        accessibilityLabel = "\(sound.title)：\(sound.subtitle)"
        accessibilityTraits = selected ? [.button, .selected] : .button
        contentView.layer.borderColor = selected ? AppTheme.accent.cgColor : UIColor.clear.cgColor
        contentView.layer.borderWidth = selected ? 2 : 0
    }

    private func setupViews() {
        isAccessibilityElement = true
        contentView.backgroundColor = AppTheme.surface
        contentView.applyRoundedCorners()
        contentView.applySubtleShadow()
        contentView.layer.borderWidth = 0

        iconImageView.image = UIImage(
            systemName: "waveform",
            withConfiguration: AppTheme.symbolConfiguration(pointSize: 20, weight: .medium)
        )
        iconImageView.tintColor = AppTheme.accent
        iconImageView.isAccessibilityElement = false

        titleLabel.font = AppTheme.font(.headline, weight: .semibold)
        titleLabel.textColor = AppTheme.foreground
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.isAccessibilityElement = false

        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.top.bottom.equalToSuperview().inset(14)
            make.trailing.equalToSuperview().inset(16)
        }
    }
}
