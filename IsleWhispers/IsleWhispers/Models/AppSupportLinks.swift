import Foundation

struct AppSupportLinks {
    let privacyPolicyURL: URL?
    let termsOfUseURL: URL?
    let supportURL: URL?

    static let current = AppSupportLinks(
        privacyPolicyURL: URL(
            string: "https://islewhispersweb.dengcheez.workers.dev/privacy"
        ),
        termsOfUseURL: URL(
            string: "https://islewhispersweb.dengcheez.workers.dev/terms"
        ),
        supportURL: URL(
            string: "https://islewhispersweb.dengcheez.workers.dev/support"
        )
    )
}
