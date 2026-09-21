import Foundation

public enum AccountMode: String, Codable, CaseIterable, Sendable {
    case deviceOnly
    case recoverable
}

public enum ActorKind: String, Codable, Sendable {
    case profile
    case generatedAlias
    case customAlias
    case sigil
}

public enum ActorRole: String, Codable, Sendable {
    case participant
    case originalPoster
}

public enum PostVisibility: String, Codable, Sendable {
    case attributed
    case anonymous
}

public enum AnonymousPresentationMode: String, Codable, CaseIterable, Sendable {
    case generatedAlias
    case customAlias
    case sigil
}

public enum FeedKind: String, Codable, CaseIterable, Sendable {
    case following
    case discover
}

public enum ConversationIdentity: String, Codable, Sendable {
    case identified
    case anonymous
}

public enum AnonymousRequestPolicy: String, Codable, CaseIterable, Sendable {
    case allow
    case filtered
    case disabled
}

public enum ExpirationPreset: String, Codable, CaseIterable, Sendable {
    case oneDay
    case sevenDays
    case thirtyDays
    case never
}

public enum ReportCategory: String, Codable, CaseIterable, Sendable {
    case illegalMaterial
    case childSexualAbuseMaterial
    case credibleThreat
    case criminalSolicitation
    case malwareOrSpam
    case privateInformation
}

public struct Page<T: Codable & Sendable>: Codable, Sendable {
    public let items: [T]
    public let nextCursor: String?

    public init(items: [T], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public struct ContentPreferences: Codable, Equatable, Sendable {
    public var mutedProfileIDs: Set<UUID>
    public var mutedTopicIDs: Set<UUID>
    public var mutedKeywords: Set<String>
    public var blurSensitiveMedia: Bool
    public var anonymousRequestPolicy: AnonymousRequestPolicy

    public init(
        mutedProfileIDs: Set<UUID> = [],
        mutedTopicIDs: Set<UUID> = [],
        mutedKeywords: Set<String> = [],
        blurSensitiveMedia: Bool = true,
        anonymousRequestPolicy: AnonymousRequestPolicy = .filtered
    ) {
        self.mutedProfileIDs = mutedProfileIDs
        self.mutedTopicIDs = mutedTopicIDs
        self.mutedKeywords = mutedKeywords
        self.blurSensitiveMedia = blurSensitiveMedia
        self.anonymousRequestPolicy = anonymousRequestPolicy
    }
}

public struct ProfileSummary: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let username: String
    public let displayName: String?
    public let avatarURL: URL?

    public init(id: UUID, username: String, displayName: String? = nil, avatarURL: URL? = nil) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
    }
}

public struct Profile: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let username: String
    public let avatarURL: URL?
    public let bio: String?
    public let followerCount: Int
    public let followingCount: Int
    public let isFollowedByMe: Bool

    public init(
        id: UUID,
        username: String,
        avatarURL: URL? = nil,
        bio: String? = nil,
        followerCount: Int,
        followingCount: Int,
        isFollowedByMe: Bool
    ) {
        self.id = id
        self.username = username
        self.avatarURL = avatarURL
        self.bio = bio
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.isFollowedByMe = isFollowedByMe
    }
}

public struct Topic: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let slug: String
    public let title: String

    public init(id: UUID, slug: String, title: String) {
        self.id = id
        self.slug = slug
        self.title = title
    }
}

/// The only author representation allowed in public content responses.
/// Anonymous values deliberately cannot carry an account or profile identifier.
public struct ActorPresentation: Codable, Equatable, Sendable {
    public let kind: ActorKind
    public let role: ActorRole
    public let profile: ProfileSummary?
    public let threadAlias: String?
    public let sigil: String?
    public let enforcementToken: String?

    public init(
        kind: ActorKind,
        role: ActorRole,
        profile: ProfileSummary? = nil,
        threadAlias: String? = nil,
        sigil: String? = nil,
        enforcementToken: String? = nil
    ) throws {
        if kind == .profile {
            guard profile != nil, threadAlias == nil, sigil == nil else {
                throw ContractError.invalidActorPresentation
            }
        } else {
            guard profile == nil, threadAlias != nil || sigil != nil else {
                throw ContractError.invalidActorPresentation
            }
        }
        self.kind = kind
        self.role = role
        self.profile = profile
        self.threadAlias = threadAlias
        self.sigil = sigil
        self.enforcementToken = enforcementToken
    }
}

public enum MediaKind: String, Codable, Sendable {
    case image
}

public struct Media: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let kind: MediaKind
    public let url: URL
    public let width: Int
    public let height: Int

    public init(id: UUID, kind: MediaKind = .image, url: URL, width: Int, height: Int) {
        self.id = id
        self.kind = kind
        self.url = url
        self.width = width
        self.height = height
    }
}

public enum PostReferenceKind: String, Codable, Sendable {
    case repost
    case quote
}

public struct ReferencedPost: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let actor: ActorPresentation
    public let visibility: PostVisibility
    public let body: String
    public let media: [Media]
    public let isSensitive: Bool
    public let createdAt: Date

    public init(
        id: UUID,
        actor: ActorPresentation,
        visibility: PostVisibility,
        body: String,
        media: [Media] = [],
        isSensitive: Bool = false,
        createdAt: Date
    ) {
        self.id = id
        self.actor = actor
        self.visibility = visibility
        self.body = body
        self.media = media
        self.isSensitive = isSensitive
        self.createdAt = createdAt
    }
}

public struct PostReference: Codable, Equatable, Sendable {
    public let kind: PostReferenceKind
    public let postID: UUID
    public let original: ReferencedPost?
    public let originalUnavailable: Bool

    public init(kind: PostReferenceKind, postID: UUID, original: ReferencedPost?, originalUnavailable: Bool) {
        self.kind = kind
        self.postID = postID
        self.original = original
        self.originalUnavailable = originalUnavailable
    }
}

public struct Post: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let actor: ActorPresentation
    public let visibility: PostVisibility
    public let body: String
    public let topic: Topic?
    public let media: [Media]
    public let reference: PostReference?
    public let createdAt: Date
    public let editedAt: Date?
    public let expiresAt: Date?
    public let isSensitive: Bool
    public let likeCount: Int
    public let commentCount: Int
    public let isLikedByMe: Bool
    public let isMine: Bool
    public let acceptedCollaborators: [ProfileSummary]?

    public init(
        id: UUID,
        actor: ActorPresentation,
        visibility: PostVisibility,
        body: String,
        topic: Topic? = nil,
        media: [Media] = [],
        reference: PostReference? = nil,
        createdAt: Date,
        editedAt: Date? = nil,
        expiresAt: Date? = nil,
        isSensitive: Bool = false,
        likeCount: Int = 0,
        commentCount: Int = 0,
        isLikedByMe: Bool = false,
        isMine: Bool = false,
        acceptedCollaborators: [ProfileSummary]? = nil
    ) {
        self.id = id
        self.actor = actor
        self.visibility = visibility
        self.body = body
        self.topic = topic
        self.media = media
        self.reference = reference
        self.createdAt = createdAt
        self.editedAt = editedAt
        self.expiresAt = expiresAt
        self.isSensitive = isSensitive
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.isLikedByMe = isLikedByMe
        self.isMine = isMine
        self.acceptedCollaborators = acceptedCollaborators
    }
}

public struct Comment: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let postID: UUID
    public let parentID: UUID?
    public let rootID: UUID?
    public let actor: ActorPresentation
    public let body: String?
    public let createdAt: Date
    public let editedAt: Date?
    public let isDeleted: Bool
    public let likeCount: Int
    public let isLikedByMe: Bool
    public let isMine: Bool

    public init(
        id: UUID,
        postID: UUID,
        parentID: UUID? = nil,
        rootID: UUID? = nil,
        actor: ActorPresentation,
        body: String?,
        createdAt: Date,
        editedAt: Date? = nil,
        isDeleted: Bool = false,
        likeCount: Int = 0,
        isLikedByMe: Bool = false,
        isMine: Bool = false
    ) {
        self.id = id
        self.postID = postID
        self.parentID = parentID
        self.rootID = rootID
        self.actor = actor
        self.body = body
        self.createdAt = createdAt
        self.editedAt = editedAt
        self.isDeleted = isDeleted
        self.likeCount = likeCount
        self.isLikedByMe = isLikedByMe
        self.isMine = isMine
    }
}

public struct Conversation: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let identity: ConversationIdentity
    public let actor: ActorPresentation
    public let isRequest: Bool
    public let isAccepted: Bool
    public let lastEventAt: Date?
    public let disappearingSeconds: Int?
    public let readReceiptsEnabled: Bool
    public let typingIndicatorsEnabled: Bool

    public init(
        id: UUID,
        identity: ConversationIdentity,
        actor: ActorPresentation,
        isRequest: Bool,
        isAccepted: Bool,
        lastEventAt: Date? = nil,
        disappearingSeconds: Int? = nil,
        readReceiptsEnabled: Bool = false,
        typingIndicatorsEnabled: Bool = false
    ) {
        self.id = id
        self.identity = identity
        self.actor = actor
        self.isRequest = isRequest
        self.isAccepted = isAccepted
        self.lastEventAt = lastEventAt
        self.disappearingSeconds = disappearingSeconds
        self.readReceiptsEnabled = readReceiptsEnabled
        self.typingIndicatorsEnabled = typingIndicatorsEnabled
    }
}

/// Message plaintext stays inside the E2EE client. The Veil API only exchanges
/// opaque Matrix event metadata.
public struct Message: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let conversationID: UUID
    public let encryptedEventID: String
    public let sender: ActorPresentation
    public let sentAt: Date
    public let expiresAt: Date?
    public let deletedForAll: Bool

    public init(
        id: UUID,
        conversationID: UUID,
        encryptedEventID: String,
        sender: ActorPresentation,
        sentAt: Date,
        expiresAt: Date? = nil,
        deletedForAll: Bool = false
    ) {
        self.id = id
        self.conversationID = conversationID
        self.encryptedEventID = encryptedEventID
        self.sender = sender
        self.sentAt = sentAt
        self.expiresAt = expiresAt
        self.deletedForAll = deletedForAll
    }
}

public struct AccountCreateRequest: Codable, Sendable {
    public let username: String
    public let mode: AccountMode
    public let devicePublicKey: String
    public let securityPassphrase: String?

    public init(username: String, mode: AccountMode, devicePublicKey: String, securityPassphrase: String? = nil) {
        self.username = username
        self.mode = mode
        self.devicePublicKey = devicePublicKey
        self.securityPassphrase = securityPassphrase
    }
}

public struct AccountRecoveryRequest: Codable, Sendable {
    public let username: String
    public let securityPassphrase: String
    public let recoveryCode: String
    public let replacementDevicePublicKey: String

    public init(username: String, securityPassphrase: String, recoveryCode: String, replacementDevicePublicKey: String) {
        self.username = username
        self.securityPassphrase = securityPassphrase
        self.recoveryCode = recoveryCode
        self.replacementDevicePublicKey = replacementDevicePublicKey
    }
}

public struct SessionEnvelope: Codable, Sendable {
    public let sessionToken: String
    public let profile: Profile
    public let recoveryCode: String?
    public let historicalMessagesRequireOldDeviceTransfer: Bool

    public init(
        sessionToken: String,
        profile: Profile,
        recoveryCode: String?,
        historicalMessagesRequireOldDeviceTransfer: Bool
    ) {
        self.sessionToken = sessionToken
        self.profile = profile
        self.recoveryCode = recoveryCode
        self.historicalMessagesRequireOldDeviceTransfer = historicalMessagesRequireOldDeviceTransfer
    }
}

/// Authenticated bootstrap material for the isolated messaging client. Matrix
/// identifiers stay inside the MessagingProvider and are never used as Veil
/// profile or anonymous identities.
public struct MessagingSessionConfiguration: Codable, Sendable {
    public let homeserverURL: URL
    public let userID: String
    public let accessToken: String
    public let deviceID: String

    public init(homeserverURL: URL, userID: String, accessToken: String, deviceID: String) {
        self.homeserverURL = homeserverURL
        self.userID = userID
        self.accessToken = accessToken
        self.deviceID = deviceID
    }
}

public struct MessagingRoomConfiguration: Codable, Sendable {
    public let roomID: String

    public init(roomID: String) {
        self.roomID = roomID
    }
}

public struct ProfileUpdateRequest: Codable, Sendable {
    public let avatarMediaID: UUID?
    public let bio: String?

    public init(avatarMediaID: UUID? = nil, bio: String? = nil) {
        self.avatarMediaID = avatarMediaID
        self.bio = bio
    }
}

public struct PostCreateRequest: Codable, Sendable {
    public let visibility: PostVisibility
    public let anonymousMode: AnonymousPresentationMode?
    public let customAlias: String?
    public let body: String
    public let topicID: UUID?
    public let mediaIDs: [UUID]
    public let expiration: ExpirationPreset
    public let isSensitive: Bool
    public let collaboratorProfileIDs: [UUID]
    public let referenceKind: PostReferenceKind?
    public let referencedPostID: UUID?

    public init(
        visibility: PostVisibility,
        anonymousMode: AnonymousPresentationMode? = nil,
        customAlias: String? = nil,
        body: String,
        topicID: UUID? = nil,
        mediaIDs: [UUID] = [],
        expiration: ExpirationPreset = .never,
        isSensitive: Bool = false,
        collaboratorProfileIDs: [UUID] = [],
        referenceKind: PostReferenceKind? = nil,
        referencedPostID: UUID? = nil
    ) {
        self.visibility = visibility
        self.anonymousMode = anonymousMode
        self.customAlias = customAlias
        self.body = body
        self.topicID = topicID
        self.mediaIDs = mediaIDs
        self.expiration = expiration
        self.isSensitive = isSensitive
        self.collaboratorProfileIDs = collaboratorProfileIDs
        self.referenceKind = referenceKind
        self.referencedPostID = referencedPostID
    }
}

public struct PostEditRequest: Codable, Sendable {
    public let body: String
    public let topicID: UUID?
    public let isSensitive: Bool

    public init(body: String, topicID: UUID? = nil, isSensitive: Bool) {
        self.body = body
        self.topicID = topicID
        self.isSensitive = isSensitive
    }
}

public struct PostCreationEnvelope: Codable, Sendable {
    public let post: Post?
    public let postID: UUID
    public let publicationState: String
    public let pendingCollaboratorCount: Int

    public init(post: Post?, postID: UUID, publicationState: String, pendingCollaboratorCount: Int) {
        self.post = post
        self.postID = postID
        self.publicationState = publicationState
        self.pendingCollaboratorCount = pendingCollaboratorCount
    }
}

public struct CollaborationInvitation: Codable, Identifiable, Sendable {
    public let id: UUID
    public let postID: UUID
    public let creator: ProfileSummary
    public let visibility: PostVisibility
    public let excerpt: String

    public init(id: UUID, postID: UUID, creator: ProfileSummary, visibility: PostVisibility, excerpt: String) {
        self.id = id
        self.postID = postID
        self.creator = creator
        self.visibility = visibility
        self.excerpt = excerpt
    }
}

public struct SearchResults: Codable, Sendable {
    public let profiles: [Profile]
    public let topics: [Topic]
    public let posts: [Post]

    public init(profiles: [Profile], topics: [Topic], posts: [Post]) {
        self.profiles = profiles
        self.topics = topics
        self.posts = posts
    }
}

public struct VeiledActivity: Codable, Sendable {
    public let posts: [Post]
    public let comments: [Comment]
    public let conversations: [Conversation]

    public init(posts: [Post], comments: [Comment], conversations: [Conversation]) {
        self.posts = posts
        self.comments = comments
        self.conversations = conversations
    }
}

public struct CommentCreateRequest: Codable, Sendable {
    public let body: String
    public let parentID: UUID?
    public let visibility: PostVisibility
    public let anonymousMode: AnonymousPresentationMode?
    public let customAlias: String?

    public init(
        body: String,
        parentID: UUID? = nil,
        visibility: PostVisibility,
        anonymousMode: AnonymousPresentationMode? = nil,
        customAlias: String? = nil
    ) {
        self.body = body
        self.parentID = parentID
        self.visibility = visibility
        self.anonymousMode = anonymousMode
        self.customAlias = customAlias
    }
}

public struct CommentEditRequest: Codable, Sendable {
    public let body: String

    public init(body: String) {
        self.body = body
    }
}

public struct ConversationRequest: Codable, Sendable {
    public let targetProfileID: UUID?
    public let sourcePostID: UUID?
    public let identity: ConversationIdentity
    public let encryptedInitialEventID: String?
    public let containsLink: Bool
    public let containsMedia: Bool

    public init(
        targetProfileID: UUID? = nil,
        sourcePostID: UUID? = nil,
        identity: ConversationIdentity,
        encryptedInitialEventID: String? = nil,
        containsLink: Bool = false,
        containsMedia: Bool = false
    ) {
        self.targetProfileID = targetProfileID
        self.sourcePostID = sourcePostID
        self.identity = identity
        self.encryptedInitialEventID = encryptedInitialEventID
        self.containsLink = containsLink
        self.containsMedia = containsMedia
    }
}

public struct EncryptedEventRequest: Codable, Sendable {
    public let encryptedEventID: String
    public let sentAt: Date
    public let disappearingSeconds: Int?
    public let containsLink: Bool
    public let containsMedia: Bool

    public init(
        encryptedEventID: String,
        sentAt: Date,
        disappearingSeconds: Int? = nil,
        containsLink: Bool = false,
        containsMedia: Bool = false
    ) {
        self.encryptedEventID = encryptedEventID
        self.sentAt = sentAt
        self.disappearingSeconds = disappearingSeconds
        self.containsLink = containsLink
        self.containsMedia = containsMedia
    }
}

public struct ConversationSettingsRequest: Codable, Sendable {
    public let disappearingSeconds: Int?
    public let readReceiptsEnabled: Bool
    public let typingIndicatorsEnabled: Bool

    public init(disappearingSeconds: Int?, readReceiptsEnabled: Bool, typingIndicatorsEnabled: Bool) {
        self.disappearingSeconds = disappearingSeconds
        self.readReceiptsEnabled = readReceiptsEnabled
        self.typingIndicatorsEnabled = typingIndicatorsEnabled
    }
}

public struct ReportRequest: Codable, Sendable {
    public let contentID: UUID
    public let category: ReportCategory
    public let explanation: String?

    public init(contentID: UUID, category: ReportCategory, explanation: String? = nil) {
        self.contentID = contentID
        self.category = category
        self.explanation = explanation
    }
}

public struct SelectedMessageReportRequest: Codable, Sendable {
    public let conversationID: UUID
    public let selectedMessages: [ReportedMessageEvidence]
    public let category: ReportCategory
    public let explanation: String?

    public init(
        conversationID: UUID,
        selectedMessages: [ReportedMessageEvidence],
        category: ReportCategory,
        explanation: String? = nil
    ) {
        self.conversationID = conversationID
        self.selectedMessages = selectedMessages
        self.category = category
        self.explanation = explanation
    }
}

/// Plaintext is accepted only through the explicit report flow and only for
/// messages deliberately selected by the reporter.
public struct ReportedMessageEvidence: Codable, Sendable {
    public let encryptedEventID: String
    public let sender: ActorPresentation
    public let body: String
    public let sentAt: Date

    public init(encryptedEventID: String, sender: ActorPresentation, body: String, sentAt: Date) {
        self.encryptedEventID = encryptedEventID
        self.sender = sender
        self.body = body
        self.sentAt = sentAt
    }
}

public struct ReportReceipt: Codable, Sendable {
    public let caseToken: String

    public init(caseToken: String) {
        self.caseToken = caseToken
    }
}

public struct ModeratorCase: Codable, Identifiable, Sendable {
    public let id: UUID
    public let caseToken: String
    public let enforcementToken: String
    public let contentID: UUID
    public let category: ReportCategory
    public let explanation: String?

    public init(
        id: UUID,
        caseToken: String,
        enforcementToken: String,
        contentID: UUID,
        category: ReportCategory,
        explanation: String? = nil
    ) {
        self.id = id
        self.caseToken = caseToken
        self.enforcementToken = enforcementToken
        self.contentID = contentID
        self.category = category
        self.explanation = explanation
    }
}

public struct Health: Codable, Sendable {
    public let status: String
    public let database: String
    public let matrix: String

    public init(status: String, database: String, matrix: String) {
        self.status = status
        self.database = database
        self.matrix = matrix
    }
}

public enum ContractError: Error, Equatable {
    case invalidActorPresentation
}
