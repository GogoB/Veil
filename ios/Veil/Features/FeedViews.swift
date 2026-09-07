import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var store: DemoSocialStore
    @EnvironmentObject private var appearance: AppearanceStore
    @State private var feedKind: FeedKind = .discover
    @State private var selectedTopic: Topic?
    @State private var showsControls = false

    private var posts: [DemoPost] {
        store.visiblePosts(in: feedKind, topic: selectedTopic)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        topicStrip
                        if posts.isEmpty {
                            VStack(spacing: 14) {
                                Image(systemName: "waveform.path")
                                    .font(.largeTitle)
                                    .foregroundStyle(appearance.accentColor)
                                Text("A little quiet here")
                                    .font(.title3.weight(.semibold))
                                Text("Try another topic or switch to Discover.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.veilSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 70)
                        } else {
                            ForEach(posts) { post in
                                PostCardView(post: post)
                            }
                        }
                    } header: {
                        feedHeader
                            .background(.ultraThinMaterial)
                    }
                }
            }
            .background(Color.veilBackground)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { VeilWordmark() }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showsControls = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Feed controls")
                }
            }
            .sheet(isPresented: $showsControls) {
                FeedControlsView()
                    .presentationDetents([.medium])
            }
        }
    }

    private var feedHeader: some View {
        HStack(spacing: 26) {
            ForEach(FeedKind.allCases) { kind in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { feedKind = kind }
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Text(kind.title)
                            if kind == .discover {
                                Circle().fill(appearance.accentColor).frame(width: 5, height: 5)
                            }
                        }
                        .font(.title2.weight(feedKind == kind ? .semibold : .regular))
                        .foregroundStyle(feedKind == kind ? Color.primary : Color.veilSecondary)
                        Rectangle()
                            .fill(feedKind == kind ? appearance.accentColor : Color.clear)
                            .frame(width: 28, height: 2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(feedKind == kind ? .isSelected : [])
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.title3)
                .foregroundStyle(appearance.accentColor)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var topicStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                topicButton(title: "For you", topic: nil)
                ForEach(store.topics) { topic in
                    topicButton(title: topic.title, topic: topic)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func topicButton(title: String, topic: Topic?) -> some View {
        let selected = selectedTopic == topic
        return Button(title) {
            withAnimation(.easeOut(duration: 0.16)) { selectedTopic = topic }
        }
        .font(.caption.weight(selected ? .semibold : .regular))
        .foregroundStyle(selected ? Color.veilBackground : Color.veilSecondary)
        .padding(.horizontal, 13)
        .frame(minHeight: 38)
        .background(selected ? appearance.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).stroke(selected ? .clear : Color.veilLine, lineWidth: 1)
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct PostDetailView: View {
    let postID: UUID
    @EnvironmentObject private var store: DemoSocialStore
    @State private var reply = ""

    private var post: DemoPost? { store.posts.first(where: { $0.id == postID }) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let post {
                    PostCardView(post: post)
                    ForEach(store.comments(for: postID)) { comment in
                        HStack(alignment: .top, spacing: 12) {
                            ActorBadge(actor: comment.actor, size: 34)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 7) {
                                    if let name = comment.actor.displayName { Text(name).font(.subheadline.weight(.semibold)) }
                                    if case let .anonymous(_, _, role) = comment.actor, role == .originalPoster {
                                        Text("OP").font(.veilLabel(size: 8)).foregroundStyle(Color.accentColor)
                                    }
                                    Text(comment.createdLabel).font(.caption).foregroundStyle(Color.veilSecondary)
                                }
                                Text(comment.body).font(.body).lineSpacing(3)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(20)
                        VeilDivider()
                    }
                }
            }
        }
        .background(Color.veilBackground)
        .navigationTitle("Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                TextField("Add a thought…", text: $reply, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color.veilRaised, in: RoundedRectangle(cornerRadius: 12))
                Button {
                    store.addComment(reply, to: postID)
                    reply = ""
                } label: {
                    Image(systemName: "arrow.up.right")
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Color.veilBackground)
                }
                .disabled(reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Post reply")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }
}

struct FeedControlsView: View {
    @EnvironmentObject private var store: DemoSocialStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Personal filters") {
                    if store.mutedTopicIDs.isEmpty && store.hiddenPostIDs.isEmpty {
                        Text("You haven’t hidden posts or muted topics in this demo.")
                            .foregroundStyle(Color.veilSecondary)
                    } else {
                        Label("\(store.mutedTopicIDs.count) muted topics", systemImage: "speaker.slash")
                        Label("\(store.hiddenPostIDs.count) hidden posts", systemImage: "eye.slash")
                        Button("Reset demo feed controls", role: .destructive) {
                            store.resetFeedControls()
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.veilBackground)
            .navigationTitle("Your feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
