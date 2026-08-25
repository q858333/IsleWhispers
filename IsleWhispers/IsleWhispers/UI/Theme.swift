import UIKit

enum AppTheme {
    static let background = UIColor {
        $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.071, green: 0.071, blue: 0.071, alpha: 1)
            : UIColor(red: 0.961, green: 0.961, blue: 0.941, alpha: 1)
    }
    static let surface = UIColor {
        $0.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.10)
            : UIColor(white: 1, alpha: 0.72)
    }
    static let foreground = UIColor.label
    static let muted = UIColor.secondaryLabel
    static let accent = UIColor(red: 0.663, green: 0.769, blue: 0.851, alpha: 1)
    static let accentForeground = UIColor(
        red: 0.035,
        green: 0.105,
        blue: 0.145,
        alpha: 1
    )
    static let cardRadius: CGFloat = 24
    static let controlSize: CGFloat = 48
    static let primaryControlSize: CGFloat = 64

    static func font(_ textStyle: UIFont.TextStyle, weight: UIFont.Weight = .regular) -> UIFont {
        UIFont.preferredFont(forTextStyle: textStyle).withWeight(weight)
    }

    static func symbolConfiguration(pointSize: CGFloat, weight: UIImage.SymbolWeight = .regular) -> UIImage.SymbolConfiguration {
        UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight, scale: .medium)
    }
}

extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        UIFont(descriptor: fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]]), size: pointSize)
    }
}

extension UIView {
    func applyRoundedCorners(radius: CGFloat = AppTheme.cardRadius) {
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
    }

    func applySubtleShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.10
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 6)
    }
}
