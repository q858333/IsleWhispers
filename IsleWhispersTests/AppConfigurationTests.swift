import XCTest

final class AppConfigurationTests: XCTestCase {
    func testApplicationBuildIsIPhonePortraitOnly() throws {
        let info = try XCTUnwrap(Bundle.main.infoDictionary)
        XCTAssertEqual(info["UIDeviceFamily"] as? [Int], [1])
        XCTAssertEqual(
            info["UISupportedInterfaceOrientations~iphone"] as? [String],
            ["UIInterfaceOrientationPortrait"]
        )
        XCTAssertNil(info["UISupportedInterfaceOrientations~ipad"])
    }
}
