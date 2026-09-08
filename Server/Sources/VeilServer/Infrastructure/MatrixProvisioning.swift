import Crypto
import Fluent
import Foundation
import Vapor
import VeilShared

struct MatrixProvisionedAccount: Sendable {
    let userID: String
    let password: String
    let accessToken: String
    let deviceID: String
}

protocol MatrixProvisioning: Sendable {
    var publicHomeserverURL: URL { get }
    func register(accountID: UUID, deviceID: UUID, client: any Client) async throws -> MatrixProvisionedAccount
    func recover(_ account: MatrixProvisionedAccount, deviceID: UUID, client: any Client) async throws -> MatrixProvisionedAccount
    func createEncryptedDirectRoom(
        creator: MatrixProvisionedAccount,
        inviteeUserID: String,
        client: any Client
    ) async throws -> String
}

struct SynapseSharedSecretProvisioner: MatrixProvisioning {
    let internalHomeserverURL: String
    let publicHomeserverURL: URL
    private let registrationSecret: String

    init(internalHomeserverURL: String, publicHomeserverURL: URL, registrationSecret: String) {
        self.internalHomeserverURL = internalHomeserverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.publicHomeserverURL = publicHomeserverURL
        self.registrationSecret = registrationSecret
    }

    func register(accountID: UUID, deviceID: UUID, client: any Client) async throws -> MatrixProvisionedAccount {
        let endpoint = URI(string: self.internalHomeserverURL + "/_synapse/admin/v1/register")
        let nonceResponse = try await client.get(endpoint)
        guard nonceResponse.status == .ok else { throw MatrixProvisioningError.unavailable }
        let nonce = try nonceResponse.content.decode(NonceResponse.self).nonce
        let username = "v_" + accountID.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let password = SecureValue.token(byteCount: 36)
        let macSource = [nonce, username, password, "notadmin"].joined(separator: "\0")
        let mac = HMAC<Insecure.SHA1>.authenticationCode(
            for: Data(macSource.utf8),
            using: SymmetricKey(data: Data(self.registrationSecret.utf8))
        ).map { String(format: "%02x", $0) }.joined()
        let response = try await client.post(endpoint) { request in
            try request.content.encode(RegisterRequest(
                nonce: nonce,
                username: username,
                password: password,
                admin: false,
                mac: mac,
                displayname: "Veil user"
            ))
        }
        guard response.status == .ok else { throw MatrixProvisioningError.rejected }
        let session = try response.content.decode(SessionResponse.self)
        return MatrixProvisionedAccount(
            userID: session.userID,
            password: password,
            accessToken: session.accessToken,
            deviceID: session.deviceID
        )
    }

    func recover(_ account: MatrixProvisionedAccount, deviceID: UUID, client: any Client) async throws -> MatrixProvisionedAccount {
        let logoutEndpoint = URI(string: self.internalHomeserverURL + "/_matrix/client/v3/logout/all")
        _ = try? await client.post(logoutEndpoint) { request in
            request.headers.bearerAuthorization = BearerAuthorization(token: account.accessToken)
        }

        let loginEndpoint = URI(string: self.internalHomeserverURL + "/_matrix/client/v3/login")
        let response = try await client.post(loginEndpoint) { request in
            try request.content.encode(LoginRequest(
                type: "m.login.password",
                identifier: .init(type: "m.id.user", user: account.userID),
                password: account.password,
                deviceID: "veil_" + deviceID.uuidString.lowercased(),
                initialDeviceDisplayName: "Veil recovery device"
            ))
        }
        guard response.status == .ok else { throw MatrixProvisioningError.rejected }
        let session = try response.content.decode(SessionResponse.self)
        return MatrixProvisionedAccount(
            userID: session.userID,
            password: account.password,
            accessToken: session.accessToken,
            deviceID: session.deviceID
        )
    }

    func createEncryptedDirectRoom(
        creator: MatrixProvisionedAccount,
        inviteeUserID: String,
        client: any Client
    ) async throws -> String {
        let endpoint = URI(string: self.internalHomeserverURL + "/_matrix/client/v3/createRoom")
        let response = try await client.post(endpoint) { request in
            request.headers.bearerAuthorization = BearerAuthorization(token: creator.accessToken)
            try request.content.encode(CreateRoomRequest(inviteeUserID: inviteeUserID))
        }
        guard response.status == .ok else { throw MatrixProvisioningError.rejected }
        return try response.content.decode(CreateRoomResponse.self).roomID
    }
}

enum MatrixProvisioningError: Error {
    case unavailable
    case rejected
}

private struct NonceResponse: Content { let nonce: String }

private struct RegisterRequest: Content {
    let nonce: String
    let username: String
    let password: String
    let admin: Bool
    let mac: String
    let displayname: String
}

private struct LoginIdentifier: Content {
    let type: String
    let user: String
}

private struct LoginRequest: Content {
    let type: String
    let identifier: LoginIdentifier
    let password: String
    let deviceID: String
    let initialDeviceDisplayName: String

    enum CodingKeys: String, CodingKey {
        case type, identifier, password
        case deviceID = "device_id"
        case initialDeviceDisplayName = "initial_device_display_name"
    }
}

private struct SessionResponse: Content {
    let accessToken: String
    let userID: String
    let deviceID: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case userID = "user_id"
        case deviceID = "device_id"
    }
}

private struct CreateRoomRequest: Content {
    let preset = "trusted_private_chat"
    let isDirect = true
    let invite: [String]
    let initialState = [
        InitialState(
            type: "m.room.encryption",
            stateKey: "",
            content: .init(
                algorithm: "m.megolm.v1.aes-sha2",
                rotationPeriodMilliseconds: 604_800_000,
                rotationPeriodMessages: 100
            )
        )
    ]
    let creationContent = CreationContent(federates: false)

    init(inviteeUserID: String) {
        self.invite = [inviteeUserID]
    }

    enum CodingKeys: String, CodingKey {
        case preset, invite
        case isDirect = "is_direct"
        case initialState = "initial_state"
        case creationContent = "creation_content"
    }
}

private struct InitialState: Content {
    let type: String
    let stateKey: String
    let content: EncryptionContent

    enum CodingKeys: String, CodingKey {
        case type, content
        case stateKey = "state_key"
    }
}

private struct EncryptionContent: Content {
    let algorithm: String
    let rotationPeriodMilliseconds: Int
    let rotationPeriodMessages: Int

    enum CodingKeys: String, CodingKey {
        case algorithm
        case rotationPeriodMilliseconds = "rotation_period_ms"
        case rotationPeriodMessages = "rotation_period_msgs"
    }
}

private struct CreationContent: Content {
    let federates: Bool

    enum CodingKeys: String, CodingKey {
        case federates = "m.federate"
    }
}

private struct CreateRoomResponse: Content {
    let roomID: String

    enum CodingKeys: String, CodingKey {
        case roomID = "room_id"
    }
}

private struct MatrixProvisionerKey: StorageKey {
    typealias Value = any MatrixProvisioning
}

extension Application {
    var matrixProvisioner: (any MatrixProvisioning)? {
        get { self.storage[MatrixProvisionerKey.self] }
        set { self.storage[MatrixProvisionerKey.self] = newValue }
    }
}

extension Request {
    func storeMatrixAccount(_ account: MatrixProvisionedAccount, for accountID: UUID) async throws {
        let record = try await MatrixAccountRecord.query(on: self.db).filter(\.$accountID == accountID).first() ?? MatrixAccountRecord()
        if record.id == nil { record.id = UUID(); record.accountID = accountID }
        record.sealedUserID = try self.ownershipCipher.sealString(account.userID)
        record.sealedPassword = try self.ownershipCipher.sealString(account.password)
        record.sealedAccessToken = try self.ownershipCipher.sealString(account.accessToken)
        record.sealedDeviceID = try self.ownershipCipher.sealString(account.deviceID)
        if record.$id.exists { try await record.update(on: self.db) } else { try await record.create(on: self.db) }
    }

    func loadMatrixAccount(for accountID: UUID) async throws -> MatrixProvisionedAccount? {
        guard let record = try await MatrixAccountRecord.query(on: self.db).filter(\.$accountID == accountID).first() else { return nil }
        return try MatrixProvisionedAccount(
            userID: self.ownershipCipher.openString(record.sealedUserID),
            password: self.ownershipCipher.openString(record.sealedPassword),
            accessToken: self.ownershipCipher.openString(record.sealedAccessToken),
            deviceID: self.ownershipCipher.openString(record.sealedDeviceID)
        )
    }
}
