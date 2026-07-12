import Foundation
import Security

/// Keychain-backed trial marker. One generic-password item per
/// (service, account) pair. Inject a per-test service so tests are hermetic.
public struct KeychainTrialMarkerStore: TrialMarkerStore {
    public let service: String
    public let account: String

    public init(service: String, account: String = "trial-marker") {
        self.service = service
        self.account = account
    }

    public func read() throws -> TrialMarker? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw TrialMarkerError.markerCorrupt(reason: "keychain item held no data")
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            do {
                return try decoder.decode(TrialMarker.self, from: data)
            } catch {
                throw TrialMarkerError.markerCorrupt(reason: String(describing: error))
            }
        case errSecItemNotFound:
            return nil
        default:
            throw TrialMarkerError.keychainReadFailed(status: status)
        }
    }

    @discardableResult
    public func startIfAbsent(now: Date) throws -> TrialMarker {
        if let existing = try read() { return existing }
        let marker = TrialMarker(startedAt: now)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data: Data
        do {
            data = try encoder.encode(marker)
        } catch {
            throw TrialMarkerError.markerEncodingFailed(underlying: error)
        }
        var query = baseQuery
        query[kSecValueData as String] = data
        #if os(iOS)
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #endif
        let status = SecItemAdd(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return marker
        case errSecDuplicateItem:
            // Lost a race with a concurrent start. The stored marker wins.
            if let existing = try read() { return existing }
            throw TrialMarkerError.keychainWriteFailed(status: status)
        default:
            throw TrialMarkerError.keychainWriteFailed(status: status)
        }
    }

    public func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TrialMarkerError.keychainDeleteFailed(status: status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
