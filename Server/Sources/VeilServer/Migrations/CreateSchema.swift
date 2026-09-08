import Fluent

struct CreateSchema: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(AccountRecord.schema)
            .id().field("profile_id", .uuid, .required)
            .field("normalized_username", .string, .required)
            .field("account_mode", .string, .required)
            .field("passphrase_hash", .string)
            .field("recovery_hash", .string)
            .field("anonymous_request_policy", .string, .required)
            .field("privilege_level", .int, .required)
            .field("created_at", .datetime)
            .unique(on: "normalized_username")
            .unique(on: "profile_id")
            .create()

        try await database.schema(ProfileRecord.schema)
            .id().field("username", .string, .required)
            .field("avatar_media_id", .uuid).field("bio", .string)
            .field("follower_count", .int, .required)
            .field("following_count", .int, .required)
            .field("created_at", .datetime)
            .unique(on: "username").create()

        try await database.schema(DeviceRecord.schema)
            .id().field("account_id", .uuid, .required)
            .field("public_key", .string, .required).field("revoked_at", .datetime)
            .field("created_at", .datetime).unique(on: "public_key").create()

        try await database.schema(SessionRecord.schema)
            .id().field("account_id", .uuid, .required).field("device_id", .uuid, .required)
            .field("token_digest", .string, .required).field("expires_at", .datetime, .required)
            .field("revoked_at", .datetime).field("created_at", .datetime)
            .unique(on: "token_digest").create()

        try await database.schema(MatrixAccountRecord.schema)
            .id().field("account_id", .uuid, .required)
            .field("sealed_user_id", .data, .required)
            .field("sealed_password", .data, .required)
            .field("sealed_access_token", .data, .required)
            .field("sealed_device_id", .data, .required)
            .field("created_at", .datetime).field("updated_at", .datetime)
            .unique(on: "account_id").create()

        try await database.schema(TopicRecord.schema)
            .id().field("slug", .string, .required).field("title", .string, .required)
            .unique(on: "slug").create()

        try await database.schema(MediaRecord.schema)
            .id().field("object_name", .string, .required).field("mime_type", .string, .required)
            .field("width", .int, .required).field("height", .int, .required)
            .field("byte_count", .int, .required).field("created_at", .datetime)
            .unique(on: "object_name").create()

        try await database.schema(PostRecord.schema)
            .id().field("visibility", .string, .required).field("actor_kind", .string, .required)
            .field("profile_id", .uuid).field("thread_alias", .string).field("sigil", .string)
            .field("enforcement_token", .string, .required).field("publication_state", .string, .required)
            .field("body", .string, .required)
            .field("topic_id", .uuid).field("media_ids", .array(of: .uuid), .required)
            .field("reference_kind", .string).field("referenced_post_id", .uuid)
            .field("is_sensitive", .bool, .required).field("like_count", .int, .required)
            .field("comment_count", .int, .required).field("edited_at", .datetime)
            .field("expires_at", .datetime).field("deleted_at", .datetime)
            .field("created_at", .datetime).create()

        try await database.schema(CommentRecord.schema)
            .id().field("post_id", .uuid, .required).field("parent_id", .uuid).field("root_id", .uuid)
            .field("actor_kind", .string, .required).field("profile_id", .uuid)
            .field("thread_alias", .string).field("sigil", .string)
            .field("actor_role", .string, .required).field("enforcement_token", .string, .required)
            .field("body", .string).field("like_count", .int, .required)
            .field("edited_at", .datetime).field("is_deleted", .bool, .required)
            .field("created_at", .datetime).create()

        try await database.schema(OwnershipRecord.schema)
            .id().field("content_kind", .string, .required).field("content_id", .uuid, .required)
            .field("sealed_account_id", .data, .required).field("enforcement_digest", .string, .required)
            .unique(on: "content_kind", "content_id").unique(on: "enforcement_digest").create()

        try await database.schema(ThreadIdentityRecord.schema)
            .id().field("post_id", .uuid, .required).field("sealed_account_id", .data, .required)
            .field("thread_alias", .string).field("sigil", .string, .required)
            .field("actor_role", .string, .required).create()

        try await database.schema(FollowRecord.schema)
            .id().field("follower_account_id", .uuid, .required).field("followed_profile_id", .uuid, .required)
            .field("created_at", .datetime).unique(on: "follower_account_id", "followed_profile_id").create()

        try await database.schema(BlockRecord.schema)
            .id().field("account_id", .uuid, .required).field("enforcement_digest", .string, .required)
            .field("created_at", .datetime).unique(on: "account_id", "enforcement_digest").create()

        try await database.schema(MuteRecord.schema)
            .id().field("account_id", .uuid, .required).field("kind", .string, .required)
            .field("value", .string, .required).field("created_at", .datetime)
            .unique(on: "account_id", "kind", "value").create()

        try await database.schema(LikeRecord.schema)
            .id().field("account_id", .uuid, .required).field("content_kind", .string, .required)
            .field("content_id", .uuid, .required).field("created_at", .datetime)
            .unique(on: "account_id", "content_kind", "content_id").create()

        try await database.schema(CollaboratorRecord.schema)
            .id().field("post_id", .uuid, .required).field("creator_account_id", .uuid, .required)
            .field("invited_profile_id", .uuid, .required).field("status", .string, .required)
            .field("created_at", .datetime).unique(on: "post_id", "invited_profile_id").create()

        try await database.schema(CommentIdentityLockRecord.schema)
            .id().field("post_id", .uuid, .required).field("account_id", .uuid, .required)
            .field("actor_kind", .string, .required).field("thread_alias", .string).field("sigil", .string)
            .unique(on: "post_id", "account_id").create()

        try await database.schema(ConversationRecord.schema)
            .id().field("identity", .string, .required)
            .field("creator_account_id", .uuid, .required).field("recipient_account_id", .uuid, .required)
            .field("source_post_id", .uuid).field("matrix_room_ciphertext", .data, .required)
            .field("is_request", .bool, .required).field("is_accepted", .bool, .required)
            .field("disappearing_seconds", .int).field("read_receipts_enabled", .bool, .required)
            .field("typing_indicators_enabled", .bool, .required).field("created_at", .datetime)
            .field("last_event_at", .datetime).field("blocked_at", .datetime).create()

        try await database.schema(ConversationIdentityRecord.schema)
            .id().field("conversation_id", .uuid, .required).field("sealed_account_id", .data, .required)
            .field("alias", .string).field("sigil", .string, .required)
            .field("enforcement_token", .string, .required)
            .field("enforcement_digest", .string, .required)
            .unique(on: "conversation_id", "sealed_account_id").create()

        try await database.schema(MessageEventRecord.schema)
            .id().field("conversation_id", .uuid, .required)
            .field("encrypted_event_id", .string, .required)
            .field("sealed_sender_id", .data, .required)
            .field("sent_at", .datetime, .required).field("expires_at", .datetime)
            .field("deleted_at", .datetime)
            .unique(on: "conversation_id", "encrypted_event_id").create()

        try await database.schema(MessageReportRecord.schema)
            .id().field("case_token", .string, .required).field("conversation_id", .uuid, .required)
            .field("selected_evidence", .array(of: .json), .required)
            .field("category", .string, .required).field("explanation", .string)
            .field("sealed_reporter_id", .data, .required).field("created_at", .datetime)
            .unique(on: "case_token").create()

        try await database.schema(ReportRecord.schema)
            .id().field("case_token", .string, .required).field("enforcement_token", .string, .required)
            .field("content_id", .uuid, .required).field("category", .string, .required)
            .field("explanation", .string).field("sealed_reporter_id", .data, .required)
            .field("status", .string, .required).field("created_at", .datetime)
            .unique(on: "case_token").create()

        try await database.schema(QuarantineRecord.schema)
            .id().field("content_id", .uuid, .required).field("content_kind", .string, .required)
            .field("payload", .json, .required).field("created_at", .datetime)
            .unique(on: "content_id", "content_kind").create()

        try await database.schema(RateLimitRecord.schema)
            .id().field("bucket", .string, .required).field("subject_digest", .string, .required)
            .field("window_started_at", .datetime, .required).field("count", .int, .required)
            .unique(on: "bucket", "subject_digest").create()
    }

    func revert(on database: any Database) async throws {
        let schemas = [
            RateLimitRecord.schema, QuarantineRecord.schema, ReportRecord.schema, MessageReportRecord.schema,
            MessageEventRecord.schema,
            ConversationIdentityRecord.schema, ConversationRecord.schema,
            CommentIdentityLockRecord.schema, CollaboratorRecord.schema, LikeRecord.schema,
            MuteRecord.schema, BlockRecord.schema, FollowRecord.schema, ThreadIdentityRecord.schema,
            OwnershipRecord.schema, CommentRecord.schema, PostRecord.schema, MediaRecord.schema,
            TopicRecord.schema, MatrixAccountRecord.schema, SessionRecord.schema, DeviceRecord.schema, ProfileRecord.schema,
            AccountRecord.schema
        ]
        for schema in schemas { try await database.schema(schema).delete() }
    }
}

struct SeedTopics: AsyncMigration {
    func prepare(on database: any Database) async throws {
        let topics = [
            TopicRecord(slug: "after-hours", title: "After hours"),
            TopicRecord(slug: "architecture", title: "Architecture"),
            TopicRecord(slug: "music", title: "Music"),
            TopicRecord(slug: "city-life", title: "City life")
        ]
        for topic in topics where try await TopicRecord.query(on: database).filter(\.$slug == topic.slug).first() == nil {
            try await topic.create(on: database)
        }
    }

    func revert(on database: any Database) async throws {
        try await TopicRecord.query(on: database).delete()
    }
}
