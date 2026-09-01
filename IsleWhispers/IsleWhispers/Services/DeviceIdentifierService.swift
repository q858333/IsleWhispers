import Security
import UIKit

@MainActor
protocol DeviceIdentifierStoring: AnyObject {
    func loadDeviceIdentifier() throws -> String?
    func saveDeviceIdentifier(_ value: String) throws
}

struct DeviceIdentifierKeychainError: Error {
    let status: OSStatus
}

@MainActor
final class KeychainDeviceIdentifierStore: DeviceIdentifierStoring {
    private let service: String
    private let account: String

    init(
        service: String = Bundle.main.bundleIdentifier ?? "DB.IsleWhispers",
        account: String = "device_identifier"
    ) {
        self.service = service
        self.account = account
    }

    func loadDeviceIdentifier() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw DeviceIdentifierKeychainError(status: status)
        }
        guard
            let data = result as? Data,
            let value = String(data: data, encoding: .utf8),
            !value.isEmpty
        else {
            throw DeviceIdentifierKeychainError(status: errSecDecode)
        }
        return value
    }

    func saveDeviceIdentifier(_ value: String) throws {
        let data = Data(value.utf8)
        var item = baseQuery
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(item as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return
        }
        guard addStatus == errSecDuplicateItem else {
            throw DeviceIdentifierKeychainError(status: addStatus)
        }

        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        guard updateStatus == errSecSuccess else {
            throw DeviceIdentifierKeychainError(status: updateStatus)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
    }
}

@MainActor
final class DeviceIdentifierService {
    private let storage: any DeviceIdentifierStoring
    private let idfvProvider: () -> UUID?

    init(
        storage: (any DeviceIdentifierStoring)? = nil,
        idfvProvider: (() -> UUID?)? = nil
    ) {
        self.storage = storage ?? KeychainDeviceIdentifierStore()
        self.idfvProvider = idfvProvider ?? { UIDevice.current.identifierForVendor }
    }

    func deviceIdentifier() throws -> String {
        if let storedIdentifier = try storage.loadDeviceIdentifier() {
            return storedIdentifier
        }

        let identifier = (idfvProvider() ?? UUID()).uuidString
        try storage.saveDeviceIdentifier(identifier)
        return identifier
    }
}
