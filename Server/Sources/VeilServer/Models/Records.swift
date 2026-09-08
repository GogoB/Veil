import Fluent
import Foundation

final class AccountRecord: Model, @unchecked Sendable {
    static let schema = "restricted_accounts"

    @ID(key: .id) var id: UUID?
    @Field(key: "profile_id") var profileID: UUID
    @Field(key: "normalized_username") var normalizedUsername: String
    @Field(key: "account_mode") var accountMode: String
    @OptionalField(key: "passphrase_hash") var passphraseHash: String?
    @OptionalField(key: "recovery_hash") var recoveryHash: String?
    @Field(key: "anonymous_request_policy") var anonymousRequestPolicy: String
    @Field(key: "privilege_level") var privilegeLevel: Int
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    init() {}

    init(
        id: UUID = UUID(),
        profileID: UUID,
        normalizedUsername: String,
        accountMode: String,
        passphraseHash: String?,
        recoveryHash: String?
    ) {
        self.id = id
        self.profileID = profileID
        self.normalizedUsername = normalizedUsername
        self.accountMode = accountMode
        self.passphraseHash = passphraseHash
        self.recoveryHash = recoveryHash
        self.anonymousRequestPolicy = "filtered"
        self.privilegeLevel = 0
    }
}

final class ProfileRecord: Model, @unchecked Sendable {
    static let schema = "public_profiles"

    @ID(key: .id) var id: UUID?
    @Field(key: "username") var username: String
    @OptionalField(key: "avatar_media_id") var avatarMediaID: UUID?
    @OptionalField(key: "bio") var bio: String?
    @Field(key: "follower_count") var followerCount: Int
    @Field(key: "following_count") var followingCount: Int
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    init() {}

    init(id: UUID = UUID(), username: String) {
        self.id = id
        self.username = username
        self.avatarMediaID = nil
        self.bio = nil
        self.followerCount = 0
        self.followingCount = 0
    }
}

final class DeviceRecord: Model, @unchecked Sendable {
    static let schema = "restricted_devices"

    @ID(key: .id) var id: UUID?
    @Field(key: "account_id") var accountID: UUID
    @Field(key: "public_key") var publicKey: String
    @OptionalField(key: "revoked_at") var revokedAt: Date?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    init() {}

    init(id: UUID = UUID(), accountID: UUID, publicKey: String) {
        self.id = id
        self.accountID = accountID
        self.publicKey = publicKey
    }
}

final class SessionRecord: Model, @unchecked Sendable {
    static let schema = "restricted_sessions"

    @ID(key: .id) var id: UUID?
    @Field(key: "account_id") var accountID: UUID
    @Field(key: "device_id") var deviceID: UUID
    @Field(key: "token_digest") var tokenDigest: String
    @Field(key: "expires_at") var expiresAt: Date
    @OptionalField(key: "revoked_at") var revokedAt: Date?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    init() {}

    init(id: UUID = UUID(), accountID: UUID, deviceID: UUID, tokenDigest: String, expiresAt: Date) {
        self.id = id
        self.accountID = accountID
        self.deviceID = deviceID
        self.tokenDigest = tokenDigest
        self.expiresAt = expiresAt
    }
}

final class MatrixAccountRecord: Model, @unchecked Sendable {
    static let schema = "restricted_matrix_accounts"

    @ID(key: .id) var id: UUID?
    @Field(key: "account_id") var accountID: UUID
    @Field(key: "sealed_user_id") var sealedUserID: Data
    @Field(key: "sealed_password") var sealedPassword: Data
    @Field(key: "sealed_access_token") var sealedAccessToken: Data
    @Field(key: "sealed_device_id") var sealedDeviceID: Data
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?

    init() {}
}

final class TopicRecord: Model, @unchecked Sendable {
    static let schema = "public_topics"

    @ID(key: .id) var id: UUID?
    @Field(key: "slug") var slug: String
    @Field(key: "title") var title: String

    init() {}
    init(id: UUID = UUID(), slug: String, title: String) {
        self.id = id
        self.slug = slug
        self.title = title
    }
}

final class MediaRecord: Model, @unchecked Sendable {
    static let schema = "public_media"

    @ID(key: .id) var id: UUID?
    @Field(key: "object_name") var objectName: String
    @Field(key: "mime_type") var mimeType: String
    @Field(key: "width") var width: Int
    @Field(key: "height") var height: Int
    @Field(key: "byte_count") var byteCount: Int
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    init() {}
    init(id: UUID = UUID(), objectName: String, mimeType: String, width: Int, height: Int, byteCount: Int) {
        self.id = id
        self.objectName = objectName
        self.mimeType = mimeType
        self.width = width
        self.height = height
        self.byteCount = byteCount
    }
}

final class PostRecord: Model, @unchecked Sendable {
    static let schema = "public_posts"

    @ID(key: .id) var id: UUID?
    @Field(key: "visibility") var visibility: String
    @Field(key: "actor_kind") var actorKind: String
    @OptionalField(key: "profile_id") var profileID: UUID?
    @OptionalField(key: "thread_alias") var threadAlias: String?
    @OptionalField(key: "sigil") var sigil: String?
    @Field(key: "enforcement_token") var enforcementToken: String
    @Field(key: "publication_state") var publicationState: String
    @Field(key: "body") var body: String
    @OptionalField(key: "topic_id") var topicID: UUID?
    @Field(key: "media_ids") var mediaIDs: [UUID]
    @OptionalField(key: "reference_kind") var referenceKind: String?
    @OptionalField(key: "referenced_post_id") var referencedPostID: UUID?
    @Field(key: "is_sensitive") var isSensitive: Bool
    @Field(key: "like_count") var likeCount: Int
    @Field(key: "comment_count") var commentCount: Int
    @OptionalField(key: "edited_at") var editedAt: Date?
    @OptionalField(key: "expires_at") var expiresAt: Date?
    @OptionalField(key: "deleted_at") var deletedAt: Date?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    init() {}
}

final class CommentRecord: Model, @unchecked Sendable {
    static let schema = "public_comments"

    @ID(key: .id) var id: UUID?
    @Field(key: "post_id") var postID: UUID
    @OptionalField(key: "parent_id") var parentID: UUID?
    @OptionalField(key: "root_id") var rootID: UUID?
    @Field(key: "actor_kind") var actorKind: String
    @OptionalField(key: "profile_id") var profileID: UUID?
    @OptionalField(key: "thread_alias") var threadAlias: String?
    @OptionalField(key: "sigil") var sigil: String?
    @Field(key: "actor_role") var actorRole: String
    @Field(key: "enforcement_token") var enforcementToken: String
    @OptionalField(key: "body") var body: String?
    @Field(key: "like_count") var likeCount: Int
    @OptionalField(key: "edited_at") var editedAt: Date?
    @Field(key: "is_deleted") var isDeleted: Bool
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    init() {}
}

final class OwnershipRecord: Model, @unchecked Sendable {
    static let schema = "restricted_ownership"

    @ID(key: .id) var id: UUID?
    @Field(key: "content_kind") var contentKind: String
    @Field(key: "content_id") var contentID: UUID
    @Field(key: "sealed_account_id") var sealedAccountID: Data
    @Field(key: "enforcement_digest") var enforcementDigest: String

    init() {}
    init(contentKind: String, contentID: UUID, sealedAccountID: Data, enforcementDigest: String) {
        self.id = UUID()
        self.contentKind = contentKind
        self.contentID = contentID
        self.sealedAccountID = sealedAccountID
        self.enforcementDigest = enforcementDigest
    }
}

final class ThreadIdentityRecord: Model, @unchecked Sendable {
    static let schema = "restricted_thread_identities"

    @ID(key: .id) var id: UUID?
    @Field(key: "post_id") var postID: UUID
    @Field(key: "sealed_account_id") var sealedAccountID: Data
    @OptionalField(key: "thread_alias") var threadAlias: String?
    @Field(key: "sigil") var sigil: String
    @Field(key: "actor_role") var actorRole: String

    init() {}
}

final class FollowRecord: Model, @unchecked Sendable {
    static let schema = "restricted_follows"

    @ID(key: .id) var id: UUID?
    @Field(key: "follower_account_id") var followerAccountID: UUID
    @Field(key: "followed_profile_id") var followedProfileID: UUID
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    init() {}
}

final class BlockRecord: Model, @unchecked Sendable {
    static let schema = "restricted_blocks"
    @ID(key: .id) var id: UUID?
    @Field(key: "account_id") var accountID: UUID
    @Field(key: "enforcement_digest") var enforcementDigest: String
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    init() {}
}

final class MuteRecord: Model, @unchecked Sendable {
    static let schema = "restricted_mutes"
    @ID(key: .id) var id: UUID?
    @Field(key: "account_id") var accountID: UUID
    @Field(key: "kind") var kind: String
    @Field(key: "value") var value: String
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    init() {}
}

final class LikeRecord: Model, @unchecked Sendable {
    static let schema = "restricted_likes"
    @ID(key: .id) var id: UUID?
    @Field(key: "account_id") var accountID: UUID
    @Field(key: "content_kind") var contentKind: String
    @Field(key: "content_id") var contentID: UUID
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    init() {}
}

final class CollaboratorRecord: Model, @unchecked Sendable {
    static let schema = "restricted_collaborators"
    @ID(key: .id) var id: UUID?
    @Field(key: "post_id") var postID: UUID
    @Field(key: "creator_account_id") var creatorAccountID: UUID
    @Field(key: "invited_profile_id") var invitedProfileID: UUID
    @Field(key: "status") var status: String
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    init() {}
}

final class CommentIdentityLockRecord: Model, @unchecked Sendable {
    static let schema = "restricted_comment_identity_locks"
    @ID(key: .id) var id: UUID?
    @Field(key: "post_id") var postID: UUID
    @Field(key: "account_id") var accountID: UUID
    @Field(key: "actor_kind") var actorKind: String
    @OptionalField(key: "thread_alias") var threadAlias: String?
    @OptionalField(key: "sigil") var sigil: String?
    init() {}
}

final class ConversationRecord: Model, @unchecked Sendable {
    static let schema = "restricted_conversations"
    @ID(key: .id) var id: UUID?
    @Field(key: "identity") var identity: String
    @Field(key: "creator_account_id") var creatorAccountID: UUID
    @Field(key: "recipient_account_id") var recipientAccountID: UUID
    @OptionalField(key: "source_post_id") var sourcePostID: UUID?
    @Field(key: "matrix_room_ciphertext") var matrixRoomCiphertext: Data
    @Field(key: "is_request") var isRequest: Bool
    @Field(key: "is_accepted") var isAccepted: Bool
    @OptionalField(key: "disappearing_seconds") var disappearingSeconds: Int?
    @Field(key: "read_receipts_enabled") var readReceiptsEnabled: Bool
    @Field(key: "typing_indicators_enabled") var typingIndicatorsEnabled: Bool
    @OptionalField(key: "blocked_at") var blockedAt: Date?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @OptionalField(key: "last_event_at") var lastEventAt: Date?
    init() {}
}

final class ConversationIdentityRecord: Model, @unchecked Sendable {
    static let schema = "restricted_conversation_identities"
    @ID(key: .id) var id: UUID?
    @Field(key: "conversation_id") var conversationID: UUID
    @Field(key: "sealed_account_id") var sealedAccountID: Data
    @OptionalField(key: "alias") var alias: String?
    @Field(key: "sigil") var sigil: String
    @Field(key: "enforcement_token") var enforcementToken: String
    @Field(key: "enforcement_digest") var enforcementDigest: String
    init() {}
}

final class MessageEventRecord: Model, @unchecked Sendable {
    static let schema = "restricted_message_events"
    @ID(key: .id) var id: UUID?
    @Field(key: "conversation_id") var conversationID: UUID
    @Field(key: "encrypted_event_id") var encryptedEventID: String
    @Field(key: "sealed_sender_id") var sealedSenderID: Data
    @Field(key: "sent_at") var sentAt: Date
    @OptionalField(key: "expires_at") var expiresAt: Date?
    @OptionalField(key: "deleted_at") var deletedAt: Date?
    init() {}
}

final class MessageReportRecord: Model, @unchecked Sendable {
    static let schema = "restricted_message_reports"
    @ID(key: .id) var id: UUID?
    @Field(key: "case_token") var caseToken: String
    @Field(key: "conversation_id") var conversationID: UUID
    @Field(key: "selected_evidence") var selectedEvidence: [ReportedEvidencePayload]
    @Field(key: "category") var category: String
    @OptionalField(key: "explanation") var explanation: String?
    @Field(key: "sealed_reporter_id") var sealedReporterID: Data
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    init() {}
}

struct ReportedEvidencePayload: Codable, Hashable, Sendable {
    let encryptedEventID: String
    let senderJSON: String
    let body: String
    let sentAt: Date
}

final class ReportRecord: Model, @unchecked Sendable {
    static let schema = "restricted_reports"
    @ID(key: .id) var id: UUID?
    @Field(key: "case_token") var caseToken: String
    @Field(key: "enforcement_token") var enforcementToken: String
    @Field(key: "content_id") var contentID: UUID
    @Field(key: "category") var category: String
    @OptionalField(key: "explanation") var explanation: String?
    @Field(key: "sealed_reporter_id") var sealedReporterID: Data
    @Field(key: "status") var status: String
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    init() {}
}

final class QuarantineRecord: Model, @unchecked Sendable {
    static let schema = "restricted_quarantine"
    @ID(key: .id) var id: UUID?
    @Field(key: "content_id") var contentID: UUID
    @Field(key: "content_kind") var contentKind: String
    @Field(key: "payload") var payload: DataPayload
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    init() {}
}

struct DataPayload: Codable, Hashable, Sendable {
    let body: String?
    let mediaIDs: [UUID]
}

final class RateLimitRecord: Model, @unchecked Sendable {
    static let schema = "restricted_rate_limits"
    @ID(key: .id) var id: UUID?
    @Field(key: "bucket") var bucket: String
    @Field(key: "subject_digest") var subjectDigest: String
    @Field(key: "window_started_at") var windowStartedAt: Date
    @Field(key: "count") var count: Int
    init() {}
}
