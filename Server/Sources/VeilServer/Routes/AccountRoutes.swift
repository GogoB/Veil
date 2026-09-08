import Fluent
import Vapor
import VeilShared

struct AccountRoutes: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let accounts = routes.grouped("accounts")
        accounts.post("create", use: self.create)
        accounts.post("recover", use: self.recover)

        let authenticated = accounts.grouped(SessionAuthenticator()).grouped(AuthenticatedAccount.guardMiddleware())
        authenticated.get("me", use: self.current)
        authenticated.post("logout", use: self.logout)
        authenticated.get("devices", use: self.devices)
        authenticated.get("messaging-session", use: self.messagingSession)
    }

    private func create(_ request: Request) async throws -> SessionEnvelope {
        try await AccountService().create(try request.content.decode(AccountCreateRequest.self), request: request)
    }

    private func recover(_ request: Request) async throws -> SessionEnvelope {
        try await AccountService().recover(try request.content.decode(AccountRecoveryRequest.self), request: request)
    }

    private func current(_ request: Request) async throws -> Profile {
        let identity = try request.authenticatedAccount
        guard let profile = try await ProfileRecord.find(identity.profileID, on: request.db) else {
            throw Abort(.unauthorized)
        }
        return try await PublicPresenter().profile(profile, viewer: identity, database: request.db)
    }

    private func logout(_ request: Request) async throws -> EmptyResponse {
        let identity = try request.authenticatedAccount
        let digest = request.headers.bearerAuthorization.map { SecureValue.digest($0.token) }
        if let digest, let session = try await SessionRecord.query(on: request.db)
            .filter(\.$accountID == identity.accountID).filter(\.$tokenDigest == digest).first() {
            session.revokedAt = Date()
            try await session.update(on: request.db)
        }
        return .success
    }

    private func devices(_ request: Request) async throws -> [DeviceResponse] {
        let identity = try request.authenticatedAccount
        return try await DeviceRecord.query(on: request.db).filter(\.$accountID == identity.accountID).all().map {
            DeviceResponse(id: try $0.requireID(), createdAt: $0.createdAt, revokedAt: $0.revokedAt, isCurrent: $0.id == identity.deviceID)
        }
    }

    private func messagingSession(_ request: Request) async throws -> MessagingSessionConfiguration {
        let identity = try request.authenticatedAccount
        guard let provisioner = request.application.matrixProvisioner,
              let account = try await request.loadMatrixAccount(for: identity.accountID) else {
            throw Abort(.serviceUnavailable, reason: "Messaging is not configured")
        }
        return MessagingSessionConfiguration(
            homeserverURL: provisioner.publicHomeserverURL,
            userID: account.userID,
            accessToken: account.accessToken,
            deviceID: account.deviceID
        )
    }
}

struct DeviceResponse: Content {
    let id: UUID
    let createdAt: Date?
    let revokedAt: Date?
    let isCurrent: Bool
}
