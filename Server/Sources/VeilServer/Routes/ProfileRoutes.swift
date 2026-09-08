import Fluent
import Vapor
import VeilShared

struct ProfileRoutes: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let optionallyAuthenticated = routes.grouped(SessionAuthenticator())
        optionallyAuthenticated.get("profiles", ":profileID", use: self.lookup)

        let authenticated = optionallyAuthenticated.grouped(AuthenticatedAccount.guardMiddleware())
        authenticated.patch("profiles", "me", use: self.update)
        authenticated.post("profiles", ":profileID", "follow", use: self.follow)
        authenticated.delete("profiles", ":profileID", "follow", use: self.unfollow)
        authenticated.post("profiles", ":profileID", "block", use: self.blockProfile)
        authenticated.post("profiles", ":profileID", "mute", use: self.muteProfile)
        authenticated.post("enforcement", ":token", "block", use: self.blockOpaqueIdentity)
        authenticated.get("preferences", use: self.preferences)
        authenticated.put("preferences", use: self.updatePreferences)
    }

    private func lookup(_ request: Request) async throws -> Profile {
        let profileID = try request.parameters.require("profileID", as: UUID.self)
        guard let record = try await ProfileRecord.find(profileID, on: request.db) else {
            throw APIError.notFound("Profile not found")
        }
        return try await PublicPresenter().profile(record, viewer: request.auth.get(AuthenticatedAccount.self), database: request.db)
    }

    private func update(_ request: Request) async throws -> Profile {
        let identity = try request.authenticatedAccount
        let payload = try request.content.decode(ProfileUpdateRequest.self)
        guard let record = try await ProfileRecord.find(identity.profileID, on: request.db) else { throw Abort(.notFound) }
        if let bio = payload.bio {
            guard bio.count <= 300 else { throw APIError.invalidInput("Bio must be 300 characters or fewer") }
            record.bio = bio.nilIfBlank
        }
        if let mediaID = payload.avatarMediaID {
            guard try await MediaRecord.find(mediaID, on: request.db) != nil,
                  try await OwnershipService().ownerID(kind: "media", contentID: mediaID, cipher: request.ownershipCipher, database: request.db) == identity.accountID else {
                throw APIError.invalidInput("Avatar media is unavailable")
            }
            record.avatarMediaID = mediaID
        }
        try await record.update(on: request.db)
        return try await PublicPresenter().profile(record, viewer: identity, database: request.db)
    }

    private func follow(_ request: Request) async throws -> EmptyResponse {
        let identity = try request.authenticatedAccount
        let target = try request.parameters.require("profileID", as: UUID.self)
        guard target != identity.profileID, let targetProfile = try await ProfileRecord.find(target, on: request.db) else {
            throw APIError.invalidInput("That profile cannot be followed")
        }
        if try await FollowRecord.query(on: request.db)
            .filter(\.$followerAccountID == identity.accountID).filter(\.$followedProfileID == target).first() == nil {
            let follow = FollowRecord()
            follow.id = UUID(); follow.followerAccountID = identity.accountID; follow.followedProfileID = target
            try await follow.create(on: request.db)
            targetProfile.followerCount += 1
            try await targetProfile.update(on: request.db)
            if let own = try await ProfileRecord.find(identity.profileID, on: request.db) {
                own.followingCount += 1; try await own.update(on: request.db)
            }
        }
        return .success
    }

    private func unfollow(_ request: Request) async throws -> EmptyResponse {
        let identity = try request.authenticatedAccount
        let target = try request.parameters.require("profileID", as: UUID.self)
        if let follow = try await FollowRecord.query(on: request.db)
            .filter(\.$followerAccountID == identity.accountID).filter(\.$followedProfileID == target).first() {
            try await follow.delete(on: request.db)
            if let profile = try await ProfileRecord.find(target, on: request.db) {
                profile.followerCount = max(0, profile.followerCount - 1); try await profile.update(on: request.db)
            }
            if let own = try await ProfileRecord.find(identity.profileID, on: request.db) {
                own.followingCount = max(0, own.followingCount - 1); try await own.update(on: request.db)
            }
        }
        return .success
    }

    private func blockProfile(_ request: Request) async throws -> EmptyResponse {
        let identity = try request.authenticatedAccount
        let targetProfileID = try request.parameters.require("profileID", as: UUID.self)
        guard targetProfileID != identity.profileID,
              let target = try await AccountRecord.query(on: request.db).filter(\.$profileID == targetProfileID).first(),
              let targetAccountID = target.id else { throw APIError.notFound("Profile not found") }
        try await self.storeBlock(
            accountID: identity.accountID,
            subject: "account:\(targetAccountID.uuidString)",
            request: request
        )
        try await FollowRecord.query(on: request.db)
            .group(.or) { group in
                group.group(.and) { $0.filter(\.$followerAccountID == identity.accountID).filter(\.$followedProfileID == targetProfileID) }
                group.group(.and) { $0.filter(\.$followerAccountID == targetAccountID).filter(\.$followedProfileID == identity.profileID) }
            }.delete()
        return .success
    }

    private func muteProfile(_ request: Request) async throws -> EmptyResponse {
        let identity = try request.authenticatedAccount
        let target = try request.parameters.require("profileID", as: UUID.self)
        guard try await ProfileRecord.find(target, on: request.db) != nil else { throw APIError.notFound("Profile not found") }
        try await self.storeMute(accountID: identity.accountID, kind: "profile", value: target.uuidString, request: request)
        return .success
    }

    private func blockOpaqueIdentity(_ request: Request) async throws -> EmptyResponse {
        let identity = try request.authenticatedAccount
        let token = try request.parameters.require("token")
        guard let hiddenAccountID = try await OwnershipService().enforcementSubject(
            token: token, cipher: request.ownershipCipher, database: request.db
        ) else { throw APIError.notFound("Identity is unavailable") }
        try await self.storeBlock(
            accountID: identity.accountID,
            subject: "account:\(hiddenAccountID.uuidString)",
            request: request
        )
        return .success
    }

    private func preferences(_ request: Request) async throws -> ContentPreferences {
        let identity = try request.authenticatedAccount
        let rows = try await MuteRecord.query(on: request.db).filter(\.$accountID == identity.accountID).all()
        let account = try await AccountRecord.find(identity.accountID, on: request.db)
        return ContentPreferences(
            mutedProfileIDs: Set(rows.filter { $0.kind == "profile" }.compactMap { UUID(uuidString: $0.value) }),
            mutedTopicIDs: Set(rows.filter { $0.kind == "topic" }.compactMap { UUID(uuidString: $0.value) }),
            mutedKeywords: Set(rows.filter { $0.kind == "keyword" }.map(\.value)),
            blurSensitiveMedia: true,
            anonymousRequestPolicy: AnonymousRequestPolicy(rawValue: account?.anonymousRequestPolicy ?? "filtered") ?? .filtered
        )
    }

    private func updatePreferences(_ request: Request) async throws -> ContentPreferences {
        let identity = try request.authenticatedAccount
        let payload = try request.content.decode(ContentPreferences.self)
        try await MuteRecord.query(on: request.db).filter(\.$accountID == identity.accountID).delete()
        for profileID in payload.mutedProfileIDs {
            try await self.storeMute(accountID: identity.accountID, kind: "profile", value: profileID.uuidString, request: request)
        }
        for topicID in payload.mutedTopicIDs {
            try await self.storeMute(accountID: identity.accountID, kind: "topic", value: topicID.uuidString, request: request)
        }
        for keyword in payload.mutedKeywords {
            let normalized = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty, normalized.count <= 64 else { continue }
            try await self.storeMute(accountID: identity.accountID, kind: "keyword", value: normalized, request: request)
        }
        if let account = try await AccountRecord.find(identity.accountID, on: request.db) {
            account.anonymousRequestPolicy = payload.anonymousRequestPolicy.rawValue
            try await account.update(on: request.db)
        }
        return payload
    }

    private func storeMute(accountID: UUID, kind: String, value: String, request: Request) async throws {
        guard try await MuteRecord.query(on: request.db)
            .filter(\.$accountID == accountID).filter(\.$kind == kind).filter(\.$value == value).first() == nil else { return }
        let mute = MuteRecord(); mute.id = UUID(); mute.accountID = accountID; mute.kind = kind; mute.value = value
        try await mute.create(on: request.db)
    }

    private func storeBlock(accountID: UUID, subject: String, request: Request) async throws {
        let digest = request.ownershipCipher.enforcementDigest(subject)
        guard try await BlockRecord.query(on: request.db)
            .filter(\.$accountID == accountID).filter(\.$enforcementDigest == digest).first() == nil else { return }
        let block = BlockRecord(); block.id = UUID(); block.accountID = accountID; block.enforcementDigest = digest
        try await block.create(on: request.db)
    }
}
