import SnapKit
import UIKit

final class SoundCarouselCell: UICollectionViewCell {
    static let reuseIdentifier = "SoundCarouselCell"

    private let fallbackView = UIView()
    private let fallbackGradient = CAGradientLayer()
    private let artworkImageView = UIImageView()
    private let bottomOverlayView = UIView()
    private let bottomOverlay = CAGradientLayer()
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
        bottomOverlay.frame = bottomOverlayView.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        artworkImageView.image = nil
        transform = .identity
        alpha = 1
        titleLabel.alpha = 1
        subtitleLabel.alpha = 1
    }

    func configure(sound: Sound) {
        artworkImageView.image = SoundArtwork.image(for: sound)
        fallbackView.isHidden = artworkImageView.image != nil
        titleLabel.text = sound.title
        subtitleLabel.text = sound.subtitle
        isAccessibilityElement = false
    }

    func applyTitleTreatment(centerDistance: CGFloat) {
        let distance = min(max(centerDistance, 0), 1)
        let fadeProgress = distance * distance
        titleLabel.alpha = 1 - 0.90 * fadeProgress
        subtitleLabel.alpha = 1 - 0.96 * fadeProgress
    }

    private func setupViews() {
        isAccessibilityElement = false
        contentView.clipsToBounds = true
        contentView.layer.cornerRadius = 30
        contentView.layer.cornerCurve = .continuous

        fallbackGradient.colors = SoundArtwork.fallbackColors
        fallbackGradient.startPoint = CGPoint(x: 0, y: 0)
        fallbackGradient.endPoint = CGPoint(x: 1, y: 1)
        fallbackView.layer.addSublayer(fallbackGradient)

        artworkImageView.contentMode = .scaleAspectFill
        artworkImageView.clipsToBounds = true
        artworkImageView.isAccessibilityElement = false

        bottomOverlay.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.72).cgColor
        ]
        bottomOverlay.locations = [0, 1]
        bottomOverlay.startPoint = CGPoint(x: 0.5, y: 0)
        bottomOverlay.endPoint = CGPoint(x: 0.5, y: 1)
        bottomOverlayView.layer.addSublayer(bottomOverlay)
        bottomOverlayView.isUserInteractionEnabled = false

        titleLabel.font = AppTheme.font(.title2, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 2

        subtitleLabel.font = AppTheme.font(.subheadline, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.88)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.numberOfLines = 2

        [fallbackView, artworkImageView, bottomOverlayView, titleLabel, subtitleLabel].forEach {
            contentView.addSubview($0)
        }

        fallbackView.snp.makeConstraints { $0.edges.equalToSuperview() }
        artworkImageView.snp.makeConstraints { $0.edges.equalToSuperview() }
        bottomOverlayView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(0.48)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview().inset(24)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalTo(subtitleLabel.snp.top).offset(-6)
        }
    }
}
