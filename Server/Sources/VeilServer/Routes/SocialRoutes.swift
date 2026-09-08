import Fluent
import Foundation
import Vapor
import VeilShared

struct SocialRoutes: RouteCollection {
    private let presenter = PublicPresenter()
    private let identities = IdentityService()
    private let ownership = OwnershipService()

    func boot(routes: any RoutesBuilder) throws {
        let optionallyAuthenticated = routes.grouped(SessionAuthenticator())
        optionallyAuthenticated.get("topics", use: self.topics)
        optionallyAuthenticated.get("search", use: self.search)
        optionallyAuthenticated.get("feeds", ":kind", use: self.feed)
        optionallyAuthenticated.get("posts", ":postID", use: self.post)
        optionallyAuthenticated.get("posts", ":postID", "comments", use: self.comments)
        optionallyAuthenticated.get("profiles", ":profileID", "posts", use: self.profilePosts)

        let authenticated = optionallyAuthenticated.grouped(AuthenticatedAccount.guardMiddleware())
        authenticated.post("posts", use: self.createPost)
        authenticated.patch("posts", ":postID", use: self.editPost)
        authenticated.delete("posts", ":postID", use: self.deletePost)
        authenticated.post("posts", ":postID", "likes", use: self.likePost)
        authenticated.delete("posts", ":postID", "likes", use: self.unlikePost)
        authenticated.post("posts", ":postID", "comments", use: self.createComment)
        authenticated.patch("comments", ":commentID", use: self.editComment)
        authenticated.delete("comments", ":commentID", use: self.deleteComment)
        authenticated.post("comments", ":commentID", "likes", use: self.likeComment)
        authenticated.delete("comments", ":commentID", "likes", use: self.unlikeComment)
        authenticated.get("collaborations", "invitations", use: self.invitations)
        authenticated.post("posts", ":postID", "collaborators", ":profileID", "accept", use: self.acceptInvitation)
        authenticated.delete("posts", ":postID", "collaborators", "me", use: self.leaveCollaboration)
        authenticated.get("veiled-activity", use: self.veiledActivity)
    }

    private func topics(_ request: Request) async throws -> [Topic] {
        try await TopicRecord.query(on: request.db).sort(\.$title).all().map {
            Topic(id: try $0.requireID(), slug: $0.slug, title: $0.title)
        }
    }

    private func feed(_ request: Request) async throws -> VeilShared.Page<Post> {
        guard let kind = FeedKind(rawValue: try request.parameters.require("kind")) else {
            throw APIError.invalidInput("Unknown feed")
        }
        let viewer = request.auth.get(AuthenticatedAccount.self)
        let records = try await PostRecord.query(on: request.db).sort(\.$createdAt, .descending).all()
        let followed: Set<UUID>
        if kind == .following, let viewer {
            followed = Set(try await FollowRecord.query(on: request.db)
                .filter(\.$followerAccountID == viewer.accountID).all().map(\.followedProfileID))
        } else { followed = [] }

        let filters = try await self.filters(for: viewer, request: request)
        var values: [Post] = []
        for record in records {
            if kind == .following {
                guard record.visibility == PostVisibility.attributed.rawValue,
                      let profileID = record.profileID,
                      followed.contains(profileID) else { continue }
            }
            guard try await self.isVisible(record, to: viewer, filters: filters, request: request),
                  let value = try await self.presenter.post(record, viewer: viewer, request: request) else { continue }
            values.append(value)
            if values.count == 50 { break }
        }
        return VeilShared.Page(items: values)
    }

    private func post(_ request: Request) async throws -> Post {
        let id = try request.parameters.require("postID", as: UUID.self)
        let viewer = request.auth.get(AuthenticatedAccount.self)
        let filters = try await self.filters(for: viewer, request: request)
        guard let record = try await PostRecord.find(id, on: request.db),
              try await self.isVisible(record, to: viewer, filters: filters, request: request),
              let value = try await self.presenter.post(record, viewer: viewer, request: request) else {
            throw APIError.notFound("Post not found")
        }
        return value
    }

    private func profilePosts(_ request: Request) async throws -> VeilShared.Page<Post> {
        let profileID = try request.parameters.require("profileID", as: UUID.self)
        let viewer = request.auth.get(AuthenticatedAccount.self)
        let records = try await PostRecord.query(on: request.db)
            .filter(\.$profileID == profileID)
            .filter(\.$visibility == PostVisibility.attributed.rawValue)
            .sort(\.$createdAt, .descending).all()
        let filters = try await self.filters(for: viewer, request: request)
        var values: [Post] = []
        for record in records where try await self.isVisible(record, to: viewer, filters: filters, request: request) {
            if let value = try await self.presenter.post(record, viewer: viewer, request: request) { values.append(value) }
        }
        return VeilShared.Page(items: values)
    }

    private func search(_ request: Request) async throws -> SearchResults {
        let query = (try? request.query.get(String.self, at: "q"))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !query.isEmpty, query.count <= 100 else { return SearchResults(profiles: [], topics: [], posts: []) }
        let needle = query.lowercased()
        let viewer = request.auth.get(AuthenticatedAccount.self)
        let profileRecords = try await ProfileRecord.query(on: request.db).all().filter {
            $0.username.lowercased().contains(needle) || ($0.bio?.lowercased().contains(needle) ?? false)
        }
        var profiles: [Profile] = []
        for record in profileRecords.prefix(20) {
            profiles.append(try await self.presenter.profile(record, viewer: viewer, database: request.db))
        }
        let topics = try await TopicRecord.query(on: request.db).all().filter {
            $0.title.lowercased().contains(needle) || $0.slug.lowercased().contains(needle)
        }.prefix(20).map { Topic(id: try $0.requireID(), slug: $0.slug, title: $0.title) }

        // Only public body/topic/profile fields are searched. Thread aliases and
        // sigils are intentionally never added to this predicate.
        let topicMatches = Set(topics.map(\.id))
        let records = try await PostRecord.query(on: request.db).sort(\.$createdAt, .descending).all().filter {
            $0.body.lowercased().contains(needle) || ($0.topicID.map(topicMatches.contains) ?? false)
        }
        let filters = try await self.filters(for: viewer, request: request)
        var posts: [Post] = []
        for record in records where try await self.isVisible(record, to: viewer, filters: filters, request: request) {
            if let value = try await self.presenter.post(record, viewer: viewer, request: request) { posts.append(value) }
            if posts.count == 30 { break }
        }
        return SearchResults(profiles: profiles, topics: Array(topics), posts: posts)
    }

    private func createPost(_ request: Request) async throws -> PostCreationEnvelope {
        let account = try request.authenticatedAccount
        try await request.application.rateLimiter.check(policy: .post, subject: account.accountID.uuidString, request: request)
        let payload = try request.content.decode(PostCreateRequest.self)
        if payload.referenceKind == .repost {
            guard payload.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  payload.mediaIDs.isEmpty else {
                throw APIError.invalidInput("A plain repost cannot add text or images")
            }
        } else {
            do { try VeilValidation.validatePost(body: payload.body, mediaCount: payload.mediaIDs.count) }
            catch { throw APIError.invalidInput("Post text or image limits were exceeded") }
        }
        if let topicID = payload.topicID, try await TopicRecord.find(topicID, on: request.db) == nil {
            throw APIError.invalidInput("Topic not found")
        }
        for mediaID in payload.mediaIDs {
            guard try await MediaRecord.find(mediaID, on: request.db) != nil,
                  try await self.ownership.ownerID(kind: "media", contentID: mediaID, cipher: request.ownershipCipher, database: request.db) == account.accountID else {
                throw APIError.invalidInput("Media is unavailable")
            }
        }
        guard payload.collaboratorProfileIDs.count <= 5,
              Set(payload.collaboratorProfileIDs).count == payload.collaboratorProfileIDs.count,
              !payload.collaboratorProfileIDs.contains(account.profileID) else {
            throw APIError.invalidInput("Choose up to five distinct collaborators")
        }
        for profileID in payload.collaboratorProfileIDs where try await ProfileRecord.find(profileID, on: request.db) == nil {
            throw APIError.invalidInput("A collaborator profile is unavailable")
        }
        if (payload.referenceKind == nil) != (payload.referencedPostID == nil) {
            throw APIError.invalidInput("A repost or quote requires both reference fields")
        }
        if let referenceID = payload.referencedPostID {
            guard let referencedPost = try await PostRecord.find(referenceID, on: request.db),
                  referencedPost.deletedAt == nil else {
                throw APIError.notFound("Original post is unavailable")
            }
        }

        let id = UUID()
        let actor = try self.identities.postIdentity(
            account: account,
            postID: id,
            visibility: payload.visibility,
            mode: payload.anonymousMode,
            customAlias: payload.customAlias,
            cipher: request.ownershipCipher
        )
        let record = PostRecord()
        record.id = id
        record.visibility = payload.visibility.rawValue
        record.actorKind = actor.kind.rawValue
        record.profileID = actor.profileID
        record.threadAlias = actor.alias
        record.sigil = actor.sigil
        record.enforcementToken = actor.enforcementToken
        record.publicationState = payload.collaboratorProfileIDs.isEmpty ? "published" : "pending"
        record.body = payload.body.trimmingCharacters(in: .whitespacesAndNewlines)
        record.topicID = payload.topicID
        record.mediaIDs = payload.mediaIDs
        record.referenceKind = payload.referenceKind?.rawValue
        record.referencedPostID = payload.referencedPostID
        record.isSensitive = payload.isSensitive
        record.likeCount = 0
        record.commentCount = 0
        record.expiresAt = VeilValidation.expirationDate(for: payload.expiration)
        try await record.create(on: request.db)
        try await self.ownership.record(
            kind: "post", contentID: id, accountID: account.accountID,
            enforcementToken: actor.enforcementToken, cipher: request.ownershipCipher, database: request.db
        )
        if payload.visibility == .anonymous {
            let thread = ThreadIdentityRecord()
            thread.id = UUID(); thread.postID = id
            thread.sealedAccountID = try request.ownershipCipher.seal(accountID: account.accountID)
            thread.threadAlias = actor.alias; thread.sigil = actor.sigil ?? SecureValue.token(byteCount: 8)
            thread.actorRole = ActorRole.originalPoster.rawValue
            try await thread.create(on: request.db)
        }
        for profileID in payload.collaboratorProfileIDs {
            let collaboration = CollaboratorRecord()
            collaboration.id = UUID(); collaboration.postID = id
            collaboration.creatorAccountID = account.accountID
            collaboration.invitedProfileID = profileID; collaboration.status = "pending"
            try await collaboration.create(on: request.db)
        }
        let presented = try await self.presenter.post(record, viewer: account, request: request)
        return PostCreationEnvelope(
            post: presented,
            postID: id,
            publicationState: record.publicationState,
            pendingCollaboratorCount: payload.collaboratorProfileIDs.count
        )
    }

    private func editPost(_ request: Request) async throws -> Post {
        let account = try request.authenticatedAccount
        let id = try request.parameters.require("postID", as: UUID.self)
        let payload = try request.content.decode(PostEditRequest.self)
        try await self.ownership.requireCreator(kind: "post", contentID: id, accountID: account.accountID, cipher: request.ownershipCipher, database: request.db)
        guard let record = try await PostRecord.find(id, on: request.db), record.deletedAt == nil else {
            throw APIError.notFound("Post not found")
        }
        do { try VeilValidation.validatePost(body: payload.body, mediaCount: record.mediaIDs.count) }
        catch { throw APIError.invalidInput("Post text limit was exceeded") }
        record.body = payload.body.trimmingCharacters(in: .whitespacesAndNewlines)
        record.topicID = payload.topicID
        record.isSensitive = payload.isSensitive
        record.editedAt = Date()
        try await record.update(on: request.db)
        guard let value = try await self.presenter.post(record, viewer: account, request: request) else {
            throw APIError.conflict("Post is waiting for collaborator acceptance")
        }
        return value
    }

    private func deletePost(_ request: Request) async throws -> EmptyResponse {
        let account = try request.authenticatedAccount
        let id = try request.parameters.require("postID", as: UUID.self)
        try await self.ownership.requireCreator(kind: "post", contentID: id, accountID: account.accountID, cipher: request.ownershipCipher, database: request.db)
        guard let record = try await PostRecord.find(id, on: request.db), record.deletedAt == nil else { return .success }
        if try await ReportRecord.query(on: request.db).filter(\.$contentID == id).first() != nil {
            let quarantine = QuarantineRecord()
            quarantine.id = UUID(); quarantine.contentID = id; quarantine.contentKind = "post"
            quarantine.payload = DataPayload(body: record.body, mediaIDs: record.mediaIDs)
            try await quarantine.create(on: request.db)
        }
        record.body = ""; record.mediaIDs = []; record.deletedAt = Date()
        try await record.update(on: request.db)
        return .success
    }

    private func likePost(_ request: Request) async throws -> EmptyResponse {
        try await self.setLike(kind: "post", id: request.parameters.require("postID", as: UUID.self), liked: true, request: request)
    }

    private func unlikePost(_ request: Request) async throws -> EmptyResponse {
        try await self.setLike(kind: "post", id: request.parameters.require("postID", as: UUID.self), liked: false, request: request)
    }

    private func comments(_ request: Request) async throws -> VeilShared.Page<Comment> {
        let postID = try request.parameters.require("postID", as: UUID.self)
        guard try await PostRecord.find(postID, on: request.db) != nil else { throw APIError.notFound("Post not found") }
        let viewer = request.auth.get(AuthenticatedAccount.self)
        let records = try await CommentRecord.query(on: request.db).filter(\.$postID == postID).sort(\.$createdAt).all()
        var values: [Comment] = []
        for record in records { values.append(try await self.presenter.comment(record, viewer: viewer, request: request)) }
        return VeilShared.Page(items: values)
    }

    private func createComment(_ request: Request) async throws -> Comment {
        let account = try request.authenticatedAccount
        let postID = try request.parameters.require("postID", as: UUID.self)
        let payload = try request.content.decode(CommentCreateRequest.self)
        let body = payload.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, body.count <= VeilValidation.maximumPostCharacters,
              let post = try await PostRecord.find(postID, on: request.db), post.deletedAt == nil else {
            throw APIError.invalidInput("Comment is empty, too long, or the post is unavailable")
        }
        let creatorID = try await self.ownership.ownerID(kind: "post", contentID: postID, cipher: request.ownershipCipher, database: request.db)
        let collaborator = try await CollaboratorRecord.query(on: request.db)
            .filter(\.$postID == postID).filter(\.$invitedProfileID == account.profileID).filter(\.$status == "accepted").first() != nil
        let isHiddenOwner = post.visibility == PostVisibility.anonymous.rawValue && (creatorID == account.accountID || collaborator)
        let actor = try await self.identities.commentIdentity(
            account: account, postID: postID, visibility: payload.visibility,
            mode: payload.anonymousMode, customAlias: payload.customAlias,
            isHiddenOwner: isHiddenOwner, cipher: request.ownershipCipher, database: request.db
        )

        var parentID = payload.parentID
        var rootID: UUID?
        if let requestedParent = payload.parentID {
            guard let parent = try await CommentRecord.find(requestedParent, on: request.db), parent.postID == postID else {
                throw APIError.invalidInput("Parent comment not found")
            }
            rootID = parent.rootID ?? parent.id
            if parent.rootID != nil { parentID = rootID }
        }
        let record = CommentRecord()
        record.id = UUID(); record.postID = postID; record.parentID = parentID; record.rootID = rootID
        record.actorKind = actor.kind.rawValue; record.profileID = actor.profileID
        record.threadAlias = actor.alias; record.sigil = actor.sigil; record.actorRole = actor.role.rawValue
        record.enforcementToken = actor.enforcementToken; record.body = body; record.likeCount = 0; record.isDeleted = false
        try await record.create(on: request.db)
        guard let id = record.id else { throw Abort(.internalServerError) }
        try await self.ownership.record(
            kind: "comment", contentID: id, accountID: account.accountID,
            enforcementToken: actor.enforcementToken, cipher: request.ownershipCipher, database: request.db
        )
        post.commentCount += 1; try await post.update(on: request.db)
        return try await self.presenter.comment(record, viewer: account, request: request)
    }

    private func editComment(_ request: Request) async throws -> Comment {
        let account = try request.authenticatedAccount
        let id = try request.parameters.require("commentID", as: UUID.self)
        let payload = try request.content.decode(CommentEditRequest.self)
        try await self.ownership.requireCreator(kind: "comment", contentID: id, accountID: account.accountID, cipher: request.ownershipCipher, database: request.db)
        let body = payload.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, body.count <= VeilValidation.maximumPostCharacters,
              let record = try await CommentRecord.find(id, on: request.db), !record.isDeleted else {
            throw APIError.invalidInput("Comment is empty, too long, or unavailable")
        }
        record.body = body; record.editedAt = Date(); try await record.update(on: request.db)
        return try await self.presenter.comment(record, viewer: account, request: request)
    }

    private func deleteComment(_ request: Request) async throws -> EmptyResponse {
        let account = try request.authenticatedAccount
        let id = try request.parameters.require("commentID", as: UUID.self)
        try await self.ownership.requireCreator(kind: "comment", contentID: id, accountID: account.accountID, cipher: request.ownershipCipher, database: request.db)
        guard let record = try await CommentRecord.find(id, on: request.db), !record.isDeleted else { return .success }
        let hasReplies = try await CommentRecord.query(on: request.db)
            .group(.or) { $0.filter(\.$parentID == id).filter(\.$rootID == id) }.first() != nil
        if hasReplies {
            record.body = nil; record.isDeleted = true; try await record.update(on: request.db)
        } else {
            try await record.delete(on: request.db)
        }
        if let post = try await PostRecord.find(record.postID, on: request.db) {
            post.commentCount = max(0, post.commentCount - 1); try await post.update(on: request.db)
        }
        return .success
    }

    private func likeComment(_ request: Request) async throws -> EmptyResponse {
        try await self.setLike(kind: "comment", id: request.parameters.require("commentID", as: UUID.self), liked: true, request: request)
    }

    private func unlikeComment(_ request: Request) async throws -> EmptyResponse {
        try await self.setLike(kind: "comment", id: request.parameters.require("commentID", as: UUID.self), liked: false, request: request)
    }

    private func invitations(_ request: Request) async throws -> [CollaborationInvitation] {
        let account = try request.authenticatedAccount
        let rows = try await CollaboratorRecord.query(on: request.db)
            .filter(\.$invitedProfileID == account.profileID).filter(\.$status == "pending").all()
        var result: [CollaborationInvitation] = []
        for row in rows {
            guard let id = row.id,
                  let post = try await PostRecord.find(row.postID, on: request.db),
                  let creator = try await AccountRecord.find(row.creatorAccountID, on: request.db) else { continue }
            result.append(CollaborationInvitation(
                id: id,
                postID: row.postID,
                creator: try await self.presenter.summary(profileID: creator.profileID, database: request.db),
                visibility: PostVisibility(rawValue: post.visibility) ?? .anonymous,
                excerpt: String(post.body.prefix(120))
            ))
        }
        return result
    }

    private func acceptInvitation(_ request: Request) async throws -> EmptyResponse {
        let account = try request.authenticatedAccount
        let postID = try request.parameters.require("postID", as: UUID.self)
        let profileID = try request.parameters.require("profileID", as: UUID.self)
        guard profileID == account.profileID,
              let invitation = try await CollaboratorRecord.query(on: request.db)
                .filter(\.$postID == postID).filter(\.$invitedProfileID == profileID).filter(\.$status == "pending").first(),
              let post = try await PostRecord.find(postID, on: request.db) else {
            throw APIError.notFound("Invitation not found")
        }
        invitation.status = "accepted"; try await invitation.update(on: request.db)
        if post.visibility == PostVisibility.anonymous.rawValue {
            let digest = request.ownershipCipher.enforcementDigest("thread:\(postID.uuidString):\(account.accountID.uuidString)")
            let thread = ThreadIdentityRecord(); thread.id = UUID(); thread.postID = postID
            thread.sealedAccountID = try request.ownershipCipher.seal(accountID: account.accountID)
            thread.threadAlias = nil; thread.sigil = "v-\(digest.prefix(16))"; thread.actorRole = ActorRole.originalPoster.rawValue
            try await thread.create(on: request.db)
        }
        let pending = try await CollaboratorRecord.query(on: request.db)
            .filter(\.$postID == postID).filter(\.$status == "pending").count()
        if pending == 0 { post.publicationState = "published"; try await post.update(on: request.db) }
        return .success
    }

    private func leaveCollaboration(_ request: Request) async throws -> EmptyResponse {
        let account = try request.authenticatedAccount
        let postID = try request.parameters.require("postID", as: UUID.self)
        guard let collaboration = try await CollaboratorRecord.query(on: request.db)
            .filter(\.$postID == postID).filter(\.$invitedProfileID == account.profileID).first() else { return .success }
        collaboration.status = "left"; try await collaboration.update(on: request.db)
        return .success
    }

    private func veiledActivity(_ request: Request) async throws -> VeiledActivity {
        let account = try request.authenticatedAccount
        let postsRecords = try await PostRecord.query(on: request.db)
            .filter(\.$visibility == PostVisibility.anonymous.rawValue).sort(\.$createdAt, .descending).all()
        var posts: [Post] = []
        for record in postsRecords {
            guard let id = record.id,
                  try await self.ownership.ownerID(kind: "post", contentID: id, cipher: request.ownershipCipher, database: request.db) == account.accountID,
                  let value = try await self.presenter.post(record, viewer: account, request: request) else { continue }
            posts.append(value)
        }
        let commentRecords = try await CommentRecord.query(on: request.db)
            .filter(\.$actorKind != ActorKind.profile.rawValue).sort(\.$createdAt, .descending).all()
        var comments: [Comment] = []
        for record in commentRecords {
            guard let id = record.id,
                  try await self.ownership.ownerID(kind: "comment", contentID: id, cipher: request.ownershipCipher, database: request.db) == account.accountID else { continue }
            comments.append(try await self.presenter.comment(record, viewer: account, request: request))
        }
        return VeiledActivity(posts: posts, comments: comments, conversations: [])
    }

    private func setLike(kind: String, id: UUID, liked: Bool, request: Request) async throws -> EmptyResponse {
        let account = try request.authenticatedAccount
        if kind == "post" { guard try await PostRecord.find(id, on: request.db) != nil else { throw APIError.notFound("Post not found") } }
        else { guard try await CommentRecord.find(id, on: request.db) != nil else { throw APIError.notFound("Comment not found") } }
        let query = LikeRecord.query(on: request.db).filter(\.$accountID == account.accountID)
            .filter(\.$contentKind == kind).filter(\.$contentID == id)
        let existing = try await query.first()
        if liked, existing == nil {
            let record = LikeRecord(); record.id = UUID(); record.accountID = account.accountID
            record.contentKind = kind; record.contentID = id; try await record.create(on: request.db)
            try await self.adjustLikeCount(kind: kind, id: id, delta: 1, request: request)
        } else if !liked, let existing {
            try await existing.delete(on: request.db)
            try await self.adjustLikeCount(kind: kind, id: id, delta: -1, request: request)
        }
        return .success
    }

    private func adjustLikeCount(kind: String, id: UUID, delta: Int, request: Request) async throws {
        if kind == "post", let record = try await PostRecord.find(id, on: request.db) {
            record.likeCount = max(0, record.likeCount + delta); try await record.update(on: request.db)
        } else if let record = try await CommentRecord.find(id, on: request.db) {
            record.likeCount = max(0, record.likeCount + delta); try await record.update(on: request.db)
        }
    }

    private struct Filters {
        let profileIDs: Set<UUID>
        let topicIDs: Set<UUID>
        let keywords: [String]
        let blockDigests: Set<String>
    }

    private func filters(for viewer: AuthenticatedAccount?, request: Request) async throws -> Filters {
        guard let viewer else { return Filters(profileIDs: [], topicIDs: [], keywords: [], blockDigests: []) }
        let mutes = try await MuteRecord.query(on: request.db).filter(\.$accountID == viewer.accountID).all()
        let blocks = try await BlockRecord.query(on: request.db).filter(\.$accountID == viewer.accountID).all()
        return Filters(
            profileIDs: Set(mutes.filter { $0.kind == "profile" }.compactMap { UUID(uuidString: $0.value) }),
            topicIDs: Set(mutes.filter { $0.kind == "topic" }.compactMap { UUID(uuidString: $0.value) }),
            keywords: mutes.filter { $0.kind == "keyword" }.map(\.value),
            blockDigests: Set(blocks.map(\.enforcementDigest))
        )
    }

    private func isVisible(_ record: PostRecord, to viewer: AuthenticatedAccount?, filters: Filters, request: Request) async throws -> Bool {
        guard record.publicationState == "published", record.deletedAt == nil,
              record.expiresAt.map({ $0 > Date() }) ?? true,
              !(record.topicID.map(filters.topicIDs.contains) ?? false) else { return false }
        if let profileID = record.profileID, filters.profileIDs.contains(profileID) { return false }
        if filters.keywords.contains(where: { record.body.lowercased().contains($0) }) { return false }
        if let id = record.id,
           let owner = try await self.ownership.ownerID(kind: "post", contentID: id, cipher: request.ownershipCipher, database: request.db),
           filters.blockDigests.contains(request.ownershipCipher.enforcementDigest("account:\(owner.uuidString)")) { return false }
        return true
    }
}
