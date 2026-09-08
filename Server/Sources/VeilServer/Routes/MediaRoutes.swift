import Fluent
import Foundation
import Vapor
import VeilShared

struct MediaRoutes: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let authenticated = routes.grouped(SessionAuthenticator()).grouped(AuthenticatedAccount.guardMiddleware())
        authenticated.on(.POST, "media", "images", body: .collect(maxSize: "13mb"), use: self.upload)
        authenticated.delete("media", ":mediaID", use: self.delete)
    }

    private func upload(_ request: Request) async throws -> Media {
        let account = try request.authenticatedAccount
        try await request.application.rateLimiter.check(policy: .upload, subject: account.accountID.uuidString, request: request)
        let payload = try request.content.decode(ImageUpload.self)
        let data = Data(buffer: payload.file.data)
        try await self.enforceQuota(accountID: account.accountID, incomingBytes: data.count, request: request)
        let processed = try await request.application.imageProcessor.sanitize(
            data: data,
            declaredWidth: payload.width,
            declaredHeight: payload.height,
            mimeType: payload.file.contentType?.description ?? "application/octet-stream"
        )
        let id = UUID()
        let objectName = "\(UUID().uuidString.lowercased()).jpg"
        let uploadDirectory = Environment.get("UPLOAD_DIRECTORY") ?? request.application.directory.publicDirectory + "uploads"
        let destination = URL(fileURLWithPath: uploadDirectory, isDirectory: true).appendingPathComponent(objectName)
        try processed.data.write(to: destination, options: .atomic)
        let record = MediaRecord(
            id: id,
            objectName: objectName,
            mimeType: processed.mimeType,
            width: processed.width,
            height: processed.height,
            byteCount: processed.data.count
        )
        try await record.create(on: request.db)
        let enforcementToken = SecureValue.token()
        try await OwnershipService().record(
            kind: "media", contentID: id, accountID: account.accountID,
            enforcementToken: enforcementToken, cipher: request.ownershipCipher, database: request.db
        )
        return Media(id: id, url: URL(string: "/uploads/\(objectName)")!, width: processed.width, height: processed.height)
    }

    private func delete(_ request: Request) async throws -> EmptyResponse {
        let account = try request.authenticatedAccount
        let id = try request.parameters.require("mediaID", as: UUID.self)
        try await OwnershipService().requireCreator(
            kind: "media", contentID: id, accountID: account.accountID,
            cipher: request.ownershipCipher, database: request.db
        )
        guard let record = try await MediaRecord.find(id, on: request.db) else { return .success }
        let used = try await PostRecord.query(on: request.db).all().contains { $0.mediaIDs.contains(id) && $0.deletedAt == nil }
        guard !used else { throw APIError.conflict("Media is attached to a post") }
        let uploadDirectory = Environment.get("UPLOAD_DIRECTORY") ?? request.application.directory.publicDirectory + "uploads"
        let path = URL(fileURLWithPath: uploadDirectory, isDirectory: true).appendingPathComponent(record.objectName)
        try? FileManager.default.removeItem(at: path)
        try await record.delete(on: request.db)
        return .success
    }

    private func enforceQuota(accountID: UUID, incomingBytes: Int, request: Request) async throws {
        let ownership = try await OwnershipRecord.query(on: request.db).filter(\.$contentKind == "media").all()
        var mediaIDs: [UUID] = []
        for row in ownership where try request.ownershipCipher.open(row.sealedAccountID) == accountID {
            mediaIDs.append(row.contentID)
        }
        var total = incomingBytes
        for id in mediaIDs {
            total += try await MediaRecord.find(id, on: request.db)?.byteCount ?? 0
        }
        guard total <= 250 * 1_024 * 1_024 else { throw APIError.forbidden("Local upload quota reached") }
    }
}

struct ImageUpload: Content {
    let file: File
    let width: Int
    let height: Int
}
