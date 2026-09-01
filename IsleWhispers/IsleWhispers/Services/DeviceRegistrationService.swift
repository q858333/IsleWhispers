import Foundation
import UIKit

struct DeviceRegistrationMetadata {
    let appVersion: String?
    let systemVersion: String?
    let deviceModel: String?
}

enum DeviceRegistrationError: Error, Equatable {
    case invalidResponse
    case httpStatus(Int)
}

@MainActor
final class DeviceRegistrationService {
    typealias DeviceIdentifierProvider = @MainActor () throws -> String
    typealias MetadataProvider = @MainActor () -> DeviceRegistrationMetadata
    typealias RequestExecutor = @MainActor (URLRequest) async throws -> (Data, URLResponse)
    typealias RetrySleeper = @MainActor (UInt64) async throws -> Void

    static let shared = DeviceRegistrationService()

    private struct Payload: Encodable {
        let deviceId: String
        let appVersion: String?
        let systemVersion: String?
        let deviceModel: String?
    }

    private struct WorkerResponse: Decodable {
        let success: Bool
    }

    private let endpoint: URL
    private let deviceIdentifierProvider: DeviceIdentifierProvider
    private let metadataProvider: MetadataProvider
    private let requestExecutor: RequestExecutor
    private let retrySleeper: RetrySleeper

    init(
        endpoint: URL? = nil,
        deviceIdentifierProvider: DeviceIdentifierProvider? = nil,
        metadataProvider: MetadataProvider? = nil,
        requestExecutor: RequestExecutor? = nil,
        retrySleeper: RetrySleeper? = nil
    ) {
        self.endpoint = endpoint ?? URL(
            string: "https://islewhispersweb.dengcheez.workers.dev/api/v1/devices/register"
        )!
        self.deviceIdentifierProvider = deviceIdentifierProvider ?? {
            try DeviceIdentifierService().deviceIdentifier()
        }
        self.metadataProvider = metadataProvider ?? {
            DeviceRegistrationMetadata(
                appVersion: Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleShortVersionString"
                ) as? String,
                systemVersion: UIDevice.current.systemVersion,
                deviceModel: UIDevice.current.model
            )
        }
        self.requestExecutor = requestExecutor ?? { request in
            try await URLSession.shared.data(for: request)
        }
        self.retrySleeper = retrySleeper ?? { delay in
            try await Task.sleep(nanoseconds: delay)
        }
    }

    func register() async throws {
        let metadata = metadataProvider()
        let payload = Payload(
            deviceId: try deviceIdentifierProvider(),
            appVersion: metadata.appVersion,
            systemVersion: metadata.systemVersion,
            deviceModel: metadata.deviceModel
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await requestExecutor(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeviceRegistrationError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw DeviceRegistrationError.httpStatus(httpResponse.statusCode)
        }
        guard
            let workerResponse = try? JSONDecoder().decode(WorkerResponse.self, from: data),
            workerResponse.success
        else {
            throw DeviceRegistrationError.invalidResponse
        }
    }

    func registerWithRetry() async throws {
        var completedRetryCount = 0
        while true {
            do {
                try await register()
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                guard error is URLError else { throw error }
                guard completedRetryCount < 3 else { throw error }
                completedRetryCount += 1
                try await retrySleeper(2_000_000_000)
            }
        }
    }
}
