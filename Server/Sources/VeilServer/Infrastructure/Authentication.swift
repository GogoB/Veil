import Fluent
import Vapor

struct AuthenticatedAccount: Authenticatable, Sendable {
    let accountID: UUID
    let profileID: UUID
    let deviceID: UUID
}

struct SessionAuthenticator: AsyncBearerAuthenticator {
    func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        let digest = SecureValue.digest(bearer.token)
        guard let session = try await SessionRecord.query(on: request.db)
            .filter(\.$tokenDigest == digest)
            .filter(\.$revokedAt == nil)
            .filter(\.$expiresAt > Date())
            .first(),
              let account = try await AccountRecord.find(session.accountID, on: request.db),
              let device = try await DeviceRecord.find(session.deviceID, on: request.db),
              device.revokedAt == nil,
              let accountID = account.id,
              let deviceID = device.id else {
            return
        }
        request.auth.login(AuthenticatedAccount(accountID: accountID, profileID: account.profileID, deviceID: deviceID))
    }
}

extension Request {
    var authenticatedAccount: AuthenticatedAccount {
        get throws { try self.auth.require(AuthenticatedAccount.self) }
    }
}
