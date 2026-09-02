import XCTest
@testable import IsleWhispers

final class SoundCatalogGroupingTests: XCTestCase {
    func testCategoriesContainAllSoundsExactlyOnce() throws {
        let grouped = Sound.catalogByCategory
        let simplifiedChinese = try LocalizationTestSupport.bundle("zh-Hans")
        XCTAssertEqual(SoundCategory.allCases, [.nature, .life, .atmosphere])
        XCTAssertEqual(grouped[.nature]?.map { $0.title(bundle: simplifiedChinese) }, [
            "雷声", "雨声", "水流", "风声", "河流", "农场", "鲸歌"
        ])
        XCTAssertEqual(grouped[.life]?.map { $0.title(bundle: simplifiedChinese) }, [
            "茶香", "火炉", "游艇", "火车", "风铃"
        ])
        XCTAssertEqual(grouped[.atmosphere]?.map { $0.title(bundle: simplifiedChinese) }, [
            "白昼", "夜晚", "太空"
        ])
        XCTAssertEqual(grouped.values.flatMap { $0 }.map(\.id).count, 15)
        XCTAssertEqual(Set(grouped.values.flatMap { $0 }.map(\.id)).count, 15)
    }

    func testCatalogReturnsAllEnglishSimplifiedAndTraditionalChineseMetadata() throws {
        let english = try LocalizationTestSupport.bundle("en")
        let simplifiedChinese = try LocalizationTestSupport.bundle("zh-Hans")
        let traditionalChinese = try LocalizationTestSupport.bundle("zh-Hant")

        XCTAssertEqual(Sound.catalog.map { $0.title(bundle: english) }, [
            "Tea", "Thunder", "Rain", "Fireplace", "Flowing Water", "Wind", "Daylight", "Night", "River", "Space", "Yacht", "Train", "Farm", "Wind Chimes", "Whale Song"
        ])
        XCTAssertEqual(Sound.catalog.map { $0.title(bundle: simplifiedChinese) }, [
            "茶香", "雷声", "雨声", "火炉", "水流", "风声", "白昼", "夜晚", "河流", "太空", "游艇", "火车", "农场", "风铃", "鲸歌"
        ])
        XCTAssertEqual(Sound.catalog.map { $0.title(bundle: traditionalChinese) }, [
            "茶香", "雷聲", "雨聲", "壁爐", "流水", "風聲", "白晝", "夜晚", "河流", "太空", "遊艇", "火車", "農場", "風鈴", "鯨歌"
        ])
    }

    func testCategoryTitlesUseInjectedLanguageBundle() throws {
        let english = try LocalizationTestSupport.bundle("en")
        let simplifiedChinese = try LocalizationTestSupport.bundle("zh-Hans")
        let traditionalChinese = try LocalizationTestSupport.bundle("zh-Hant")

        XCTAssertEqual(SoundCategory.allCases.map { $0.title(bundle: english) }, ["Nature", "Everyday", "Atmosphere"])
        XCTAssertEqual(SoundCategory.allCases.map { $0.title(bundle: simplifiedChinese) }, ["自然", "生活", "氛围"])
        XCTAssertEqual(SoundCategory.allCases.map { $0.title(bundle: traditionalChinese) }, ["自然", "日常", "氛圍"])
    }

    func testLocalizedDisplayDoesNotChangeStableResourceIdentity() throws {
        let english = try LocalizationTestSupport.bundle("en")
        let simplifiedChinese = try LocalizationTestSupport.bundle("zh-Hans")
        let traditionalChinese = try LocalizationTestSupport.bundle("zh-Hant")
        let identitiesBeforeLocalization = stableIdentities()

        for sound in Sound.catalog {
            _ = sound.title(bundle: english)
            _ = sound.subtitle(bundle: english)
            _ = sound.category.title(bundle: english)
            _ = sound.title(bundle: simplifiedChinese)
            _ = sound.subtitle(bundle: simplifiedChinese)
            _ = sound.category.title(bundle: simplifiedChinese)
            _ = sound.title(bundle: traditionalChinese)
            _ = sound.subtitle(bundle: traditionalChinese)
            _ = sound.category.title(bundle: traditionalChinese)
        }

        XCTAssertEqual(stableIdentities(), identitiesBeforeLocalization)
    }

    func testCatalogAudioResourcesResolveFromBundle() {
        for sound in Sound.catalog {
            XCTAssertNotNil(
                Bundle.main.url(forResource: sound.audioResource, withExtension: "caf"),
                "Missing audio resource for \(sound.title): \(sound.audioResource).caf"
            )
        }
    }

    private func stableIdentities() -> [[String]] {
        Sound.catalog.map { [$0.id, $0.audioResource, $0.backgroundResource, $0.category.rawValue] }
    }
}
