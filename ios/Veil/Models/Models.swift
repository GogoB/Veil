import Foundation

enum AccountMode: String, CaseIterable, Identifiable, Codable {
    case deviceOnly
    case recoverable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deviceOnly: return "This device only"
        case .recoverable: return "Recoverable"
        }
    }

    var summary: String {
        switch self {
        case .deviceOnly:
            return "Lose every enrolled device and the account cannot be recovered."
        case .recoverable:
            return "A security passphrase and a separate recovery code are both required."
        }
    }
}

enum FeedKind: String, CaseIterable, Identifiable {
    case discover
    case following

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum AnonymousPresentationMode: String, CaseIterable, Identifiable {
    case generatedAlias
    case customAlias
    case sigil

    var id: String { rawValue }

    var title: String {
        switch self {
        case .generatedAlias: return "Generated"
        case .customAlias: return "Custom"
        case .sigil: return "Sigil only"
        }
    }
}

enum PostIdentityChoice: String, CaseIterable, Identifiable {
    case profile
    case anonymous

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum AnonymousRequestPolicy: String, CaseIterable, Identifiable {
    case allow
    case filtered
    case disabled

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ActorRole: String, Codable, Hashable {
    case participant
    case originalPoster
}

enum ActorPresentation: Hashable {
    case profile(handle: String, displayName: String)
    case anonymous(alias: String?, sigilSeed: Int, role: ActorRole)

    var displayName: String? {
        switch self {
        case let .profile(_, displayName): return displayName
        case let .anonymous(alias, _, _): return alias
        }
    }

    var subtitle: String {
        switch self {
        case let .profile(handle, _): return "@\(handle)"
        case let .anonymous(alias, _, _): return alias == nil ? "Thread sigil" : "Thread alias"
        }
    }

    var isAnonymous: Bool {
        if case .anonymous = self { return true }
        return false
    }

    var sigilSeed: Int? {
        if case let .anonymous(_, seed, _) = self { return seed }
        return nil
    }
}

enum PostExpiration: String, CaseIterable, Identifiable {
    case oneDay
    case sevenDays
    case thirtyDays
    case never

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneDay: return "24 hours"
        case .sevenDays: return "7 days"
        case .thirtyDays: return "30 days"
        case .never: return "Never"
        }
    }

    var shortLabel: String? {
        switch self {
        case .oneDay: return "24h left"
        case .sevenDays: return "7d left"
        case .thirtyDays: return "30d left"
        case .never: return nil
        }
    }
}

struct Topic: Identifiable, Hashable {
    let id: String
    let title: String

    static let afterHours = Topic(id: "after-hours", title: "After hours")
    static let architecture = Topic(id: "architecture", title: "Architecture")
    static let music = Topic(id: "music", title: "Music")
    static let cityLife = Topic(id: "city-life", title: "City life")
}

enum PostMedia: Identifiable, Equatable {
    case architecture(UUID)
    case image(id: UUID, data: Data)

    var id: UUID {
        switch self {
        case let .architecture(id), let .image(id, _): return id
        }
    }
}

struct DemoPost: Identifiable, Equatable {
    let id: UUID
    var actor: ActorPresentation
    var body: String
    let topic: Topic?
    let createdLabel: String
    var likeCount: Int
    var commentCount: Int
    var isLiked: Bool
    let expiration: PostExpiration
    let isSensitive: Bool
    let isMine: Bool
    let eligibleForFollowing: Bool
    let media: [PostMedia]
}

struct DemoComment: Identifiable, Equatable {
    let id: UUID
    let actor: ActorPresentation
    let body: String
    let createdLabel: String
}

struct DemoConversation: Identifiable {
    let id: UUID
    let actor: ActorPresentation
    let preview: String
    let time: String
    let isRequest: Bool
}

enum ComposerValidationError: LocalizedError {
    case empty
    case tooLong
    case tooManyImages
    case aliasLength
    case invalidAlias
    case reservedAlias

    var errorDescription: String? {
        switch self {
        case .empty: return "Write something or add an image."
        case .tooLong: return "Keep the post to 2,000 characters."
        case .tooManyImages: return "Add no more than four images."
        case .aliasLength: return "Use 2–24 characters for a custom thread alias."
        case .invalidAlias: return "Use letters, numbers, spaces, dots, underscores, or hyphens."
        case .reservedAlias: return "That system-style name is reserved. Choose another."
        }
    }
}
