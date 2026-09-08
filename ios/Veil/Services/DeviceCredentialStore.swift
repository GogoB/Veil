import CryptoKit
import Foundation

struct DeviceCredentialStore {
    private let keychain: LocalKeychain
    private let account = "veil.device.signing-key"

    init(keychain: LocalKeychain = .init()) {
        self.keychain = keychain
    }

    func publicKey(replacingExisting: Bool = false) throws -> String {
        let privateKey: Curve25519.Signing.PrivateKey
        if !replacingExisting,
           let existing = keychain.data(for: account),
           let restored = try? Curve25519.Signing.PrivateKey(rawRepresentation: existing) {
            privateKey = restored
        } else {
            privateKey = Curve25519.Signing.PrivateKey()
            guard keychain.set(privateKey.rawRepresentation, for: account) else {
                throw DeviceCredentialError.keychainFailure
            }
        }
        return privateKey.publicKey.rawRepresentation.base64EncodedString()
    }

    func remove() {
        keychain.delete(account)
    }
}

enum DeviceCredentialError: LocalizedError {
    case keychainFailure

    var errorDescription: String? { "The device credential could not be stored in Keychain." }
}
