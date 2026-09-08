import Fluent
import Foundation
import Vapor
import VeilShared

struct ConversationService: Sendable {
    func participant(_ accountID: UUID, in conversation: ConversationRecord) -> Bool {
        conversation.creatorAccountID == accountID || conversation.recipientAccountID == accountID
    }

    func otherAccountID(for accountID: UUID, in conversation: ConversationRecord) throws -> UUID {
        if conversation.creatorAccountID == accountID { return conversation.recipientAccountID }
        if conversation.recipientAccountID == accountID { return conversation.creatorAccountID }
        throw APIError.forbidden("Conversation is unavailable")
    }

    func presentation(_ record: ConversationRecord, viewer: AuthenticatedAccount, request: Request) async throws -> Conversation {
        guard let id = record.id else { throw Abort(.internalServerError) }
        let otherID = try self.otherAccountID(for: viewer.accountID, in: record)
        let actor: ActorPresentation
        if record.identity == ConversationIdentity.identified.rawValue {
            guard let otherAccount = try await AccountRecord.find(otherID, on: request.db) else { throw Abort(.internalServerError) }
            actor = try ActorPresentation(
                kind: .profile,
                role: .participant,
                profile: try await PublicPresenter().summary(profileID: otherAccount.profileID, database: request.db)
            )
        } else {
            let identities = try await ConversationIdentityRecord.query(on: request.db)
                .filter(\.$conversationID == id).all()
            guard let value = try identities.first(where: {
                try request.ownershipCipher.open($0.sealedAccountID) == otherID
            }) else { throw Abort(.internalServerError) }
            actor = try ActorPresentation(
                kind: value.alias == nil ? .sigil : .generatedAlias,
                role: .participant,
                threadAlias: value.alias,
                sigil: value.sigil,
                enforcementToken: value.enforcementToken
            )
        }
        return Conversation(
            id: id,
            identity: ConversationIdentity(rawValue: record.identity) ?? .anonymous,
            actor: actor,
            isRequest: record.recipientAccountID == viewer.accountID && record.isRequest && !record.isAccepted,
            isAccepted: record.isAccepted,
            lastEventAt: record.lastEventAt,
            disappearingSeconds: record.disappearingSeconds,
            readReceiptsEnabled: record.readReceiptsEnabled,
            typingIndicatorsEnabled: record.typingIndicatorsEnabled
        )
    }

    func actor(for accountID: UUID, conversation: ConversationRecord, request: Request) async throws -> ActorPresentation {
        guard let conversationID = conversation.id else { throw Abort(.internalServerError) }
        if conversation.identity == ConversationIdentity.identified.rawValue {
            guard let account = try await AccountRecord.find(accountID, on: request.db) else { throw Abort(.internalServerError) }
            return try ActorPresentation(
                kind: .profile,
                role: .participant,
                profile: try await PublicPresenter().summary(profileID: account.profileID, database: request.db)
            )
        }
        let rows = try await ConversationIdentityRecord.query(on: request.db).filter(\.$conversationID == conversationID).all()
        guard let row = try rows.first(where: { try request.ownershipCipher.open($0.sealedAccountID) == accountID }) else {
            throw Abort(.internalServerError)
        }
        return try ActorPresentation(
            kind: row.alias == nil ? .sigil : .generatedAlias,
            role: .participant,
            threadAlias: row.alias,
            sigil: row.sigil,
            enforcementToken: row.enforcementToken
        )
    }
}
