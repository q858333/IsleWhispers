import SnapKit
import UIKit

final class RecentSoundCell: UICollectionViewCell {
    static let reuseIdentifier = "RecentSoundCell"

    private let imageContainer = UIView()
    private let fallbackGradient = CAGradientLayer()
    private let imageView = UIImageView()
    private let waveformView = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fallbackGradient.frame = imageContainer.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }

    func configure(
        sound: Sound,
        selected: Bool,
        localizationBundle: Bundle = .main
    ) {
        let title = sound.title(bundle: localizationBundle)
        let subtitle = sound.subtitle(bundle: localizationBundle)
        imageView.image = SoundArtwork.image(for: sound)
        fallbackGradient.isHidden = imageView.image != nil
        titleLabel.text = title
        waveformView.isHidden = !selected
        imageContainer.layer.borderWidth = selected ? 2 : 0
        imageContainer.layer.borderColor = selected ? UIColor.white.cgColor : UIColor.clear.cgColor
        accessibilityLabel = L10n.format(
            "sound.accessibility.title_subtitle.format",
            bundle: localizationBundle,
            title,
            subtitle
        )
        accessibilityTraits = selected ? [.button, .selected] : .button
    }

    private func setupViews() {
        isAccessibilityElement = true
        contentView.backgroundColor = .clear

        imageContainer.clipsToBounds = true
        imageContainer.applyRoundedCorners(radius: 48)
        imageContainer.layer.borderWidth = 0
        imageContainer.layer.borderColor = UIColor.clear.cgColor

        fallbackGradient.colors = SoundArtwork.fallbackColors
        fallbackGradient.startPoint = CGPoint(x: 0, y: 0)
        fallbackGradient.endPoint = CGPoint(x: 1, y: 1)
        imageContainer.layer.addSublayer(fallbackGradient)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isAccessibilityElement = false

        waveformView.image = UIImage(
            systemName: "waveform",
            withConfiguration: AppTheme.symbolConfiguration(pointSize: 16, weight: .bold)
        )
        waveformView.tintColor = .white
        waveformView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        waveformView.applyRoundedCorners(radius: 18)
        waveformView.contentMode = .center
        waveformView.isAccessibilityElement = false

        titleLabel.font = AppTheme.font(.headline, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .center
        titleLabel.isAccessibilityElement = false

        contentView.addSubview(imageContainer)
        imageContainer.addSubview(imageView)
        imageContainer.addSubview(waveformView)
        contentView.addSubview(titleLabel)

        imageContainer.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(imageContainer.snp.width).multipliedBy(1.4)
        }
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }
        waveformView.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(10)
            make.size.equalTo(36)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(imageContainer.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
