enum SoundCategory: String, CaseIterable, Sendable {
    case nature = "自然"
    case life = "生活"
    case atmosphere = "氛围"
}

struct Sound: Equatable, Hashable, Sendable, Identifiable {
    let title: String
    let subtitle: String
    let audioResource: String
    let backgroundResource: String
    let category: SoundCategory

    var id: String { audioResource }

    static var catalogByCategory: [SoundCategory: [Sound]] {
        Dictionary(grouping: catalog, by: \.category)
    }

    static let catalog: [Sound] = [
        .init(title: "茶香", subtitle: "茶与安静器皿", audioResource: "0_sound_tea", backgroundResource: "tea", category: .life),
        .init(title: "雷声", subtitle: "低沉而遥远", audioResource: "1_sound_thunder", backgroundResource: "thunder", category: .nature),
        .init(title: "雨声", subtitle: "均匀落在窗边", audioResource: "2_sound_rain", backgroundResource: "rain", category: .nature),
        .init(title: "火炉", subtitle: "轻柔木柴噼啪", audioResource: "3_sound_fire", backgroundResource: "fire", category: .life),
        .init(title: "水流", subtitle: "舒缓连续水声", audioResource: "4_sound_water", backgroundResource: "water", category: .nature),
        .init(title: "风声", subtitle: "空气缓慢流动", audioResource: "5_sound_wind", backgroundResource: "wind", category: .nature),
        .init(title: "白昼", subtitle: "明亮自然环境", audioResource: "6_sound_day", backgroundResource: "day", category: .atmosphere),
        .init(title: "夜晚", subtitle: "深夜低噪氛围", audioResource: "7_sound_night", backgroundResource: "night", category: .atmosphere),
        .init(title: "河流", subtitle: "清澈而连续的水纹", audioResource: "8_sound_river", backgroundResource: "river", category: .nature),
        .init(title: "太空", subtitle: "宽阔漂浮氛围", audioResource: "9_sound_space", backgroundResource: "space", category: .atmosphere),
        .init(title: "游艇", subtitle: "海面与船体轻响", audioResource: "10_sound_yacht", backgroundResource: "yacht", category: .life),
        .init(title: "火车", subtitle: "规律远行节奏", audioResource: "11_sound_train", backgroundResource: "train", category: .life),
        .init(title: "农场", subtitle: "开阔乡间声景", audioResource: "12_sound_farm", backgroundResource: "farm", category: .nature),
        .init(title: "风铃", subtitle: "清脆稀疏回响", audioResource: "13_sound_chimes", backgroundResource: "chimes", category: .life),
        .init(title: "鲸歌", subtitle: "深海悠长低吟", audioResource: "14_sound_whale", backgroundResource: "whale", category: .nature)
    ]
}
