import SnapKit
import UIKit

final class LibrarySoundCardCell: UICollectionViewCell {
    static let reuseIdentifier = "LibrarySoundCardCell"

    private let fallbackView = UIView()
    private let fallbackGradient = CAGradientLayer()
    private let artworkImageView = UIImageView()
    private let warmOverlayView = UIView()
    private let warmOverlay = CAGradientLayer()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fallbackGradient.frame = fallbackView.bounds
        warmOverlay.frame = warmOverlayView.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        artworkImageView.image = nil
    }

    func configure(sound: Sound, selected: Bool) {
        artworkImageView.image = SoundArtwork.image(for: sound)
        fallbackGradient.isHidden = artworkImageView.image != nil
        titleLabel.text = sound.title
        subtitleLabel.text = sound.subtitle
        contentView.layer.borderWidth = selected ? 2 : 0
        contentView.layer.borderColor = selected ? UIColor.white.cgColor : UIColor.clear.cgColor
        accessibilityLabel = "\(sound.title)：\(sound.subtitle)"
        accessibilityTraits = selected ? [.button, .selected] : .button
    }

    private func setupViews() {
        isAccessibilityElement = true
        contentView.clipsToBounds = true
        contentView.applyRoundedCorners(radius: AppTheme.cardRadius)

        fallbackGradient.colors = SoundArtwork.fallbackColors
        fallbackGradient.startPoint = CGPoint(x: 0, y: 0)
        fallbackGradient.endPoint = CGPoint(x: 1, y: 1)
        fallbackView.layer.addSublayer(fallbackGradient)

        artworkImageView.contentMode = .scaleAspectFill
        artworkImageView.clipsToBounds = true
        artworkImageView.isAccessibilityElement = false

        warmOverlay.colors = [
            UIColor(red: 0.16, green: 0.07, blue: 0.03, alpha: 0.05).cgColor,
            UIColor(red: 0.20, green: 0.08, blue: 0.03, alpha: 0.78).cgColor
        ]
        warmOverlay.startPoint = CGPoint(x: 0.5, y: 0)
        warmOverlay.endPoint = CGPoint(x: 0.5, y: 1)
        warmOverlayView.layer.addSublayer(warmOverlay)
        warmOverlayView.isUserInteractionEnabled = false

        titleLabel.font = AppTheme.font(.headline, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.isAccessibilityElement = false

        subtitleLabel.font = AppTheme.font(.subheadline, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.88)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.numberOfLines = 0
        subtitleLabel.isAccessibilityElement = false

        [fallbackView, artworkImageView, warmOverlayView, titleLabel, subtitleLabel].forEach {
            contentView.addSubview($0)
        }

        fallbackView.snp.makeConstraints { $0.edges.equalToSuperview() }
        artworkImageView.snp.makeConstraints { $0.edges.equalToSuperview() }
        warmOverlayView.snp.makeConstraints { $0.edges.equalToSuperview() }
        subtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview().inset(16)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.greaterThanOrEqualToSuperview().offset(16)
            make.bottom.equalTo(subtitleLabel.snp.top).offset(-4)
        }
        contentView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(contentView.snp.width).multipliedBy(0.72)
        }
    }
}
