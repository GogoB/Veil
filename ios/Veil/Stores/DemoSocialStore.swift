import Foundation
import UIKit
import VeilShared

@MainActor
final class DemoSocialStore: ObservableObject {
    @Published private(set) var posts: [DemoPost]
    @Published private(set) var comments: [UUID: [DemoComment]]
    @Published private(set) var mutedTopicIDs: Set<String> = []
    @Published private(set) var hiddenPostIDs: Set<UUID> = []
    @Published private(set) var veiledPosts: [DemoPost] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var backendError: String?
    @Published private(set) var searchPosts: [DemoPost] = []
    @Published private(set) var searchProfiles: [VeilShared.Profile] = []
    @Published private(set) var searchTopics: [Topic] = []
    @Published private(set) var isSearching = false
    @Published private(set) var collaborationInvitations: [VeilShared.CollaborationInvitation] = []
    @Published private(set) var currentProfile: VeilShared.Profile?
    @Published private(set) var currentProfilePosts: [DemoPost] = []

    @Published private(set) var topics: [Topic]
    let conversations: [DemoConversation]
    private let apiClient: APIClient
    private var sessionToken: String?
    private var currentProfileID: UUID?

    init(apiClient: APIClient = .init()) {
        self.apiClient = apiClient
        topics = [.afterHours, .architecture, .music, .cityLife]
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

    func connect(sessionToken: String?, demoMode: Bool) async {
        guard !demoMode, let sessionToken else { return }
        self.sessionToken = sessionToken
        isRefreshing = true
        backendError = nil
        defer { isRefreshing = false }
        do {
            async let remoteTopics = apiClient.topics(token: sessionToken)
            async let remoteFeed = apiClient.feed(VeilShared.FeedKind.discover, token: sessionToken)
            async let activity = apiClient.veiledActivity(token: sessionToken)
            async let profile = apiClient.currentProfile(token: sessionToken)
            async let invitations = apiClient.collaborationInvitations(token: sessionToken)
            topics = try await remoteTopics.map(\.localTopic)
            posts = try await remoteFeed.items.map { $0.localPost(apiBaseURL: apiClient.baseURL) }
            veiledPosts = try await activity.posts.map { $0.localPost(apiBaseURL: apiClient.baseURL) }
            let currentProfile = try await profile
            currentProfileID = currentProfile.id
            self.currentProfile = currentProfile
            currentProfilePosts = try await apiClient.profilePosts(
                profileID: currentProfile.id,
                token: sessionToken
            ).items.map { $0.localPost(apiBaseURL: apiClient.baseURL) }
            collaborationInvitations = try await invitations
        } catch {
            backendError = error.localizedDescription
        }
    }

    func refresh(feed: FeedKind) async {
        guard let sessionToken else { return }
        isRefreshing = true
        backendError = nil
        defer { isRefreshing = false }
        do {
            let kind: VeilShared.FeedKind = feed == .following ? .following : .discover
            let response = try await apiClient.feed(kind, token: sessionToken)
            posts = response.items.map { $0.localPost(apiBaseURL: apiClient.baseURL) }
        } catch {
            backendError = error.localizedDescription
        }
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

    func performSearch(_ query: String) async {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            searchPosts = []
            searchProfiles = []
            searchTopics = []
            return
        }
        guard let sessionToken else {
            searchPosts = search(normalized)
            searchProfiles = []
            searchTopics = topics.filter { $0.title.localizedCaseInsensitiveContains(normalized) }
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            let result = try await apiClient.search(normalized, token: sessionToken)
            searchPosts = result.posts.map { $0.localPost(apiBaseURL: apiClient.baseURL) }
            searchProfiles = result.profiles
            searchTopics = result.topics.map(\.localTopic)
        } catch { backendError = error.localizedDescription }
    }

    func toggleLike(postID: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index].isLiked.toggle()
        posts[index].likeCount += posts[index].isLiked ? 1 : -1
        guard let sessionToken else { return }
        let intendedState = posts[index].isLiked
        Task {
            do { try await apiClient.setPostLike(id: postID, liked: intendedState, token: sessionToken) }
            catch {
                guard let current = posts.firstIndex(where: { $0.id == postID }), posts[current].isLiked == intendedState else { return }
                posts[current].isLiked.toggle()
                posts[current].likeCount += posts[current].isLiked ? 1 : -1
                backendError = error.localizedDescription
            }
        }
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

    func addComment(
        _ body: String,
        to postID: UUID,
        parentID: UUID? = nil,
        identity: PostIdentityChoice = .anonymous
    ) {
        let normalized = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 2_000 else { return }
        if let sessionToken {
            Task {
                do {
                    let value = try await apiClient.createComment(
                        postID: postID,
                        body: VeilShared.CommentCreateRequest(
                            body: normalized,
                            parentID: parentID,
                            visibility: identity == .profile ? .attributed : .anonymous,
                            anonymousMode: identity == .anonymous ? .generatedAlias : nil
                        ),
                        token: sessionToken
                    )
                    comments[postID, default: []].append(value.localComment)
                    if let index = posts.firstIndex(where: { $0.id == postID }) { posts[index].commentCount += 1 }
                } catch { backendError = error.localizedDescription }
            }
            return
        }
        let actor: ActorPresentation = identity == .profile
            ? .profile(handle: "you", displayName: "you")
            : threadIdentity(for: postID)
        comments[postID, default: []].append(
            DemoComment(
                id: UUID(),
                actor: actor,
                body: normalized,
                createdLabel: "Now",
                parentID: parentID,
                rootID: parentID,
                isMine: true
            )
        )
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index].commentCount += 1
    }

    func toggleCommentLike(_ commentID: UUID, in postID: UUID) {
        guard var thread = comments[postID], let index = thread.firstIndex(where: { $0.id == commentID }) else { return }
        thread[index].isLiked.toggle()
        thread[index].likeCount += thread[index].isLiked ? 1 : -1
        let intended = thread[index].isLiked
        comments[postID] = thread
        guard let sessionToken else { return }
        Task {
            do { try await apiClient.setCommentLike(id: commentID, liked: intended, token: sessionToken) }
            catch {
                guard var currentThread = comments[postID],
                      let current = currentThread.firstIndex(where: { $0.id == commentID }),
                      currentThread[current].isLiked == intended else { return }
                currentThread[current].isLiked.toggle()
                currentThread[current].likeCount += currentThread[current].isLiked ? 1 : -1
                comments[postID] = currentThread
                backendError = error.localizedDescription
            }
        }
    }

    func editComment(_ commentID: UUID, in postID: UUID, body: String) async {
        let normalized = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 2_000 else { return }
        guard let sessionToken else {
            if var thread = comments[postID], let index = thread.firstIndex(where: { $0.id == commentID }) {
                let current = thread[index]
                thread[index] = DemoComment(
                    id: current.id,
                    actor: current.actor,
                    body: normalized,
                    createdLabel: current.createdLabel,
                    parentID: current.parentID,
                    rootID: current.rootID,
                    isDeleted: false,
                    isEdited: true,
                    likeCount: current.likeCount,
                    isLiked: current.isLiked,
                    isMine: true
                )
                comments[postID] = thread
            }
            return
        }
        do {
            let updated = try await apiClient.editComment(id: commentID, body: normalized, token: sessionToken).localComment
            if let index = comments[postID]?.firstIndex(where: { $0.id == commentID }) { comments[postID]?[index] = updated }
        } catch { backendError = error.localizedDescription }
    }

    func deleteComment(_ commentID: UUID, in postID: UUID) async {
        guard let sessionToken else {
            comments[postID]?.removeAll { $0.id == commentID }
            return
        }
        do {
            try await apiClient.deleteComment(id: commentID, token: sessionToken)
            await loadComments(for: postID)
            if let index = posts.firstIndex(where: { $0.id == postID }) {
                posts[index].commentCount = max(0, posts[index].commentCount - 1)
            }
        } catch { backendError = error.localizedDescription }
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
        images: [Data],
        collaboratorProfileIDs: [UUID] = [],
        referenceKind: VeilShared.PostReferenceKind? = nil,
        referencedPostID: UUID? = nil
    ) async throws -> UUID {
        let normalizedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedBody.isEmpty || !images.isEmpty || referenceKind == .repost else { throw ComposerValidationError.empty }
        guard normalizedBody.count <= 2_000 else { throw ComposerValidationError.tooLong }
        guard images.count <= 4 else { throw ComposerValidationError.tooManyImages }

        if let sessionToken {
            var mediaIDs: [UUID] = []
            for data in images {
                guard let image = UIImage(data: data) else { throw ImageSanitizerError.unreadable }
                let uploaded = try await apiClient.uploadImage(
                    data,
                    width: Int(image.size.width * image.scale),
                    height: Int(image.size.height * image.scale),
                    token: sessionToken
                )
                mediaIDs.append(uploaded.id)
            }
            let sharedVisibility: VeilShared.PostVisibility = identity == .profile ? .attributed : .anonymous
            let sharedMode = VeilShared.AnonymousPresentationMode(rawValue: anonymousMode.rawValue)
            let topicID = topic.flatMap { UUID(uuidString: $0.id) }
            let response = try await apiClient.createPost(
                VeilShared.PostCreateRequest(
                    visibility: sharedVisibility,
                    anonymousMode: sharedVisibility == .anonymous ? sharedMode : nil,
                    customAlias: anonymousMode == .customAlias ? customAlias : nil,
                    body: normalizedBody,
                    topicID: topicID,
                    mediaIDs: mediaIDs,
                    expiration: VeilShared.ExpirationPreset(rawValue: expiration.rawValue) ?? .never,
                    isSensitive: isSensitive,
                    collaboratorProfileIDs: collaboratorProfileIDs,
                    referenceKind: referenceKind,
                    referencedPostID: referencedPostID
                ),
                token: sessionToken
            )
            if let post = response.post {
                let local = post.localPost(apiBaseURL: apiClient.baseURL)
                posts.insert(local, at: 0)
                if local.actor.isAnonymous { veiledPosts.insert(local, at: 0) }
                else { currentProfilePosts.insert(local, at: 0) }
            }
            return response.postID
        }

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
        sessionToken == nil ? posts.filter { $0.isMine && $0.actor.isAnonymous } : veiledPosts
    }

    func loadComments(for postID: UUID) async {
        guard let sessionToken else { return }
        do {
            comments[postID] = try await apiClient.comments(postID: postID, token: sessionToken).items.map(\.localComment)
        } catch { backendError = error.localizedDescription }
    }

    func deletePost(_ postID: UUID) async {
        guard let sessionToken else {
            posts.removeAll { $0.id == postID }
            return
        }
        do {
            try await apiClient.deletePost(id: postID, token: sessionToken)
            posts.removeAll { $0.id == postID }
            veiledPosts.removeAll { $0.id == postID }
            currentProfilePosts.removeAll { $0.id == postID }
        } catch { backendError = error.localizedDescription }
    }

    func editPost(_ postID: UUID, body: String) async {
        guard let sessionToken else { return }
        do {
            let existing = posts.first(where: { $0.id == postID })
            let updated = try await apiClient.editPost(
                id: postID,
                body: VeilShared.PostEditRequest(
                    body: body,
                    topicID: existing?.topic.flatMap { UUID(uuidString: $0.id) },
                    isSensitive: existing?.isSensitive ?? false
                ),
                token: sessionToken
            ).localPost(apiBaseURL: apiClient.baseURL)
            if let index = posts.firstIndex(where: { $0.id == postID }) { posts[index] = updated }
            if let index = currentProfilePosts.firstIndex(where: { $0.id == postID }) { currentProfilePosts[index] = updated }
        } catch { backendError = error.localizedDescription }
    }

    func reshare(_ postID: UUID, quote: String?) async {
        do {
            _ = try await createPost(
                body: quote ?? "",
                identity: .profile,
                anonymousMode: .generatedAlias,
                generatedAlias: "",
                customAlias: "",
                sigilSeed: 0,
                profileHandle: "",
                topic: nil,
                expiration: .never,
                isSensitive: false,
                images: [],
                referenceKind: quote == nil ? .repost : .quote,
                referencedPostID: postID
            )
        } catch { backendError = error.localizedDescription }
    }

    func report(_ postID: UUID, category: VeilShared.ReportCategory = .malwareOrSpam) async {
        guard let sessionToken else { return }
        do { _ = try await apiClient.report(contentID: postID, category: category, explanation: nil, token: sessionToken) }
        catch { backendError = error.localizedDescription }
    }

    func savePreferences(
        mutedKeywords: Set<String>,
        blurSensitiveMedia: Bool,
        anonymousRequestPolicy: VeilShared.AnonymousRequestPolicy
    ) async {
        guard let sessionToken else { return }
        do {
            let value = VeilShared.ContentPreferences(
                mutedTopicIDs: Set(mutedTopicIDs.compactMap(UUID.init(uuidString:))),
                mutedKeywords: mutedKeywords,
                blurSensitiveMedia: blurSensitiveMedia,
                anonymousRequestPolicy: anonymousRequestPolicy
            )
            _ = try await apiClient.updatePreferences(value, token: sessionToken)
        } catch { backendError = error.localizedDescription }
    }

    func acceptCollaboration(_ invitation: VeilShared.CollaborationInvitation) async {
        guard let sessionToken, let currentProfileID else { return }
        do {
            try await apiClient.acceptCollaboration(
                postID: invitation.postID,
                profileID: currentProfileID,
                token: sessionToken
            )
            collaborationInvitations.removeAll { $0.id == invitation.id }
            await refresh(feed: .discover)
        } catch { backendError = error.localizedDescription }
    }

    func updateBio(_ bio: String) async {
        let normalized = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count <= 300, let sessionToken else { return }
        do { currentProfile = try await apiClient.updateProfile(.init(bio: normalized), token: sessionToken) }
        catch { backendError = error.localizedDescription }
    }

    func profileDetails(id: UUID) async -> (VeilShared.Profile, [DemoPost])? {
        do {
            async let profile = apiClient.profile(id: id, token: sessionToken)
            async let posts = apiClient.profilePosts(profileID: id, token: sessionToken)
            let (profileValue, page) = try await (profile, posts)
            return (profileValue, page.items.map { $0.localPost(apiBaseURL: apiClient.baseURL) })
        } catch {
            backendError = error.localizedDescription
            return nil
        }
    }

    func setFollowing(_ profile: VeilShared.Profile, following: Bool) async -> VeilShared.Profile? {
        guard let sessionToken else { return nil }
        do {
            try await apiClient.setFollowing(profileID: profile.id, following: following, token: sessionToken)
            let updated = try await apiClient.profile(id: profile.id, token: sessionToken)
            if let index = searchProfiles.firstIndex(where: { $0.id == updated.id }) { searchProfiles[index] = updated }
            if let ownID = currentProfileID { currentProfile = try await apiClient.profile(id: ownID, token: sessionToken) }
            return updated
        } catch {
            backendError = error.localizedDescription
            return nil
        }
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
