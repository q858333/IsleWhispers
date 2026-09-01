import Foundation
import XCTest
@testable import IsleWhispers

@MainActor
final class DeviceRegistrationServiceTests: XCTestCase {
    func testDeviceIdentifierPersistsIDFVAndReusesStoredValue() throws {
        let storage = InMemoryDeviceIdentifierStore()
        let expectedIdentifier = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        var providerCallCount = 0
        let service = DeviceIdentifierService(
            storage: storage,
            idfvProvider: {
                providerCallCount += 1
                return expectedIdentifier
            }
        )

        XCTAssertEqual(try service.deviceIdentifier(), expectedIdentifier.uuidString)
        XCTAssertEqual(try service.deviceIdentifier(), expectedIdentifier.uuidString)
        XCTAssertEqual(storage.value, expectedIdentifier.uuidString)
        XCTAssertEqual(providerCallCount, 1)
    }

    func testRegisterPostsMetadataToProductionWorkerWithoutAPNsFields() async throws {
        let endpoint = URL(
            string: "https://islewhispersweb.dengcheez.workers.dev/api/v1/devices/register"
        )!
        var capturedRequest: URLRequest?
        let service = DeviceRegistrationService(
            endpoint: endpoint,
            deviceIdentifierProvider: { "11111111-2222-3333-4444-555555555555" },
            metadataProvider: {
                DeviceRegistrationMetadata(
                    appVersion: "1.0",
                    systemVersion: "18.6",
                    deviceModel: "iPhone"
                )
            },
            requestExecutor: { request in
                capturedRequest = request
                let response = HTTPURLResponse(
                    url: endpoint,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (
                    Data(#"{"success":true,"data":{"deviceId":"11111111-2222-3333-4444-555555555555"}}"#.utf8),
                    response
                )
            }
        )

        try await service.register()

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.url, endpoint)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.timeoutInterval, 15)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        XCTAssertEqual(json["deviceId"] as? String, "11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(json["appVersion"] as? String, "1.0")
        XCTAssertEqual(json["systemVersion"] as? String, "18.6")
        XCTAssertEqual(json["deviceModel"] as? String, "iPhone")
        XCTAssertNil(json["apnsToken"])
        XCTAssertNil(json["apnsEnvironment"])
    }

    func testRegisterWithRetrySucceedsAfterThreeTransientFailures() async throws {
        let endpoint = URL(string: "https://example.com/api/v1/devices/register")!
        var attemptCount = 0
        var delays: [UInt64] = []
        let service = DeviceRegistrationService(
            endpoint: endpoint,
            deviceIdentifierProvider: { "11111111-2222-3333-4444-555555555555" },
            metadataProvider: {
                DeviceRegistrationMetadata(
                    appVersion: nil,
                    systemVersion: nil,
                    deviceModel: nil
                )
            },
            requestExecutor: { _ in
                attemptCount += 1
                if attemptCount < 4 {
                    throw URLError(.timedOut)
                }
                let response = HTTPURLResponse(
                    url: endpoint,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (Data(#"{"success":true}"#.utf8), response)
            },
            retrySleeper: { delays.append($0) }
        )

        try await service.registerWithRetry()

        XCTAssertEqual(attemptCount, 4)
        XCTAssertEqual(delays, [2_000_000_000, 2_000_000_000, 2_000_000_000])
    }

    func testRegisterWithRetryDoesNotRetryClientError() async {
        let endpoint = URL(string: "https://example.com/api/v1/devices/register")!
        var attemptCount = 0
        var delayCount = 0
        let service = DeviceRegistrationService(
            endpoint: endpoint,
            deviceIdentifierProvider: { "11111111-2222-3333-4444-555555555555" },
            metadataProvider: {
                DeviceRegistrationMetadata(
                    appVersion: nil,
                    systemVersion: nil,
                    deviceModel: nil
                )
            },
            requestExecutor: { _ in
                attemptCount += 1
                let response = HTTPURLResponse(
                    url: endpoint,
                    statusCode: 400,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (Data(#"{"success":false}"#.utf8), response)
            },
            retrySleeper: { _ in delayCount += 1 }
        )

        do {
            try await service.registerWithRetry()
            XCTFail("HTTP 400 应直接失败")
        } catch {
            XCTAssertEqual(error as? DeviceRegistrationError, .httpStatus(400))
        }

        XCTAssertEqual(attemptCount, 1)
        XCTAssertEqual(delayCount, 0)
    }
}

@MainActor
private final class InMemoryDeviceIdentifierStore: DeviceIdentifierStoring {
    var value: String?

    func loadDeviceIdentifier() throws -> String? {
        value
    }

    func saveDeviceIdentifier(_ value: String) throws {
        self.value = value
    }
}
