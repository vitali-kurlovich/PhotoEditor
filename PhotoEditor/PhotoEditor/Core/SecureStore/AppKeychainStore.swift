//
//  Created by Kurlovich Vitali on 10/27/26.
//

import Security
import SwiftUI

@propertyWrapper
struct AppKeychainStore: DynamicProperty {
    @State
    private var storage: KeyStorage

    init(_ service: String = Bundle.main.bundleIdentifier ?? "", key: String) {
        _storage = State(initialValue: KeyStorage(service, key: key))
    }

    @Observable
    final class KeyStorage {
        let key: String

        private let storage: KeychainStore
        init(_ service: String, key: String) {
            storage = KeychainStore(service: service)
            self.key = key
        }

        var current: String {
            get {
                storage.read(key) ?? ""
            }
            set {
                guard newValue != current else { return }

                try? storage.save(newValue, forKey: key)
            }
        }
    }

    var wrappedValue: String {
        get {
            storage.current
        }
        nonmutating set {
            storage.current = newValue
        }
    }

    /// `$value` gives access to bindings and undo/redo controls.
    var projectedValue: Binding<String> {
        Binding(
            get: {
                storage.current
            },

            set: {
                storage.current = $0
            }
        )
    }
}

private struct KeychainStore {
    let service: String

    init(
        service: String = Bundle.main.bundleIdentifier ?? ""

    ) {
        self.service = service
    }

    func save(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw NSError(domain: "Keychain", code: -1)
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        // Remove an existing item so save() behaves like an upsert.
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] =
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return token
    }

    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
