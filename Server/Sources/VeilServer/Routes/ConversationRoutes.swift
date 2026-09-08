import Fluent
import Foundation
import Vapor
import VeilShared

struct ConversationRoutes: RouteCollection {
    private let service = ConversationService()

    func boot(routes: any RoutesBuilder) throws {
        let authenticated = routes.grouped(SessionAuthenticator()).grouped(AuthenticatedAccount.guardMiddleware())
        authenticated.post("conversations", use: self.create)
        authenticated.get("conversations", use: self.list)
        authenticated.get("conversations", ":conversationID", "events", use: self.events)
        authenticated.get("conversations", ":conversationID", "messaging-room", use: self.messagingRoom)
        authenticated.post("conversations", ":conversationID", "events", use: self.registerEvent)
        authenticated.delete("conversations", ":conversationID", "events", ":eventID", use: self.deleteForAll)
        authenticated.post("conversations", ":conversationID", "accept", use: self.accept)
        authenticated.post("conversations", ":conversationID", "block", use: self.block)
        authenticated.put("conversations", ":conversationID", "settings", use: self.settings)
    }

    private func create(_ request: Request) async throws -> Conversation {
        let sender = try request.authenticatedAccount
        try await request.application.rateLimiter.check(
            policy: .messageRequest, subject: sender.accountID.uuidString, request: request
        )
        let payload = try request.content.decode(ConversationRequest.self)
        guard payload.encryptedInitialEventID.map({ !$0.isEmpty && $0.count <= 255 }) ?? true else {
            throw APIError.invalidInput("Encrypted event identifier is invalid")
        }

        let recipientID: UUID
        if let sourcePostID = payload.sourcePostID {
            guard let owner = try await OwnershipService().ownerID(
                kind: "post", contentID: sourcePostID,
                cipher: request.ownershipCipher, database: request.db
            ) else { throw APIError.notFound("Post author is unavailable") }
            recipientID = owner
        } else if let profileID = payload.targetProfileID,
                  let recipient = try await AccountRecord.query(on: request.db).filter(\.$profileID == profileID).first(),
                  let id = recipient.id {
            recipientID = id
        } else {
            throw APIError.invalidInput("Choose a profile or anonymous post author")
        }
        guard recipientID != sender.accountID,
              let recipient = try await AccountRecord.find(recipientID, on: request.db) else {
            throw APIError.invalidInput("You cannot message this recipient")
        }
        try await self.requireNoBlock(between: sender.accountID, and: recipientID, request: request)

        let effectiveIdentity: ConversationIdentity = payload.sourcePostID == nil ? payload.identity : .anonymous
        let policy = AnonymousRequestPolicy(rawValue: recipient.anonymousRequestPolicy) ?? .filtered
        let isAnonymous = effectiveIdentity == .anonymous
        if isAnonymous && policy == .disabled {
            throw APIError.forbidden("This profile does not accept anonymous requests")
        }
        let accepted = !isAnonymous || policy == .allow
        if !accepted && (payload.containsMedia || payload.containsLink) {
            throw APIError.forbidden("Filtered requests allow one text-only message until accepted")
        }

        let id = UUID()
        let matrixRoomID: String
        if let matrix = request.application.matrixProvisioner {
            guard let creatorMatrix = try await request.loadMatrixAccount(for: sender.accountID),
                  let recipientMatrix = try await request.loadMatrixAccount(for: recipientID) else {
                throw Abort(.serviceUnavailable, reason: "Messaging accounts are not ready")
            }
            matrixRoomID = try await matrix.createEncryptedDirectRoom(
                creator: creatorMatrix,
                inviteeUserID: recipientMatrix.userID,
                client: request.client
            )
        } else {
            matrixRoomID = "!local-\(id.uuidString.lowercased()):veil"
        }
        let record = ConversationRecord()
        record.id = id; record.identity = effectiveIdentity.rawValue
        record.creatorAccountID = sender.accountID; record.recipientAccountID = recipientID
        record.sourcePostID = payload.sourcePostID
        record.matrixRoomCiphertext = try request.ownershipCipher.sealString(matrixRoomID)
        record.isRequest = !accepted; record.isAccepted = accepted
        record.readReceiptsEnabled = false; record.typingIndicatorsEnabled = false
        record.lastEventAt = nil
        try await record.create(on: request.db)

        if effectiveIdentity == .anonymous {
            try await self.createConversationIdentity(accountID: sender.accountID, conversationID: id, request: request)
            try await self.createConversationIdentity(accountID: recipientID, conversationID: id, request: request)
        }
        if let eventID = payload.encryptedInitialEventID {
            try await self.storeEvent(
                eventID: eventID,
                senderID: sender.accountID,
                conversationID: id,
                sentAt: Date(),
                expiration: nil,
                request: request
            )
            record.lastEventAt = Date()
            try await record.update(on: request.db)
        }
        return try await self.service.presentation(record, viewer: sender, request: request)
    }

    private func list(_ request: Request) async throws -> [Conversation] {
        let viewer = try request.authenticatedAccount
        let records = try await ConversationRecord.query(on: request.db).sort(\.$lastEventAt, .descending).all().filter {
            self.service.participant(viewer.accountID, in: $0) && $0.blockedAt == nil
        }
        var result: [Conversation] = []
        for record in records { result.append(try await self.service.presentation(record, viewer: viewer, request: request)) }
        return result
    }

    private func events(_ request: Request) async throws -> [Message] {
        let viewer = try request.authenticatedAccount
        let conversation = try await self.requireConversation(request, viewer: viewer)
        let conversationID = try conversation.requireID()
        let records = try await MessageEventRecord.query(on: request.db)
            .filter(\.$conversationID == conversationID).sort(\.$sentAt).all()
        var result: [Message] = []
        for record in records where record.deletedAt == nil && (record.expiresAt.map { $0 > Date() } ?? true) {
            let senderID = try request.ownershipCipher.open(record.sealedSenderID)
            result.append(Message(
                id: try record.requireID(),
                conversationID: conversationID,
                encryptedEventID: record.encryptedEventID,
                sender: try await self.service.actor(for: senderID, conversation: conversation, request: request),
                sentAt: record.sentAt,
                expiresAt: record.expiresAt,
                deletedForAll: false
            ))
        }
        return result
    }

    private func registerEvent(_ request: Request) async throws -> Message {
        let viewer = try request.authenticatedAccount
        let conversation = try await self.requireConversation(request, viewer: viewer)
        let conversationID = try conversation.requireID()
        let payload = try request.content.decode(EncryptedEventRequest.self)
        guard !payload.encryptedEventID.isEmpty, payload.encryptedEventID.count <= 255 else {
            throw APIError.invalidInput("Encrypted event identifier is invalid")
        }
        if !conversation.isAccepted {
            let priorCount = try await MessageEventRecord.query(on: request.db)
                .filter(\.$conversationID == conversationID).count()
            guard conversation.creatorAccountID == viewer.accountID,
                  priorCount == 0,
                  !payload.containsLink,
                  !payload.containsMedia else {
                throw APIError.forbidden("A filtered request allows one text-only message until it is accepted")
            }
        }
        let expiration = try self.expiration(seconds: payload.disappearingSeconds ?? conversation.disappearingSeconds, from: payload.sentAt)
        let record = try await self.storeEvent(
            eventID: payload.encryptedEventID,
            senderID: viewer.accountID,
            conversationID: conversationID,
            sentAt: payload.sentAt,
            expiration: expiration,
            request: request
        )
        conversation.lastEventAt = payload.sentAt; try await conversation.update(on: request.db)
        return Message(
            id: try record.requireID(),
            conversationID: try conversation.requireID(),
            encryptedEventID: record.encryptedEventID,
            sender: try await self.service.actor(for: viewer.accountID, conversation: conversation, request: request),
            sentAt: record.sentAt,
            expiresAt: record.expiresAt,
            deletedForAll: false
        )
    }

    private func deleteForAll(_ request: Request) async throws -> EmptyResponse {
        let viewer = try request.authenticatedAccount
        let conversation = try await self.requireConversation(request, viewer: viewer)
        let conversationID = try conversation.requireID()
        let eventID = try request.parameters.require("eventID")
        guard let record = try await MessageEventRecord.query(on: request.db)
            .filter(\.$conversationID == conversationID)
            .filter(\.$encryptedEventID == eventID).first(),
              try request.ownershipCipher.open(record.sealedSenderID) == viewer.accountID else {
            throw APIError.notFound("Message event not found")
        }
        record.deletedAt = Date(); try await record.update(on: request.db)
        return .success
    }

    private func accept(_ request: Request) async throws -> Conversation {
        let viewer = try request.authenticatedAccount
        let conversation = try await self.requireConversation(request, viewer: viewer)
        guard conversation.recipientAccountID == viewer.accountID else {
            throw APIError.forbidden("Only the recipient can accept a request")
        }
        conversation.isAccepted = true; conversation.isRequest = false
        try await conversation.update(on: request.db)
        return try await self.service.presentation(conversation, viewer: viewer, request: request)
    }

    private func block(_ request: Request) async throws -> EmptyResponse {
        let viewer = try request.authenticatedAccount
        let conversation = try await self.requireConversation(request, viewer: viewer)
        let other = try self.service.otherAccountID(for: viewer.accountID, in: conversation)
        let digest = request.ownershipCipher.enforcementDigest("account:\(other.uuidString)")
        if try await BlockRecord.query(on: request.db)
            .filter(\.$accountID == viewer.accountID).filter(\.$enforcementDigest == digest).first() == nil {
            let block = BlockRecord(); block.id = UUID(); block.accountID = viewer.accountID; block.enforcementDigest = digest
            try await block.create(on: request.db)
        }
        conversation.blockedAt = Date(); try await conversation.update(on: request.db)
        return .success
    }

    private func settings(_ request: Request) async throws -> Conversation {
        let viewer = try request.authenticatedAccount
        let conversation = try await self.requireConversation(request, viewer: viewer)
        guard conversation.isAccepted else { throw APIError.forbidden("Accept the request before changing settings") }
        let payload = try request.content.decode(ConversationSettingsRequest.self)
        _ = try self.expiration(seconds: payload.disappearingSeconds, from: Date())
        conversation.disappearingSeconds = payload.disappearingSeconds
        conversation.readReceiptsEnabled = payload.readReceiptsEnabled
        conversation.typingIndicatorsEnabled = payload.typingIndicatorsEnabled
        try await conversation.update(on: request.db)
        return try await self.service.presentation(conversation, viewer: viewer, request: request)
    }

    private func requireConversation(_ request: Request, viewer: AuthenticatedAccount) async throws -> ConversationRecord {
        let id = try request.parameters.require("conversationID", as: UUID.self)
        guard let record = try await ConversationRecord.find(id, on: request.db),
              self.service.participant(viewer.accountID, in: record), record.blockedAt == nil else {
            throw APIError.notFound("Conversation not found")
        }
        return record
    }

    private func messagingRoom(_ request: Request) async throws -> MessagingRoomConfiguration {
        let viewer = try request.authenticatedAccount
        let conversation = try await self.requireConversation(request, viewer: viewer)
        return MessagingRoomConfiguration(roomID: try request.ownershipCipher.openString(conversation.matrixRoomCiphertext))
    }

    private func createConversationIdentity(accountID: UUID, conversationID: UUID, request: Request) async throws {
        let identity = IdentityService().conversationIdentity(
            accountID: accountID, conversationID: conversationID, cipher: request.ownershipCipher
        )
        let record = ConversationIdentityRecord(); record.id = UUID(); record.conversationID = conversationID
        record.sealedAccountID = try request.ownershipCipher.seal(accountID: accountID)
        record.alias = identity.alias; record.sigil = identity.sigil; record.enforcementToken = identity.enforcementToken
        record.enforcementDigest = request.ownershipCipher.enforcementDigest(identity.enforcementToken)
        try await record.create(on: request.db)
    }

    @discardableResult
    private func storeEvent(
        eventID: String,
        senderID: UUID,
        conversationID: UUID,
        sentAt: Date,
        expiration: Date?,
        request: Request
    ) async throws -> MessageEventRecord {
        let record = MessageEventRecord(); record.id = UUID(); record.conversationID = conversationID
        record.encryptedEventID = eventID; record.sealedSenderID = try request.ownershipCipher.seal(accountID: senderID)
        record.sentAt = sentAt; record.expiresAt = expiration
        try await record.create(on: request.db)
        return record
    }

    private func expiration(seconds: Int?, from date: Date) throws -> Date? {
        guard let seconds else { return nil }
        let allowed = [300, 3_600, 86_400, 604_800]
        guard allowed.contains(seconds) else { throw APIError.invalidInput("Unsupported disappearing timer") }
        return date.addingTimeInterval(TimeInterval(seconds))
    }

    private func requireNoBlock(between first: UUID, and second: UUID, request: Request) async throws {
        let firstDigest = request.ownershipCipher.enforcementDigest("account:\(first.uuidString)")
        let secondDigest = request.ownershipCipher.enforcementDigest("account:\(second.uuidString)")
        let blocked = try await BlockRecord.query(on: request.db).all().contains {
            ($0.accountID == first && $0.enforcementDigest == secondDigest)
                || ($0.accountID == second && $0.enforcementDigest == firstDigest)
        }
        guard !blocked else { throw APIError.forbidden("Conversation cannot be created") }
    }
}
