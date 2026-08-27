import UIKit

enum SoundArtwork {
    static func image(for sound: Sound, bundle: Bundle = .main) -> UIImage? {
        let url = bundle.url(
            forResource: sound.backgroundResource,
            withExtension: "png",
            subdirectory: "Backgrounds"
        ) ?? bundle.url(forResource: sound.backgroundResource, withExtension: "png")
        return url.flatMap { UIImage(contentsOfFile: $0.path) }
    }

    static let fallbackColors = [
        UIColor(red: 0.73, green: 0.55, blue: 0.56, alpha: 1).cgColor,
        UIColor(red: 0.98, green: 0.91, blue: 0.79, alpha: 1).cgColor
    ]
}
