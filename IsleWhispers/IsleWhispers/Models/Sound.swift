import Foundation

enum SoundCategory: String, CaseIterable, Sendable {
    case nature
    case life
    case atmosphere

    var title: String { title(bundle: .main) }

    func title(bundle: Bundle) -> String {
        L10n.text("sound.category.\(rawValue)", bundle: bundle)
    }
}

struct Sound: Equatable, Hashable, Sendable, Identifiable {
    let localizationKey: String
    let audioResource: String
    let backgroundResource: String
    let category: SoundCategory

    var id: String { audioResource }
    var title: String { title(bundle: .main) }
    var subtitle: String { subtitle(bundle: .main) }

    func title(bundle: Bundle) -> String {
        L10n.text("sound.\(localizationKey).title", bundle: bundle)
    }

    func subtitle(bundle: Bundle) -> String {
        L10n.text("sound.\(localizationKey).subtitle", bundle: bundle)
    }

    static var catalogByCategory: [SoundCategory: [Sound]] {
        Dictionary(grouping: catalog, by: \.category)
    }

    static let catalog: [Sound] = [
        .init(localizationKey: "tea", audioResource: "0_sound_tea", backgroundResource: "tea", category: .life),
        .init(localizationKey: "thunder", audioResource: "1_sound_thunder", backgroundResource: "thunder", category: .nature),
        .init(localizationKey: "rain", audioResource: "2_sound_rain", backgroundResource: "rain", category: .nature),
        .init(localizationKey: "fire", audioResource: "3_sound_fire", backgroundResource: "fire", category: .life),
        .init(localizationKey: "water", audioResource: "4_sound_water", backgroundResource: "water", category: .nature),
        .init(localizationKey: "wind", audioResource: "5_sound_wind", backgroundResource: "wind", category: .nature),
        .init(localizationKey: "day", audioResource: "6_sound_day", backgroundResource: "day", category: .atmosphere),
        .init(localizationKey: "night", audioResource: "7_sound_night", backgroundResource: "night", category: .atmosphere),
        .init(localizationKey: "river", audioResource: "8_sound_river", backgroundResource: "river", category: .nature),
        .init(localizationKey: "space", audioResource: "9_sound_space", backgroundResource: "space", category: .atmosphere),
        .init(localizationKey: "yacht", audioResource: "10_sound_yacht", backgroundResource: "yacht", category: .life),
        .init(localizationKey: "train", audioResource: "11_sound_train", backgroundResource: "train", category: .life),
        .init(localizationKey: "farm", audioResource: "12_sound_farm", backgroundResource: "farm", category: .nature),
        .init(localizationKey: "chimes", audioResource: "13_sound_chimes", backgroundResource: "chimes", category: .life),
        .init(localizationKey: "whale", audioResource: "14_sound_whale", backgroundResource: "whale", category: .nature)
    ]
}
