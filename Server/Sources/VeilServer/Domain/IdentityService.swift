import Fluent
import Foundation
import VeilShared

struct PublicIdentityFields: Sendable {
    let kind: ActorKind
    let profileID: UUID?
    let alias: String?
    let sigil: String?
    let role: ActorRole
    let enforcementToken: String
}

struct IdentityService: Sendable {
    private let generatedAliases = [
        "quiet signal", "paper moon", "low orbit", "silver echo",
        "soft static", "distant light", "hollow star", "night window"
    ]

    func postIdentity(
        account: AuthenticatedAccount,
        postID: UUID,
        visibility: PostVisibility,
        mode: AnonymousPresentationMode?,
        customAlias: String?,
        cipher: OwnershipCipher
    ) throws -> PublicIdentityFields {
        let enforcementToken = SecureValue.token()
        if visibility == .attributed {
            return PublicIdentityFields(
                kind: .profile,
                profileID: account.profileID,
                alias: nil,
                sigil: nil,
                role: .originalPoster,
                enforcementToken: enforcementToken
            )
        }

        let chosenMode = mode ?? .generatedAlias
        let digest = cipher.enforcementDigest("thread:\(postID.uuidString):\(account.accountID.uuidString)")
        let alias: String?
        switch chosenMode {
        case .generatedAlias:
            alias = self.generatedAliases[self.index(from: digest, upperBound: self.generatedAliases.count)]
        case .customAlias:
            alias = try VeilValidation.validatedThreadAlias(customAlias ?? "")
        case .sigil:
            alias = nil
        }
        return PublicIdentityFields(
            kind: ActorKind(rawValue: chosenMode.rawValue) ?? .generatedAlias,
            profileID: nil,
            alias: alias,
            sigil: "v-\(digest.prefix(16))",
            role: .originalPoster,
            enforcementToken: enforcementToken
        )
    }

    func commentIdentity(
        account: AuthenticatedAccount,
        postID: UUID,
        visibility: PostVisibility,
        mode: AnonymousPresentationMode?,
        customAlias: String?,
        isHiddenOwner: Bool,
        cipher: OwnershipCipher,
        database: any Database
    ) async throws -> PublicIdentityFields {
        if let lock = try await CommentIdentityLockRecord.query(on: database)
            .filter(\.$postID == postID)
            .filter(\.$accountID == account.accountID)
            .first() {
            let requestedKind = visibility == .attributed ? ActorKind.profile : ActorKind(rawValue: (mode ?? .generatedAlias).rawValue)
            guard requestedKind?.rawValue == lock.actorKind else {
                throw APIError.conflict("Your identity is locked for this thread")
            }
            return PublicIdentityFields(
                kind: ActorKind(rawValue: lock.actorKind) ?? .generatedAlias,
                profileID: lock.actorKind == ActorKind.profile.rawValue ? account.profileID : nil,
                alias: lock.threadAlias,
                sigil: lock.sigil,
                role: isHiddenOwner ? .originalPoster : .participant,
                enforcementToken: SecureValue.token()
            )
        }

        let fields = try self.postIdentity(
            account: account,
            postID: postID,
            visibility: visibility,
            mode: mode,
            customAlias: customAlias,
            cipher: cipher
        )
        let lock = CommentIdentityLockRecord()
        lock.id = UUID()
        lock.postID = postID
        lock.accountID = account.accountID
        lock.actorKind = fields.kind.rawValue
        lock.threadAlias = fields.alias
        lock.sigil = fields.sigil
        try await lock.create(on: database)
        return PublicIdentityFields(
            kind: fields.kind,
            profileID: fields.profileID,
            alias: fields.alias,
            sigil: fields.sigil,
            role: isHiddenOwner ? .originalPoster : .participant,
            enforcementToken: fields.enforcementToken
        )
    }

    func conversationIdentity(
        accountID: UUID,
        conversationID: UUID,
        cipher: OwnershipCipher
    ) -> (alias: String, sigil: String, enforcementToken: String) {
        let digest = cipher.enforcementDigest("conversation:\(conversationID.uuidString):\(accountID.uuidString)")
        return (
            self.generatedAliases[self.index(from: digest, upperBound: self.generatedAliases.count)],
            "c-\(digest.prefix(16))",
            SecureValue.token()
        )
    }

    private func index(from digest: String, upperBound: Int) -> Int {
        let prefix = digest.prefix(8)
        return Int(prefix, radix: 16).map { $0 % upperBound } ?? 0
    }
}
