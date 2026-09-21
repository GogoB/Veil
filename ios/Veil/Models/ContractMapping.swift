import Foundation
import VeilShared

extension VeilShared.ActorPresentation {
    var localPresentation: ActorPresentation {
        if kind == .profile, let profile {
            return .profile(handle: profile.username, displayName: profile.displayName ?? profile.username)
        }
        return .anonymous(
            alias: threadAlias,
            sigilSeed: Self.visualSeed(sigil ?? threadAlias ?? "veil"),
            role: role == .originalPoster ? .originalPoster : .participant
        )
    }

    private static func visualSeed(_ value: String) -> Int {
        value.utf8.reduce(17) { (($0 &* 31) &+ Int($1)) % 10_007 }
    }
}

extension VeilShared.Topic {
    var localTopic: Topic { Topic(id: id.uuidString, title: title) }
}

extension VeilShared.Post {
    func localPost(apiBaseURL: URL) -> DemoPost {
        let localReference = reference.map { reference in
            let original = reference.original
            return DemoPostReference(
                label: reference.originalUnavailable ? "Original unavailable" : reference.kind.rawValue.capitalized,
                actor: original?.actor.localPresentation,
                body: original?.body,
                createdLabel: original?.createdAt.relativeLabel,
                media: original?.media.map { item in
                    let resolved = URL(string: item.url.absoluteString, relativeTo: apiBaseURL)?.absoluteURL ?? item.url
                    return .remote(id: item.id, url: resolved)
                } ?? [],
                isSensitive: original?.isSensitive ?? false,
                originalUnavailable: reference.originalUnavailable
            )
        }
        return DemoPost(
            id: id,
            actor: actor.localPresentation,
            body: body,
            topic: topic?.localTopic,
            createdLabel: createdAt.relativeLabel,
            likeCount: likeCount,
            commentCount: commentCount,
            isLiked: isLikedByMe,
            expiration: expiresAt.localExpiration,
            isSensitive: isSensitive,
            isMine: isMine,
            eligibleForFollowing: visibility == .attributed,
            media: media.map { item in
                let resolved = URL(string: item.url.absoluteString, relativeTo: apiBaseURL)?.absoluteURL ?? item.url
                return .remote(id: item.id, url: resolved)
            },
            isEdited: editedAt != nil,
            reference: localReference,
            collaboratorHandles: acceptedCollaborators?.map(\.username) ?? [],
            actorProfileID: actor.profile?.id,
            actorEnforcementToken: actor.enforcementToken
        )
    }
}

extension VeilShared.Comment {
    var localComment: DemoComment {
        DemoComment(
            id: id,
            actor: actor.localPresentation,
            body: body ?? "Comment deleted",
            createdLabel: createdAt.relativeLabel,
            parentID: parentID,
            rootID: rootID,
            isDeleted: isDeleted,
            isEdited: editedAt != nil,
            likeCount: likeCount,
            isLiked: isLikedByMe,
            isMine: isMine
        )
    }
}

extension VeilShared.Conversation {
    var localConversation: DemoConversation {
        DemoConversation(
            id: id,
            actor: actor.localPresentation,
            preview: isRequest ? "Encrypted message request" : "End-to-end encrypted conversation",
            time: lastEventAt?.relativeLabel ?? "New",
            isRequest: isRequest,
            isAccepted: isAccepted
        )
    }
}

private extension Date {
    var relativeLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

private extension Optional where Wrapped == Date {
    var localExpiration: PostExpiration {
        guard let date = self else { return .never }
        let interval = date.timeIntervalSinceNow
        if interval <= 2 * 86_400 { return .oneDay }
        if interval <= 10 * 86_400 { return .sevenDays }
        return .thirtyDays
    }
}
