import Fluent
import Foundation

struct OwnershipService: Sendable {
    func record(
        kind: String,
        contentID: UUID,
        accountID: UUID,
        enforcementToken: String,
        cipher: OwnershipCipher,
        database: any Database
    ) async throws {
        let record = try OwnershipRecord(
            contentKind: kind,
            contentID: contentID,
            sealedAccountID: cipher.seal(accountID: accountID),
            enforcementDigest: cipher.enforcementDigest(enforcementToken)
        )
        try await record.create(on: database)
    }

    func ownerID(kind: String, contentID: UUID, cipher: OwnershipCipher, database: any Database) async throws -> UUID? {
        guard let record = try await OwnershipRecord.query(on: database)
            .filter(\.$contentKind == kind)
            .filter(\.$contentID == contentID)
            .first() else { return nil }
        return try cipher.open(record.sealedAccountID)
    }

    func requireCreator(
        kind: String,
        contentID: UUID,
        accountID: UUID,
        cipher: OwnershipCipher,
        database: any Database
    ) async throws {
        guard try await self.ownerID(kind: kind, contentID: contentID, cipher: cipher, database: database) == accountID else {
            throw APIError.forbidden("Only the creator can change this content")
        }
    }

    func enforcementSubject(token: String, cipher: OwnershipCipher, database: any Database) async throws -> UUID? {
        let digest = cipher.enforcementDigest(token)
        guard let record = try await OwnershipRecord.query(on: database)
            .filter(\.$enforcementDigest == digest).first() else { return nil }
        return try cipher.open(record.sealedAccountID)
    }
}
