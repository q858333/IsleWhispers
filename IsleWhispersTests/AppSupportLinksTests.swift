import XCTest
@testable import IsleWhispers

final class AppSupportLinksTests: XCTestCase {
    func testCurrentSupportLinksUsePublicWorkerPages() {
        XCTAssertEqual(
            AppSupportLinks.current.privacyPolicyURL?.absoluteString,
            "https://islewhispersweb.dengcheez.workers.dev/privacy"
        )
        XCTAssertEqual(
            AppSupportLinks.current.termsOfUseURL?.absoluteString,
            "https://islewhispersweb.dengcheez.workers.dev/terms"
        )
        XCTAssertEqual(
            AppSupportLinks.current.supportURL?.absoluteString,
            "https://islewhispersweb.dengcheez.workers.dev/support"
        )
    }
}
