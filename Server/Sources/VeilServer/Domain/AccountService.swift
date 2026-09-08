import Fluent
import Foundation
import Vapor
import VeilShared

struct AccountService: Sendable {
    func create(_ payload: AccountCreateRequest, request: Request) async throws -> SessionEnvelope {
        try await request.application.rateLimiter.check(policy: .signup, subject: request.shortLivedNetworkSubject, request: request)
        try await request.application.appAttestVerifier.verify(
            assertion: request.headers.first(name: "X-Veil-App-Attest"),
            challenge: payload.devicePublicKey,
            request: request
        )
        let username: String
        do { username = try VeilValidation.normalizedUsername(payload.username) }
        catch { throw APIError.invalidInput("Choose a valid, non-reserved username") }
        guard (32...4_096).contains(payload.devicePublicKey.count) else {
            throw APIError.invalidInput("A valid device public key is required")
        }
        guard try await AccountRecord.query(on: request.db).filter(\.$normalizedUsername == username).first() == nil else {
            throw APIError.conflict("That username is already in use")
        }
        guard try await DeviceRecord.query(on: request.db).filter(\.$publicKey == payload.devicePublicKey).first() == nil else {
            throw APIError.conflict("That device credential is already enrolled")
        }

        var recoveryCode: String?
        var passphraseHash: String?
        var recoveryHash: String?
        switch payload.mode {
        case .deviceOnly:
            guard payload.securityPassphrase == nil else {
                throw APIError.invalidInput("Device-only accounts do not accept a recovery passphrase")
            }
        case .recoverable:
            guard let passphrase = payload.securityPassphrase, passphrase.count >= 12 else {
                throw APIError.invalidInput("A recoverable account requires a passphrase of at least 12 characters")
            }
            let code = SecureValue.token(byteCount: 32)
            recoveryCode = code
            passphraseHash = try Bcrypt.hash(passphrase, cost: 12)
            recoveryHash = try Bcrypt.hash(code, cost: 12)
        }

        let profile = ProfileRecord(username: username)
        try await profile.create(on: request.db)
        guard let profileID = profile.id else { throw Abort(.internalServerError) }

        let account = AccountRecord(
            profileID: profileID,
            normalizedUsername: username,
            accountMode: payload.mode.rawValue,
            passphraseHash: passphraseHash,
            recoveryHash: recoveryHash
        )
        do {
            try await account.create(on: request.db)
        } catch {
            try? await profile.delete(on: request.db)
            throw error
        }
        guard let accountID = account.id else { throw Abort(.internalServerError) }

        let device = DeviceRecord(accountID: accountID, publicKey: payload.devicePublicKey)
        try await device.create(on: request.db)
        guard let deviceID = device.id else { throw Abort(.internalServerError) }
        if let matrix = request.application.matrixProvisioner {
            let provisioned = try await matrix.register(accountID: accountID, deviceID: deviceID, client: request.client)
            try await request.storeMatrixAccount(provisioned, for: accountID)
        }
        let sessionToken = try await self.issueSession(accountID: accountID, deviceID: deviceID, database: request.db)
        let publicProfile = try await PublicPresenter().profile(profile, viewer: nil, database: request.db)
        return SessionEnvelope(
            sessionToken: sessionToken,
            profile: publicProfile,
            recoveryCode: recoveryCode,
            historicalMessagesRequireOldDeviceTransfer: false
        )
    }

    func recover(_ payload: AccountRecoveryRequest, request: Request) async throws -> SessionEnvelope {
        let username: String
        do { username = try VeilValidation.normalizedUsername(payload.username) }
        catch { throw Abort(.unauthorized) }
        guard let account = try await AccountRecord.query(on: request.db)
            .filter(\.$normalizedUsername == username).first(),
              account.accountMode == AccountMode.recoverable.rawValue,
              let passphraseHash = account.passphraseHash,
              let recoveryHash = account.recoveryHash,
              try Bcrypt.verify(payload.securityPassphrase, created: passphraseHash),
              try Bcrypt.verify(payload.recoveryCode, created: recoveryHash),
              let accountID = account.id,
              (32...4_096).contains(payload.replacementDevicePublicKey.count) else {
            throw Abort(.unauthorized, reason: "Both recovery secrets are required")
        }
        guard try await DeviceRecord.query(on: request.db)
            .filter(\.$publicKey == payload.replacementDevicePublicKey).first() == nil else {
            throw APIError.conflict("That device credential is already enrolled")
        }

        let now = Date()
        let sessions = try await SessionRecord.query(on: request.db).filter(\.$accountID == accountID).all()
        for session in sessions { session.revokedAt = now; try await session.update(on: request.db) }
        let devices = try await DeviceRecord.query(on: request.db).filter(\.$accountID == accountID).all()
        for device in devices { device.revokedAt = now; try await device.update(on: request.db) }

        let replacement = DeviceRecord(accountID: accountID, publicKey: payload.replacementDevicePublicKey)
        try await replacement.create(on: request.db)
        guard let deviceID = replacement.id else { throw Abort(.internalServerError) }
        if let matrix = request.application.matrixProvisioner,
           let prior = try await request.loadMatrixAccount(for: accountID) {
            let recovered = try await matrix.recover(prior, deviceID: deviceID, client: request.client)
            try await request.storeMatrixAccount(recovered, for: accountID)
        }
        let replacementCode = SecureValue.token(byteCount: 32)
        account.recoveryHash = try Bcrypt.hash(replacementCode, cost: 12)
        try await account.update(on: request.db)
        let sessionToken = try await self.issueSession(accountID: accountID, deviceID: deviceID, database: request.db)
        guard let profile = try await ProfileRecord.find(account.profileID, on: request.db) else { throw Abort(.internalServerError) }
        return SessionEnvelope(
            sessionToken: sessionToken,
            profile: try await PublicPresenter().profile(profile, viewer: nil, database: request.db),
            recoveryCode: replacementCode,
            historicalMessagesRequireOldDeviceTransfer: true
        )
    }

    func issueSession(accountID: UUID, deviceID: UUID, database: any Database) async throws -> String {
        let token = SecureValue.token(byteCount: 32)
        let record = SessionRecord(
            accountID: accountID,
            deviceID: deviceID,
            tokenDigest: SecureValue.digest(token),
            expiresAt: Date().addingTimeInterval(30 * 86_400)
        )
        try await record.create(on: database)
        return token
    }
}
