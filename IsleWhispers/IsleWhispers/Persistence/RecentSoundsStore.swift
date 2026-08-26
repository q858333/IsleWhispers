import Foundation

final class RecentSoundsStore {
    static let defaultsKey = "recentSoundResourceIDs"

    private let defaults: UserDefaults
    private(set) var recentSounds: [Sound]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let ids = defaults.stringArray(forKey: Self.defaultsKey) ?? []
        let byID = Dictionary(uniqueKeysWithValues: Sound.catalog.map { ($0.id, $0) })
        recentSounds = ids.compactMap { byID[$0] }
        persist()
    }

    func record(_ sound: Sound) {
        recentSounds.removeAll { $0.id == sound.id }
        recentSounds.insert(sound, at: 0)
        recentSounds = Array(recentSounds.prefix(6))
        persist()
    }

    private func persist() {
        defaults.set(recentSounds.map(\.id), forKey: Self.defaultsKey)
    }
}
