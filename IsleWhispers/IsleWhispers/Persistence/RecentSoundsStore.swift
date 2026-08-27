import Foundation

final class RecentSoundsStore {
    static let defaultsKey = "recentSoundResourceIDs"

    private let defaults: UserDefaults
    private(set) var recentSounds: [Sound]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let ids = defaults.stringArray(forKey: Self.defaultsKey) ?? []
        let byID = Dictionary(uniqueKeysWithValues: Sound.catalog.map { ($0.id, $0) })
        var seenIDs = Set<String>()
        recentSounds = ids.compactMap { id in
            guard let sound = byID[id], seenIDs.insert(id).inserted else { return nil }
            return sound
        }
        recentSounds = Array(recentSounds.prefix(6))
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
