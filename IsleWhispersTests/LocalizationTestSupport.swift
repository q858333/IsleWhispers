import Foundation
import XCTest

enum LocalizationTestSupport {
    static func bundle(_ language: String, appBundle: Bundle = .main) throws -> Bundle {
        let path = try XCTUnwrap(appBundle.path(forResource: language, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }
}
