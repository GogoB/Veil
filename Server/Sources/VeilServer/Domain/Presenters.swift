import Fluent
import Foundation
import Vapor
import VeilShared

struct PublicPresenter: Sendable {
    func profile(_ record: ProfileRecord, viewer: AuthenticatedAccount?, database: any Database) async throws -> Profile {
        guard let id = record.id else { throw Abort(.internalServerError) }
        let followed = if let viewer {
            try await FollowRecord.query(on: database)
                .filter(\.$followerAccountID == viewer.accountID)
                .filter(\.$followedProfileID == id).first() != nil
        } else { false }
        return Profile(
            id: id,
            username: record.username,
            avatarURL: nil,
            bio: record.bio,
            followerCount: record.followerCount,
            followingCount: record.followingCount,
            isFollowedByMe: followed
        )
    }

    func summary(profileID: UUID, database: any Database) async throws -> ProfileSummary {
        guard let record = try await ProfileRecord.find(profileID, on: database), let id = record.id else {
            throw Abort(.internalServerError)
        }
        return ProfileSummary(id: id, username: record.username, avatarURL: nil)
    }

    func topic(id: UUID?, database: any Database) async throws -> Topic? {
        guard let id, let record = try await TopicRecord.find(id, on: database), let topicID = record.id else { return nil }
        return Topic(id: topicID, slug: record.slug, title: record.title)
    }

    func actor(
        kind: String,
        profileID: UUID?,
        alias: String?,
        sigil: String?,
        role: String,
        enforcementToken: String,
        database: any Database
    ) async throws -> ActorPresentation {
        let actorKind = ActorKind(rawValue: kind) ?? .generatedAlias
        let actorRole = ActorRole(rawValue: role) ?? .participant
        let profile: ProfileSummary? = if actorKind == .profile, let profileID {
            try await self.summary(profileID: profileID, database: database)
        } else { nil }
        return try ActorPresentation(
            kind: actorKind,
            role: actorRole,
            profile: profile,
            threadAlias: alias,
            sigil: sigil,
            enforcementToken: enforcementToken
        )
    }

    func post(_ record: PostRecord, viewer: AuthenticatedAccount?, request: Request) async throws -> Post? {
        guard record.deletedAt == nil,
              record.publicationState == "published",
              record.expiresAt.map({ $0 > Date() }) ?? true,
              let id = record.id,
              let createdAt = record.createdAt else { return nil }

        if record.referenceKind == PostReferenceKind.repost.rawValue,
           let referencedID = record.referencedPostID,
           !((try await PostRecord.find(referencedID, on: request.db)).map {
               $0.deletedAt == nil
                   && $0.publicationState == "published"
                   && ($0.expiresAt.map { $0 > Date() } ?? true)
           } ?? false) {
            return nil
        }

        let actor = try await self.actor(
            kind: record.actorKind,
            profileID: record.profileID,
            alias: record.threadAlias,
            sigil: record.sigil,
            role: ActorRole.originalPoster.rawValue,
            enforcementToken: record.enforcementToken,
            database: request.db
        )
        let medias = try await record.mediaIDs.asyncCompactMap { mediaID -> Media? in
            guard let media = try await MediaRecord.find(mediaID, on: request.db), let id = media.id else { return nil }
            return Media(
                id: id,
                url: URL(string: "/uploads/\(media.objectName)")!,
                width: media.width,
                height: media.height
            )
        }
        let reference = try await self.reference(for: record, viewer: viewer, request: request)
        let liked = if let viewer {
            try await LikeRecord.query(on: request.db)
                .filter(\.$accountID == viewer.accountID)
                .filter(\.$contentKind == "post")
                .filter(\.$contentID == id).first() != nil
        } else { false }
        let isMine = if let viewer {
            try await OwnershipService().ownerID(kind: "post", contentID: id, cipher: request.ownershipCipher, database: request.db) == viewer.accountID
        } else { false }

        let collaborators: [ProfileSummary]?
        if record.visibility == PostVisibility.attributed.rawValue {
            let accepted = try await CollaboratorRecord.query(on: request.db)
                .filter(\.$postID == id).filter(\.$status == "accepted").all()
            collaborators = try await accepted.asyncMap { try await self.summary(profileID: $0.invitedProfileID, database: request.db) }
        } else {
            collaborators = nil
        }

        return Post(
            id: id,
            actor: actor,
            visibility: PostVisibility(rawValue: record.visibility) ?? .anonymous,
            body: record.body,
            topic: try await self.topic(id: record.topicID, database: request.db),
            media: medias,
            reference: reference,
            createdAt: createdAt,
            editedAt: record.editedAt,
            expiresAt: record.expiresAt,
            isSensitive: record.isSensitive,
            likeCount: record.likeCount,
            commentCount: record.commentCount,
            isLikedByMe: liked,
            isMine: isMine,
            acceptedCollaborators: collaborators
        )
    }

    func comment(_ record: CommentRecord, viewer: AuthenticatedAccount?, request: Request) async throws -> Comment {
        guard let id = record.id, let createdAt = record.createdAt else { throw Abort(.internalServerError) }
        let liked = if let viewer {
            try await LikeRecord.query(on: request.db)
                .filter(\.$accountID == viewer.accountID).filter(\.$contentKind == "comment")
                .filter(\.$contentID == id).first() != nil
        } else { false }
        let isMine = if let viewer {
            try await OwnershipService().ownerID(
                kind: "comment",
                contentID: id,
                cipher: request.ownershipCipher,
                database: request.db
            ) == viewer.accountID
        } else { false }
        return Comment(
            id: id,
            postID: record.postID,
            parentID: record.parentID,
            rootID: record.rootID,
            actor: try await self.actor(
                kind: record.actorKind,
                profileID: record.profileID,
                alias: record.threadAlias,
                sigil: record.sigil,
                role: record.actorRole,
                enforcementToken: record.enforcementToken,
                database: request.db
            ),
            body: record.body,
            createdAt: createdAt,
            editedAt: record.editedAt,
            isDeleted: record.isDeleted,
            likeCount: record.likeCount,
            isLikedByMe: liked,
            isMine: isMine
        )
    }

    private func reference(for record: PostRecord, viewer: AuthenticatedAccount?, request: Request) async throws -> PostReference? {
        guard let rawKind = record.referenceKind,
              let kind = PostReferenceKind(rawValue: rawKind),
              let referencedID = record.referencedPostID else { return nil }
        guard let original = try await PostRecord.find(referencedID, on: request.db),
              original.deletedAt == nil,
              original.expiresAt.map({ $0 > Date() }) ?? true,
              let id = original.id,
              let createdAt = original.createdAt else {
            return PostReference(kind: kind, postID: referencedID, original: nil, originalUnavailable: true)
        }
        let actor = try await self.actor(
            kind: original.actorKind,
            profileID: original.profileID,
            alias: original.threadAlias,
            sigil: original.sigil,
            role: ActorRole.originalPoster.rawValue,
            enforcementToken: original.enforcementToken,
            database: request.db
        )
        return PostReference(
            kind: kind,
            postID: referencedID,
            original: ReferencedPost(
                id: id,
                actor: actor,
                visibility: PostVisibility(rawValue: original.visibility) ?? .anonymous,
                body: original.body,
                createdAt: createdAt
            ),
            originalUnavailable: false
        )
    }
}

private extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values: [T] = []
        values.reserveCapacity(self.count)
        for element in self { values.append(try await transform(element)) }
        return values
    }

    func asyncCompactMap<T>(_ transform: (Element) async throws -> T?) async rethrows -> [T] {
        var values: [T] = []
        for element in self {
            if let value = try await transform(element) { values.append(value) }
        }
        return values
    }
}
