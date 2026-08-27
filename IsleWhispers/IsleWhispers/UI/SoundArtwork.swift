import UIKit

enum SoundArtwork {
    private static let imageCache = NSCache<NSURL, UIImage>()

    static func image(for sound: Sound, bundle: Bundle = .main) -> UIImage? {
        let url = bundle.url(
            forResource: sound.backgroundResource,
            withExtension: "png",
            subdirectory: "Backgrounds"
        ) ?? bundle.url(forResource: sound.backgroundResource, withExtension: "png")
        guard let url else { return nil }
        let key = url as NSURL
        if let cachedImage = imageCache.object(forKey: key) {
            return cachedImage
        }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        imageCache.setObject(image, forKey: key)
        return image
    }

    static let fallbackColors = [
        UIColor(red: 0.73, green: 0.55, blue: 0.56, alpha: 1).cgColor,
        UIColor(red: 0.98, green: 0.91, blue: 0.79, alpha: 1).cgColor
    ]
}
