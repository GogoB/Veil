import SwiftUI
import VeilShared

struct SearchView: View {
    @EnvironmentObject private var store: DemoSocialStore
    @EnvironmentObject private var appearance: AppearanceStore
    @State private var query = ""

    private var hasResults: Bool {
        !store.searchPosts.isEmpty || !store.searchProfiles.isEmpty || !store.searchTopics.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if query.isEmpty {
                        introduction
                    } else if store.isSearching {
                        ProgressView("Searching public posts…")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 70)
                    } else if !hasResults {
                        emptyState
                    } else {
                        if !store.searchProfiles.isEmpty {
                            resultHeading("Profiles")
                            ForEach(store.searchProfiles) { profile in
                                NavigationLink {
                                    RemoteProfileView(initialProfile: profile)
                                } label: {
                                    profileRow(profile)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if !store.searchTopics.isEmpty {
                            resultHeading("Topics")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(store.searchTopics) { topic in
                                        Label(topic.title, systemImage: "number")
                                            .font(.subheadline.weight(.medium))
                                            .padding(.horizontal, 14)
                                            .frame(minHeight: 40)
                                            .background(Color.veilRaised, in: RoundedRectangle(cornerRadius: 9))
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.bottom, 12)
                        }
                        if !store.searchPosts.isEmpty {
                            resultHeading("Public posts")
                            ForEach(store.searchPosts) { post in PostCardView(post: post) }
                        }
                    }
                }
            }
            .background(Color.veilBackground)
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Topics, posts, profiles")
            .task(id: query) {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else { return }
                await store.performSearch(query)
            }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 18) {
            VeilSectionLabel(text: "Public discovery")
            Text("Find a topic, a thought,\nor a public profile.")
                .font(.system(size: 34, weight: .medium))
                .tracking(-1.2)
            Text("Anonymous aliases and sigils never appear in search results.")
                .font(.callout)
                .foregroundStyle(Color.veilSecondary)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(appearance.accentColor)
            Text("Nothing public found").font(.headline)
            Text("Try a topic, post text, or public handle.")
                .font(.subheadline)
                .foregroundStyle(Color.veilSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
    }

    private func resultHeading(_ title: String) -> some View {
        VeilSectionLabel(text: title)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
    }

    private func profileRow(_ profile: VeilShared.Profile) -> some View {
        HStack(spacing: 12) {
            ActorBadge(actor: .profile(handle: profile.username, displayName: profile.username), size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(profile.username).font(.subheadline.weight(.semibold))
                Text("\(profile.followerCount) followers")
                    .font(.caption)
                    .foregroundStyle(Color.veilSecondary)
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundStyle(appearance.accentColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

private struct RemoteProfileView: View {
    @EnvironmentObject private var store: DemoSocialStore
    @EnvironmentObject private var messaging: MessagingStore
    @State private var profile: VeilShared.Profile
    @State private var posts: [DemoPost] = []
    @State private var showsMessageComposer = false

    init(initialProfile: VeilShared.Profile) {
        _profile = State(initialValue: initialProfile)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 15) {
                    ActorBadge(actor: .profile(handle: profile.username, displayName: profile.username), size: 68)
                    Text(profile.username).font(.title.bold())
                    if let bio = profile.bio { Text(bio).foregroundStyle(Color.veilSecondary) }
                    HStack(spacing: 22) {
                        Text("\(profile.followerCount) followers")
                        Text("\(profile.followingCount) following")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.veilSecondary)
                    if store.currentProfile?.id == profile.id {
                        Label("Your public profile", systemImage: "person.crop.circle.badge.checkmark")
                            .font(.subheadline)
                            .foregroundStyle(Color.veilSecondary)
                    } else {
                        HStack {
                            Button(profile.isFollowedByMe ? "Following" : "Follow") {
                                Task {
                                    if let updated = await store.setFollowing(profile, following: !profile.isFollowedByMe) {
                                        profile = updated
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Message") { showsMessageComposer = true }
                                .buttonStyle(.bordered)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                VeilDivider()
                if posts.isEmpty {
                    Text("No public posts yet.")
                        .foregroundStyle(Color.veilSecondary)
                        .padding(32)
                } else {
                    ForEach(posts) { post in PostCardView(post: post) }
                }
            }
        }
        .background(Color.veilBackground)
        .navigationTitle("@\(profile.username)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let details = await store.profileDetails(id: profile.id) {
                profile = details.0
                posts = details.1
            }
        }
        .sheet(isPresented: $showsMessageComposer) {
            ProfileMessageSheet(profile: profile, isPresented: $showsMessageComposer)
                .environmentObject(messaging)
        }
    }
}

private struct ProfileMessageSheet: View {
    let profile: VeilShared.Profile
    @Binding var isPresented: Bool
    @EnvironmentObject private var messaging: MessagingStore
    @State private var text = ""
    @State private var identity: PostIdentityChoice = .profile

    var body: some View {
        NavigationStack {
            Form {
                Picker("Identity", selection: $identity) {
                    Text("Public profile").tag(PostIdentityChoice.profile)
                    Text("Hide my identity").tag(PostIdentityChoice.anonymous)
                }
                .pickerStyle(.segmented)
                TextField("First message", text: $text, axis: .vertical)
                    .lineLimit(3...8)
                Text("Anonymous conversations use a fresh conversation-only alias.")
                    .font(.caption)
                    .foregroundStyle(Color.veilSecondary)
            }
            .navigationTitle("Message @\(profile.username)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        let message = text
                        Task {
                            _ = await messaging.startConversation(
                                targetProfileID: profile.id,
                                sourcePostID: nil,
                                anonymous: identity == .anonymous,
                                initialText: message
                            )
                            isPresented = false
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 2_000)
                }
            }
        }
    }
}
