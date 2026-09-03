import UIKit
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

    @MainActor
    func testSystemLaunchScreenUsesFullBleedSharedArtwork() throws {
        let baseBundle = try XCTUnwrap(
            Bundle(path: try XCTUnwrap(Bundle.main.path(forResource: "Base", ofType: "lproj")))
        )
        let launch = try XCTUnwrap(
            UIStoryboard(name: "LaunchScreen", bundle: baseBundle).instantiateInitialViewController()
        )
        launch.loadViewIfNeeded()

        launch.view.layoutIfNeeded()
        let background = try XCTUnwrap(
            configurationView("launch.background", in: launch.view) as? UIImageView
        )
        XCTAssertNotNil(background.image)
        XCTAssertEqual(background.contentMode, .scaleAspectFill)
        XCTAssertTrue(background.clipsToBounds)
        XCTAssertEqual(background.frame, launch.view.bounds)
    }

    func testSimplifiedChineseLaunchScreenOverrideExists() throws {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: "LaunchScreen", ofType: "strings", inDirectory: "zh-Hans.lproj")
        )
        let strings = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(strings.contains("\"lch-sub-txt.text\" = \"聆听自然，放松此刻\";"))
    }

    func testTraditionalChineseLaunchScreenOverrideExists() throws {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: "LaunchScreen", ofType: "strings", inDirectory: "zh-Hant.lproj")
        )
        let strings = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(strings.contains("\"lch-sub-txt.text\" = \"聆聽自然，放鬆此刻\";"))
    }
}

private func configurationView(_ identifier: String, in root: UIView) -> UIView? {
    if root.accessibilityIdentifier == identifier {
        return root
    }
    return root.subviews.lazy.compactMap { configurationView(identifier, in: $0) }.first
}
