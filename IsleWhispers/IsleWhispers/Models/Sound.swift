struct Sound: Equatable, Sendable {
    let title: String
    let subtitle: String
    let audioResource: String
    let backgroundResource: String

    static let catalog: [Sound] = [
        .init(title: "茶香", subtitle: "茶与安静器皿", audioResource: "0_sound_tea_1", backgroundResource: "tea"),
        .init(title: "雷声", subtitle: "低沉而遥远", audioResource: "1_sound_thunder_1", backgroundResource: "thunder"),
        .init(title: "雨声", subtitle: "均匀落在窗边", audioResource: "2_sound_rain_1", backgroundResource: "rain"),
        .init(title: "火炉", subtitle: "轻柔木柴噼啪", audioResource: "3_sound_fire_1", backgroundResource: "fire"),
        .init(title: "水流", subtitle: "舒缓连续水声", audioResource: "4_sound_water_1", backgroundResource: "water"),
        .init(title: "风声", subtitle: "空气缓慢流动", audioResource: "5_sound_wind_1", backgroundResource: "wind"),
        .init(title: "白昼", subtitle: "明亮自然环境", audioResource: "6_sound_day_1", backgroundResource: "day"),
        .init(title: "夜晚", subtitle: "深夜低噪氛围", audioResource: "7_sound_night_1", backgroundResource: "night"),
        .init(title: "河流", subtitle: "清澈而连续的水纹", audioResource: "8_sound_river_1", backgroundResource: "river"),
        .init(title: "太空", subtitle: "宽阔漂浮氛围", audioResource: "9_sound_space_1", backgroundResource: "space"),
        .init(title: "游艇", subtitle: "海面与船体轻响", audioResource: "10_sound_yacht_1", backgroundResource: "yacht"),
        .init(title: "火车", subtitle: "规律远行节奏", audioResource: "11_sound_train_1", backgroundResource: "train"),
        .init(title: "农场", subtitle: "开阔乡间声景", audioResource: "12_sound_farm_1", backgroundResource: "farm"),
        .init(title: "风铃", subtitle: "清脆稀疏回响", audioResource: "13_sound_chimes_1", backgroundResource: "chimes"),
        .init(title: "鲸歌", subtitle: "深海悠长低吟", audioResource: "14_sound_whale_1", backgroundResource: "whale")
    ]
}
