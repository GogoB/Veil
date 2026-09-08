import Crypto
import Foundation
import Vapor

enum SecureValue {
    static func token(byteCount: Int = 32) -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<byteCount).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func keyedDigest(_ value: String, key: SymmetricKey) -> String {
        HMAC<SHA256>.authenticationCode(for: Data(value.utf8), using: key)
            .map { String(format: "%02x", $0) }.joined()
    }
}

struct OwnershipCipher: @unchecked Sendable {
    private let key: SymmetricKey

    init(base64Key: String) throws {
        guard let data = Data(base64Encoded: base64Key), data.count == 32 else {
            throw ConfigurationError.invalidOwnershipKey
        }
        self.key = SymmetricKey(data: data)
    }

    func seal(accountID: UUID) throws -> Data {
        try self.sealString(accountID.uuidString)
    }

    func sealString(_ value: String) throws -> Data {
        let sealed = try AES.GCM.seal(Data(value.utf8), using: self.key)
        guard let combined = sealed.combined else { throw ConfigurationError.cipherFailure }
        return combined
    }

    func open(_ data: Data) throws -> UUID {
        guard let id = UUID(uuidString: try self.openString(data)) else {
            throw ConfigurationError.cipherFailure
        }
        return id
    }

    func openString(_ data: Data) throws -> String {
        let box = try AES.GCM.SealedBox(combined: data)
        let plaintext = try AES.GCM.open(box, using: self.key)
        guard let raw = String(data: plaintext, encoding: .utf8) else { throw ConfigurationError.cipherFailure }
        return raw
    }

    func enforcementDigest(_ token: String) -> String {
        SecureValue.keyedDigest(token, key: self.key)
    }

    func rotatingNetworkDigest(_ address: String, now: Date = .now) -> String {
        let day = Int(now.timeIntervalSince1970 / 86_400)
        return SecureValue.keyedDigest("\(day):\(address)", key: self.key)
    }
}

enum ConfigurationError: Error {
    case invalidOwnershipKey
    case cipherFailure
}

struct OwnershipCipherKey: StorageKey {
    typealias Value = OwnershipCipher
}

extension Application {
    var ownershipCipher: OwnershipCipher {
        get {
            guard let value = self.storage[OwnershipCipherKey.self] else {
                fatalError("OwnershipCipher was not configured")
            }
            return value
        }
        set { self.storage[OwnershipCipherKey.self] = newValue }
    }
}

extension Request {
    var ownershipCipher: OwnershipCipher { self.application.ownershipCipher }
}
