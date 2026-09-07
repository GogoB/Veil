import Foundation
import Security

@MainActor
final class AppFlowStore: ObservableObject {
    @Published private(set) var hasConfirmedAdultStatement: Bool
    @Published private(set) var hasLocalDemoAccount: Bool
    @Published private(set) var username: String
    @Published private(set) var accountMode: AccountMode

    private let defaults: UserDefaults
    private let keychain: LocalKeychain

    init(
        defaults: UserDefaults = .standard,
        keychain: LocalKeychain = .init(),
        previewingMainApp: Bool = false
    ) {
        self.defaults = defaults
        self.keychain = keychain
        hasConfirmedAdultStatement = previewingMainApp || keychain.bool(for: Keys.adultConfirmation)
        hasLocalDemoAccount = previewingMainApp || defaults.bool(forKey: Keys.hasAccount)
        username = defaults.string(forKey: Keys.username) ?? "noor"
        accountMode = AccountMode(rawValue: defaults.string(forKey: Keys.accountMode) ?? "") ?? .deviceOnly
    }

    var routeID: String {
        "\(hasConfirmedAdultStatement)-\(hasLocalDemoAccount)"
    }

    func confirmAdultStatement() {
        guard keychain.set(true, for: Keys.adultConfirmation) else { return }
        hasConfirmedAdultStatement = true
    }

    func createLocalDemoAccount(username: String, mode: AccountMode) {
        let normalized = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return }
        self.username = normalized
        accountMode = mode
        hasLocalDemoAccount = true
        defaults.set(normalized, forKey: Keys.username)
        defaults.set(mode.rawValue, forKey: Keys.accountMode)
        defaults.set(true, forKey: Keys.hasAccount)
    }

    func resetLocalDemoAccount() {
        hasLocalDemoAccount = false
        defaults.removeObject(forKey: Keys.hasAccount)
        defaults.removeObject(forKey: Keys.username)
        defaults.removeObject(forKey: Keys.accountMode)
    }

    private enum Keys {
        static let adultConfirmation = "veil.local.adult-confirmation"
        static let hasAccount = "veil.demo.has-account"
        static let username = "veil.demo.username"
        static let accountMode = "veil.demo.account-mode"
    }
}

struct LocalKeychain {
    private let service = "com.veil.poc.local"

    func bool(for account: String) -> Bool {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return false
        }
        return value == "true"
    }

    @discardableResult
    func set(_ value: Bool, for account: String) -> Bool {
        let data = Data(String(value).utf8)
        let query = baseQuery(account: account)
        let attributes: [String: Any] = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return true }
        if status != errSecItemNotFound { return false }

        var insertion = query
        insertion[kSecValueData as String] = data
        insertion[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(insertion as CFDictionary, nil) == errSecSuccess
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
