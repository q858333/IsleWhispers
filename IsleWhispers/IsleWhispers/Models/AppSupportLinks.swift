import Foundation

struct AppSupportLinks {
    let privacyPolicyURL: URL?
    let termsOfUseURL: URL?
    let supportURL: URL?

    static let current = AppSupportLinks(
        privacyPolicyURL: nil,
        termsOfUseURL: nil,
        supportURL: nil
    )
}
