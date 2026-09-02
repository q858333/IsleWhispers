import Foundation

enum L10n {
    static func text(_ key: String, bundle: Bundle = .main) -> String {
        bundle.localizedString(forKey: key, value: nil, table: "Localizable")
    }

    static func format(
        _ key: String,
        bundle: Bundle = .main,
        _ arguments: CVarArg...
    ) -> String {
        let language = bundle.preferredLocalizations.first ?? "en"
        return String(
            format: text(key, bundle: bundle),
            locale: Locale(identifier: language),
            arguments: arguments
        )
    }

    static func plural(_ key: String, count: Int, bundle: Bundle = .main) -> String {
        let language = bundle.preferredLocalizations.first ?? "en"
        return String(
            format: text(key, bundle: bundle),
            locale: Locale(identifier: language),
            arguments: [count]
        )
    }

    static func canonicalLanguage(_ language: String) -> String {
        let components = language
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-", omittingEmptySubsequences: true)
            .map(String.init)
        guard components.first?.lowercased() == "zh", components.count >= 2 else {
            return language
        }
        let scriptOrRegion = components[1]
        if scriptOrRegion.caseInsensitiveCompare("Hant") == .orderedSame
            || ["TW", "HK"].contains(scriptOrRegion.uppercased()) {
            return "zh-Hant"
        }
        return language
    }

    static func bundle(for language: String, in appBundle: Bundle = .main) -> Bundle {
        let resolvedLanguage = canonicalLanguage(language)
        let path = appBundle.path(forResource: resolvedLanguage, ofType: "lproj")
            ?? appBundle.path(forResource: "en", ofType: "lproj")
        return path.flatMap(Bundle.init(path:)) ?? appBundle
    }
}
