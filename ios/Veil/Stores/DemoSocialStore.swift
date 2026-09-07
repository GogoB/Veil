import Foundation

@MainActor
final class DemoSocialStore: ObservableObject {
    @Published private(set) var posts: [DemoPost]
    @Published private(set) var comments: [UUID: [DemoComment]]
    @Published private(set) var mutedTopicIDs: Set<String> = []
    @Published private(set) var hiddenPostIDs: Set<UUID> = []

    let topics: [Topic] = [.afterHours, .architecture, .music, .cityLife]
    let conversations: [DemoConversation]

    init() {
        let quietPostID = UUID()
        let architectureID = UUID()
        posts = [
            DemoPost(
                id: quietPostID,
                actor: .anonymous(alias: "soft static", sigilSeed: 17, role: .originalPoster),
                body: "Anyone else feel more like themselves after the city goes quiet?",
                topic: .afterHours,
                createdLabel: "12m",
                likeCount: 128,
                commentCount: 24,
                isLiked: false,
                expiration: .oneDay,
                isSensitive: false,
                isMine: false,
                eligibleForFollowing: false,
                media: []
            ),
            DemoPost(
                id: architectureID,
                actor: .profile(handle: "noor", displayName: "noor"),
                body: "Some buildings feel like a pause button.",
                topic: .architecture,
                createdLabel: "28m",
                likeCount: 86,
                commentCount: 9,
                isLiked: false,
                expiration: .never,
                isSensitive: false,
                isMine: true,
                eligibleForFollowing: true,
                media: [.architecture(UUID())]
            ),
            DemoPost(
                id: UUID(),
                actor: .anonymous(alias: "low orbit", sigilSeed: 29, role: .participant),
                body: "An album you wish you could hear for the first time again. I’ll start: Untrue.",
                topic: .music,
                createdLabel: "41m",
                likeCount: 204,
                commentCount: 67,
                isLiked: false,
                expiration: .sevenDays,
                isSensitive: false,
                isMine: false,
                eligibleForFollowing: false,
                media: []
            ),
            DemoPost(
                id: UUID(),
                actor: .profile(handle: "formandfield", displayName: "form & field"),
                body: "A good public space lets you be alone without feeling lonely.",
                topic: .architecture,
                createdLabel: "1h",
                likeCount: 53,
                commentCount: 8,
                isLiked: false,
                expiration: .never,
                isSensitive: false,
                isMine: false,
                eligibleForFollowing: true,
                media: []
            )
        ]
        comments = [
            quietPostID: [
                DemoComment(id: UUID(), actor: .anonymous(alias: "night window", sigilSeed: 41, role: .participant), body: "Less noise outside. Less noise in my head.", createdLabel: "8m"),
                DemoComment(id: UUID(), actor: .anonymous(alias: "soft static", sigilSeed: 17, role: .originalPoster), body: "Exactly this. Everything has a little more room.", createdLabel: "6m")
            ]
        ]
        conversations = [
            DemoConversation(id: UUID(), actor: .profile(handle: "formandfield", displayName: "form & field"), preview: "That corner catches the best afternoon light.", time: "14m", isRequest: false),
            DemoConversation(id: UUID(), actor: .anonymous(alias: "faint signal", sigilSeed: 73, role: .participant), preview: "Your post stayed with me.", time: "1h", isRequest: true)
        ]
    }

    func visiblePosts(in feed: FeedKind, topic: Topic?) -> [DemoPost] {
        posts.filter { post in
            !hiddenPostIDs.contains(post.id)
                && !(post.topic.map { mutedTopicIDs.contains($0.id) } ?? false)
                && (feed == .discover || post.eligibleForFollowing)
                && (topic == nil || post.topic == topic)
        }
    }

    func setCurrentProfileHandle(_ handle: String) {
        let normalized = handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }
        for index in posts.indices where posts[index].isMine && !posts[index].actor.isAnonymous {
            posts[index].actor = .profile(handle: normalized, displayName: normalized)
        }
    }

    func search(_ query: String) -> [DemoPost] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }
        return posts.filter { post in
            guard !hiddenPostIDs.contains(post.id) else { return false }
            var searchable = [post.body, post.topic?.title ?? ""]
            if case let .profile(handle, displayName) = post.actor {
                searchable.append(contentsOf: [handle, displayName])
            }
            return searchable.joined(separator: " ").lowercased().contains(needle)
        }
    }

    func toggleLike(postID: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index].isLiked.toggle()
        posts[index].likeCount += posts[index].isLiked ? 1 : -1
    }

    func hide(postID: UUID) {
        hiddenPostIDs.insert(postID)
    }

    func mute(topic: Topic) {
        mutedTopicIDs.insert(topic.id)
    }

    func resetFeedControls() {
        hiddenPostIDs.removeAll()
        mutedTopicIDs.removeAll()
    }

    func comments(for postID: UUID) -> [DemoComment] {
        comments[postID] ?? []
    }

    func addComment(_ body: String, to postID: UUID) {
        let normalized = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 2_000 else { return }
        let identity = threadIdentity(for: postID)
        comments[postID, default: []].append(
            DemoComment(id: UUID(), actor: identity, body: normalized, createdLabel: "Now")
        )
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index].commentCount += 1
    }

    @discardableResult
    func createPost(
        body: String,
        identity: PostIdentityChoice,
        anonymousMode: AnonymousPresentationMode,
        generatedAlias: String,
        customAlias: String,
        sigilSeed: Int,
        profileHandle: String,
        topic: Topic?,
        expiration: PostExpiration,
        isSensitive: Bool,
        images: [Data]
    ) throws -> UUID {
        let normalizedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedBody.isEmpty || !images.isEmpty else { throw ComposerValidationError.empty }
        guard normalizedBody.count <= 2_000 else { throw ComposerValidationError.tooLong }
        guard images.count <= 4 else { throw ComposerValidationError.tooManyImages }

        let actor: ActorPresentation
        switch identity {
        case .profile:
            actor = .profile(handle: profileHandle, displayName: profileHandle)
        case .anonymous:
            let alias: String?
            switch anonymousMode {
            case .generatedAlias:
                alias = generatedAlias
            case .sigil:
                alias = nil
            case .customAlias:
                alias = try Self.validatedAlias(customAlias)
            }
            actor = .anonymous(alias: alias, sigilSeed: sigilSeed, role: .originalPoster)
        }

        let id = UUID()
        let post = DemoPost(
            id: id,
            actor: actor,
            body: normalizedBody,
            topic: topic,
            createdLabel: "Now",
            likeCount: 0,
            commentCount: 0,
            isLiked: false,
            expiration: expiration,
            isSensitive: isSensitive,
            isMine: true,
            eligibleForFollowing: identity == .profile,
            media: images.map { .image(id: UUID(), data: $0) }
        )
        posts.insert(post, at: 0)
        return id
    }

    var veiledActivity: [DemoPost] {
        posts.filter { $0.isMine && $0.actor.isAnonymous }
    }

    private func threadIdentity(for postID: UUID) -> ActorPresentation {
        let stable = abs(postID.uuidString.hashValue)
        let aliases = ["paper moon", "quiet tide", "hollow star", "silver echo"]
        return .anonymous(alias: aliases[stable % aliases.count], sigilSeed: stable % 97, role: .participant)
    }

    private static func validatedAlias(_ value: String) throws -> String {
        let alias = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...24).contains(alias.count) else { throw ComposerValidationError.aliasLength }
        let allowed = CharacterSet.letters
            .union(.decimalDigits)
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "._-"))
        guard alias.unicodeScalars.allSatisfy(allowed.contains) else { throw ComposerValidationError.invalidAlias }

        let words = alias.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
        let reserved: Set<String> = ["admin", "administrator", "moderator", "mod", "support", "system", "official", "veil"]
        guard reserved.isDisjoint(with: Set(words)) else { throw ComposerValidationError.reservedAlias }
        return alias
    }
}
