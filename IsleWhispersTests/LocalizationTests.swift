import Foundation
import XCTest
@testable import IsleWhispers

final class LocalizationTests: XCTestCase {
    func testEnglishIsDevelopmentLanguageAndBothChineseLocalesArePackaged() throws {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleDevelopmentRegion") as? String,
            "en"
        )
        XCTAssertNotNil(try LocalizationTestSupport.bundle("en"))
        XCTAssertNotNil(try LocalizationTestSupport.bundle("zh-Hans"))
        XCTAssertNotNil(try LocalizationTestSupport.bundle("zh-Hant"))
    }

    func testCatalogContainsExactly129NonemptyKeysInAllThreeLocales() throws {
        XCTAssertEqual(requiredCatalogKeys.count, expectedCatalogKeyCount)

        for language in ["en", "zh-Hans", "zh-Hant"] {
            XCTAssertEqual(try catalogKeys(language), requiredCatalogKeys)
            for key in requiredCatalogKeys {
                XCTAssertFalse(try catalogValue(key, language: language).isEmpty)
            }
        }
    }

    func testUnsupportedLanguageResolutionFallsBackToEnglish() throws {
        XCTAssertEqual(L10n.bundle(for: "fr", in: .main).bundleURL.lastPathComponent, "en.lproj")
        XCTAssertEqual(L10n.bundle(for: "zh-Hans", in: .main).bundleURL.lastPathComponent, "zh-Hans.lproj")

        for language in ["zh-Hant", "zh-TW", "zh-HK", "zh-Hant-TW", "zh-Hant-HK"] {
            XCTAssertEqual(L10n.bundle(for: language, in: .main).bundleURL.lastPathComponent, "zh-Hant.lproj")
        }

        XCTAssertEqual(L10n.canonicalLanguage("zh-TW"), "zh-Hant")
        XCTAssertEqual(L10n.canonicalLanguage("zh-HK"), "zh-Hant")
        XCTAssertEqual(L10n.canonicalLanguage("zh-Hant-TW"), "zh-Hant")
        XCTAssertEqual(L10n.canonicalLanguage("zh_Hant_HK"), "zh-Hant")
    }

    func testFormattingUsesInjectedBundleAndLocale() throws {
        let english = try LocalizationTestSupport.bundle("en")
        let simplifiedChinese = try LocalizationTestSupport.bundle("zh-Hans")
        let traditionalChinese = try LocalizationTestSupport.bundle("zh-Hant")

        XCTAssertEqual(L10n.format("about.version.format", bundle: english, "1.2.3"), "Version 1.2.3")
        XCTAssertEqual(L10n.format("about.version.format", bundle: simplifiedChinese, "1.2.3"), "版本 1.2.3")
        XCTAssertEqual(L10n.format("about.version.format", bundle: traditionalChinese, "1.2.3"), "版本 1.2.3")

        assertMinutes(in: english, singular: "1 minute", plural: "2 minutes")
        assertMinutes(in: simplifiedChinese, singular: "1 分钟", plural: "2 分钟")
        assertMinutes(in: traditionalChinese, singular: "1 分鐘", plural: "2 分鐘")
    }

    private func assertMinutes(in bundle: Bundle, singular: String, plural: String) {
        XCTAssertEqual(L10n.plural("timer.duration.minutes", count: 1, bundle: bundle), singular)
        XCTAssertEqual(L10n.plural("timer.duration.minutes", count: 2, bundle: bundle), plural)
    }
}

private let expectedCatalogKeyCount = 129
private let requiredCatalogKeys: Set<String> = [
    "common.ok", "common.cancel", "common.retry", "common.content_unavailable.title", "common.content_unavailable.message.format",
    "launch.subtitle", "launch.agreement.title", "launch.agreement.body", "launch.agreement.terms", "launch.agreement.privacy", "launch.agreement.accept", "launch.agreement.decline", "launch.agreement.required.title", "launch.agreement.required.message", "launch.agreement.open_terms", "launch.agreement.open_privacy",
    "tab.home", "tab.sounds", "tab.settings",
    "home.greeting", "home.action.mute", "home.action.unmute", "home.action.recent", "home.action.open_player", "home.action.play_and_open", "home.mute.on", "home.mute.off", "home.retry.hint",
    "carousel.label", "carousel.position.format", "sound.accessibility.title_subtitle.format",
    "recent.title", "recent.list.label", "recent.close", "recent.empty.title", "recent.empty.detail",
    "library.title", "library.list.label",
    "focus.sound_picker.label", "focus.sound_picker.current.format", "focus.sound_picker.hint", "focus.countdown.label", "focus.close", "focus.play", "focus.pause", "focus.retry.label", "focus.countdown.unlimited", "focus.countdown.remaining.format", "focus.countdown.ended", "focus.timer.sheet.title",
    "timer.option.unlimited", "timer.option.short_unlimited", "timer.option.minutes15", "timer.option.minutes30", "timer.option.minutes60", "timer.duration.minutes_seconds.format", "timer.accessibility.option.format", "timer.duration.minutes", "timer.duration.seconds",
    "player.status.ready", "player.status.session_unavailable", "player.status.playback_failed", "player.status.decode_failed", "player.status.resource_unavailable", "notification.playback_ended.title",
    "settings.title", "settings.subtitle", "settings.about.title", "settings.about.detail", "settings.help.title", "settings.help.detail",
    "about.title", "about.tagline", "about.version.format", "about.local_privacy", "about.privacy", "about.terms",
    "help.title", "help.faq.title", "help.faq.playback.question", "help.faq.playback.answer", "help.faq.timer.question", "help.faq.timer.answer", "help.faq.background.question", "help.faq.background.answer", "help.faq.notifications.question", "help.faq.notifications.answer", "help.contact.title", "help.action.email", "help.action.copy_email", "help.action.website", "help.email.subject", "help.email.no_app", "help.email.copied", "help.email.copied.title", "help.website.unavailable",
    "sound.category.nature", "sound.category.life", "sound.category.atmosphere",
    "sound.tea.title", "sound.tea.subtitle", "sound.thunder.title", "sound.thunder.subtitle", "sound.rain.title", "sound.rain.subtitle", "sound.fire.title", "sound.fire.subtitle", "sound.water.title", "sound.water.subtitle", "sound.wind.title", "sound.wind.subtitle", "sound.day.title", "sound.day.subtitle", "sound.night.title", "sound.night.subtitle", "sound.river.title", "sound.river.subtitle", "sound.space.title", "sound.space.subtitle", "sound.yacht.title", "sound.yacht.subtitle", "sound.train.title", "sound.train.subtitle", "sound.farm.title", "sound.farm.subtitle", "sound.chimes.title", "sound.chimes.subtitle", "sound.whale.title", "sound.whale.subtitle"
]

private func catalogKeys(_ language: String) throws -> Set<String> {
    let strings = try catalogStrings()
    return Set(strings.compactMap { key, value in
        localizationEntry(value, language: language) == nil ? nil : key
    })
}

private func catalogValue(_ key: String, language: String) throws -> String {
    let entry = try XCTUnwrap(localizationEntry(try catalogStrings()[key], language: language))
    if let value = (entry["stringUnit"] as? [String: Any])?["value"] as? String {
        return value
    }
    let pluralValues = ((entry["variations"] as? [String: Any])?["plural"] as? [String: Any])?
        .compactMap { ($0.value as? [String: Any])?["stringUnit"] as? [String: Any] }
        .compactMap { $0["value"] as? String } ?? []
    return pluralValues.joined(separator: "|")
}

private func catalogStrings() throws -> [String: Any] {
    let data = try Data(contentsOf: catalogURL)
    let catalog = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    return try XCTUnwrap(catalog["strings"] as? [String: Any])
}

private func localizationEntry(_ value: Any?, language: String) -> [String: Any]? {
    guard let string = value as? [String: Any],
          let localizations = string["localizations"] as? [String: Any]
    else {
        return nil
    }
    return localizations[language] as? [String: Any]
}

private let catalogURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("IsleWhispers/IsleWhispers/Localizable.xcstrings")
