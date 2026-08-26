import XCTest
@testable import IsleWhispers

final class SoundCatalogGroupingTests: XCTestCase {
    func testCategoriesContainAllSoundsExactlyOnce() {
        let grouped = Sound.catalogByCategory
        XCTAssertEqual(SoundCategory.allCases, [.nature, .life, .atmosphere])
        XCTAssertEqual(grouped[.nature]?.map(\.title), [
            "雷声", "雨声", "水流", "风声", "河流", "农场", "鲸歌"
        ])
        XCTAssertEqual(grouped[.life]?.map(\.title), [
            "茶香", "火炉", "游艇", "火车", "风铃"
        ])
        XCTAssertEqual(grouped[.atmosphere]?.map(\.title), [
            "白昼", "夜晚", "太空"
        ])
        XCTAssertEqual(grouped.values.flatMap { $0 }.map(\.id).count, 15)
        XCTAssertEqual(Set(grouped.values.flatMap { $0 }.map(\.id)).count, 15)
    }

    func testCatalogAudioResourcesResolveFromBundle() {
        for sound in Sound.catalog {
            XCTAssertNotNil(
                Bundle.main.url(forResource: sound.audioResource, withExtension: "caf"),
                "Missing audio resource for \(sound.title): \(sound.audioResource).caf"
            )
        }
    }
}
