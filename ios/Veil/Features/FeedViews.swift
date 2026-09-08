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
                        if let error = store.backendError {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(Color.red)
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                        }
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
            .refreshable { await store.refresh(feed: feedKind) }
            .background(Color.veilBackground)
            .task { await store.refresh(feed: feedKind) }
            .onChange(of: feedKind) { newValue in
                Task { await store.refresh(feed: newValue) }
            }
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
    @State private var replyIdentity: PostIdentityChoice = .anonymous
    @State private var replyParentID: UUID?
    @State private var hasCommented = false
    @State private var editingComment: DemoComment?
    @State private var editingBody = ""
    @State private var commentPendingDeletion: DemoComment?

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
                                Text(comment.body)
                                    .font(.body)
                                    .lineSpacing(3)
                                    .foregroundStyle(comment.isDeleted ? Color.veilSecondary : Color.primary)
                                HStack(spacing: 14) {
                                    if comment.isEdited {
                                        Text("EDITED").font(.veilLabel(size: 8))
                                    }
                                    if !comment.isDeleted {
                                        Button("Reply") {
                                            replyParentID = comment.rootID ?? comment.id
                                        }
                                        .font(.caption)
                                        Button {
                                            store.toggleCommentLike(comment.id, in: postID)
                                        } label: {
                                            Label("\(comment.likeCount)", systemImage: comment.isLiked ? "heart.fill" : "heart")
                                        }
                                        .font(.caption)
                                        .foregroundStyle(comment.isLiked ? Color.accentColor : Color.veilSecondary)
                                    }
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(20)
                        .padding(.leading, comment.parentID == nil ? 0 : 28)
                        .contextMenu {
                            if comment.isMine && !comment.isDeleted {
                                Button {
                                    editingBody = comment.body
                                    editingComment = comment
                                } label: {
                                    Label("Edit comment", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    commentPendingDeletion = comment
                                } label: {
                                    Label("Delete comment", systemImage: "trash")
                                }
                            }
                        }
                        VeilDivider()
                    }
                }
            }
        }
        .background(Color.veilBackground)
        .task {
            await store.loadComments(for: postID)
            if let ownComment = store.comments(for: postID).first(where: \.isMine) {
                hasCommented = true
                replyIdentity = ownComment.actor.isAnonymous ? .anonymous : .profile
            }
        }
        .navigationTitle("Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                if replyParentID != nil {
                    HStack {
                        Text("Replying in thread").font(.caption).foregroundStyle(Color.veilSecondary)
                        Spacer()
                        Button("Cancel") { replyParentID = nil }.font(.caption)
                    }
                }
                HStack(spacing: 10) {
                    Menu {
                        Button("Anonymous") { replyIdentity = .anonymous }
                        Button("Public profile") { replyIdentity = .profile }
                    } label: {
                        Image(systemName: replyIdentity == .anonymous ? "hexagon" : "person.crop.circle")
                            .frame(width: 36, height: 44)
                    }
                    .disabled(hasCommented)
                    .accessibilityLabel("Reply as \(replyIdentity.title)")
                    TextField("Add a thought…", text: $reply, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Color.veilRaised, in: RoundedRectangle(cornerRadius: 12))
                    Button {
                        store.addComment(reply, to: postID, parentID: replyParentID, identity: replyIdentity)
                        reply = ""
                        replyParentID = nil
                        hasCommented = true
                    } label: {
                        Image(systemName: "arrow.up.right")
                            .frame(width: 44, height: 44)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(Color.veilBackground)
                    }
                    .disabled(reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Post reply")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .sheet(item: $editingComment) { comment in
            CommentEditSheet(text: $editingBody) {
                Task { await store.editComment(comment.id, in: postID, body: editingBody) }
            }
        }
        .confirmationDialog(
            "Delete this comment?",
            isPresented: Binding(
                get: { commentPendingDeletion != nil },
                set: { if !$0 { commentPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let comment = commentPendingDeletion else { return }
                Task { await store.deleteComment(comment.id, in: postID) }
                commentPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { commentPendingDeletion = nil }
        } message: {
            Text("Comments with replies become a tombstone so the thread still makes sense.")
        }
    }
}

private struct CommentEditSheet: View {
    @Binding var text: String
    let save: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding()
                .scrollContentBackground(.hidden)
                .background(Color.veilBackground)
                .navigationTitle("Edit comment")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            save()
                            dismiss()
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 2_000)
                    }
                }
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
