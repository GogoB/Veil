import Foundation
import Security
import VeilShared

@MainActor
final class AppFlowStore: ObservableObject {
    @Published private(set) var hasConfirmedAdultStatement: Bool
    @Published private(set) var hasLocalDemoAccount: Bool
    @Published private(set) var username: String
    @Published private(set) var accountMode: AccountMode
    @Published private(set) var isDemoMode: Bool
    @Published private(set) var sessionToken: String?
    @Published private(set) var pendingRecoveryCode: String?
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    private let defaults: UserDefaults
    private let keychain: LocalKeychain
    private let apiClient: APIClient

    init(
        defaults: UserDefaults = .standard,
        keychain: LocalKeychain = .init(),
        apiClient: APIClient = .init(),
        previewingMainApp: Bool = false
    ) {
        self.defaults = defaults
        self.keychain = keychain
        self.apiClient = apiClient
        hasConfirmedAdultStatement = previewingMainApp || keychain.bool(for: Keys.adultConfirmation)
        hasLocalDemoAccount = previewingMainApp || defaults.bool(forKey: Keys.hasAccount)
        username = defaults.string(forKey: Keys.username) ?? "noor"
        accountMode = AccountMode(rawValue: defaults.string(forKey: Keys.accountMode) ?? "") ?? .deviceOnly
        isDemoMode = previewingMainApp || defaults.bool(forKey: Keys.demoMode)
        sessionToken = previewingMainApp ? nil : keychain.string(for: Keys.sessionToken)
        pendingRecoveryCode = nil
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
        isDemoMode = true
        sessionToken = nil
        hasLocalDemoAccount = true
        defaults.set(normalized, forKey: Keys.username)
        defaults.set(mode.rawValue, forKey: Keys.accountMode)
        defaults.set(true, forKey: Keys.demoMode)
        defaults.set(true, forKey: Keys.hasAccount)
    }

    func createAccount(username: String, mode: AccountMode, passphrase: String?) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let publicKey = try DeviceCredentialStore(keychain: keychain).publicKey()
            guard let sharedMode = VeilShared.AccountMode(rawValue: mode.rawValue) else {
                throw APIClientError.invalidResponse
            }
            let result = try await apiClient.createAccount(
                username: username,
                mode: sharedMode,
                devicePublicKey: publicKey,
                passphrase: mode == .recoverable ? passphrase : nil
            )
            guard keychain.set(result.sessionToken, for: Keys.sessionToken) else {
                throw DeviceCredentialError.keychainFailure
            }
            self.username = result.profile.username
            accountMode = mode
            sessionToken = result.sessionToken
            pendingRecoveryCode = result.recoveryCode
            isDemoMode = false
            hasLocalDemoAccount = true
            defaults.set(self.username, forKey: Keys.username)
            defaults.set(mode.rawValue, forKey: Keys.accountMode)
            defaults.set(false, forKey: Keys.demoMode)
            defaults.set(true, forKey: Keys.hasAccount)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func recoverAccount(username: String, passphrase: String, recoveryCode: String) async -> Bool {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let publicKey = try DeviceCredentialStore(keychain: keychain).publicKey(replacingExisting: true)
            let result = try await apiClient.recoverAccount(
                username: username,
                passphrase: passphrase,
                recoveryCode: recoveryCode,
                replacementDevicePublicKey: publicKey
            )
            guard keychain.set(result.sessionToken, for: Keys.sessionToken) else {
                throw DeviceCredentialError.keychainFailure
            }
            self.username = result.profile.username
            accountMode = .recoverable
            sessionToken = result.sessionToken
            pendingRecoveryCode = result.recoveryCode
            isDemoMode = false
            hasLocalDemoAccount = true
            defaults.set(self.username, forKey: Keys.username)
            defaults.set(AccountMode.recoverable.rawValue, forKey: Keys.accountMode)
            defaults.set(false, forKey: Keys.demoMode)
            defaults.set(true, forKey: Keys.hasAccount)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func clearRecoveryCodeFromScreen() {
        pendingRecoveryCode = nil
    }

    func resetLocalDemoAccount() {
        hasLocalDemoAccount = false
        isDemoMode = false
        sessionToken = nil
        pendingRecoveryCode = nil
        keychain.delete(Keys.sessionToken)
        DeviceCredentialStore(keychain: keychain).remove()
        defaults.removeObject(forKey: Keys.hasAccount)
        defaults.removeObject(forKey: Keys.username)
        defaults.removeObject(forKey: Keys.accountMode)
        defaults.removeObject(forKey: Keys.demoMode)
    }

    func signOut() async {
        if let sessionToken {
            try? await apiClient.logout(token: sessionToken)
        }
        resetLocalDemoAccount()
    }

    private enum Keys {
        static let adultConfirmation = "veil.local.adult-confirmation"
        static let hasAccount = "veil.demo.has-account"
        static let username = "veil.demo.username"
        static let accountMode = "veil.demo.account-mode"
        static let demoMode = "veil.demo.mode"
        static let sessionToken = "veil.api.session-token"
    }
}

struct LocalKeychain {
    private let service = "com.veil.poc.local"

    func bool(for account: String) -> Bool {
        string(for: account) == "true"
    }

    func string(for account: String) -> String? {
        data(for: account).flatMap { String(data: $0, encoding: .utf8) }
    }

    func data(for account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return data
    }

    @discardableResult
    func set(_ value: Bool, for account: String) -> Bool {
        set(String(value), for: account)
    }

    @discardableResult
    func set(_ value: String, for account: String) -> Bool {
        set(Data(value.utf8), for: account)
    }

    @discardableResult
    func set(_ data: Data, for account: String) -> Bool {
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

    func delete(_ account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
