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
    func testSystemLaunchScreenUsesBrandArtworkAndCopy() throws {
        let launch = try XCTUnwrap(
            UIStoryboard(name: "LaunchScreen", bundle: .main).instantiateInitialViewController()
        )
        launch.loadViewIfNeeded()

        XCTAssertNotNil(configurationView("launch.logo", in: launch.view) as? UIImageView)
        XCTAssertEqual(
            (configurationView("launch.title", in: launch.view) as? UILabel)?.text,
            "IsleWhispers"
        )
        XCTAssertEqual(
            (configurationView("launch.subtitle", in: launch.view) as? UILabel)?.text,
            "聆听自然，放松此刻"
        )
    }
}

private func configurationView(_ identifier: String, in root: UIView) -> UIView? {
    if root.accessibilityIdentifier == identifier {
        return root
    }
    return root.subviews.lazy.compactMap { configurationView(identifier, in: $0) }.first
}
