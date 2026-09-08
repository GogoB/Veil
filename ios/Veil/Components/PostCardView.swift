import SwiftUI
import UIKit
import VeilShared

struct PostCardView: View {
    let post: DemoPost
    var showDivider: Bool = true

    @EnvironmentObject private var store: DemoSocialStore
    @EnvironmentObject private var appearance: AppearanceStore
    @EnvironmentObject private var messagingStore: MessagingStore
    @State private var revealsSensitiveMedia = false
    @State private var showsEdit = false
    @State private var showsQuote = false
    @State private var showsMessageAuthor = false
    @State private var showsDeleteConfirmation = false
    @State private var editText = ""
    @State private var quoteText = ""
    @State private var firstMessage = ""
    @State private var reportCategory: VeilShared.ReportCategory?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 11) {
                    ActorBadge(actor: post.actor)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            if let name = post.actor.displayName {
                                Text(name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                            }
                            if post.actor.isAnonymous {
                                Text("VEILED")
                                    .font(.veilLabel(size: 8))
                                    .tracking(0.7)
                                    .foregroundStyle(appearance.accentColor)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.veilRaised, in: RoundedRectangle(cornerRadius: 4))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.veilLine, lineWidth: 0.5)
                                    }
                            }
                        }
                        Text("\(post.actor.subtitle) · \(post.createdLabel)")
                            .font(.caption)
                            .foregroundStyle(Color.veilSecondary)
                    }
                    Spacer(minLength: 8)
                    Menu {
                        if post.isMine {
                            Button {
                                editText = post.body
                                showsEdit = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) { showsDeleteConfirmation = true } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } else {
                            Button { showsMessageAuthor = true } label: {
                                Label("Message author", systemImage: "bubble.left")
                            }
                        }
                        Button { Task { await store.reshare(post.id, quote: nil) } } label: {
                            Label("Repost", systemImage: "arrow.2.squarepath")
                        }
                        Button { showsQuote = true } label: {
                            Label("Quote post", systemImage: "quote.bubble")
                        }
                        Button {
                            withAnimation { store.hide(postID: post.id) }
                        } label: {
                            Label("Hide this post", systemImage: "eye.slash")
                        }
                        if let topic = post.topic {
                            Button {
                                withAnimation { store.mute(topic: topic) }
                            } label: {
                                Label("Mute \(topic.title)", systemImage: "speaker.slash")
                            }
                        }
                        Menu("Report", systemImage: "exclamationmark.bubble") {
                            ForEach(reportCategories, id: \.1) { category, title in
                                Button(title) { reportCategory = category }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(Color.veilSecondary)
                    .accessibilityLabel("More options")
                }

                if !post.body.isEmpty {
                    Text(post.body)
                        .font(.title3)
                        .fontWeight(.regular)
                        .tracking(-0.35)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if post.isEdited {
                    Text("EDITED")
                        .font(.veilLabel(size: 8))
                        .foregroundStyle(Color.veilSecondary)
                }

                if let referenceLabel = post.referenceLabel {
                    Label(referenceLabel, systemImage: "arrow.2.squarepath")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(referenceLabel == "Original unavailable" ? Color.orange : Color.veilSecondary)
                }

                if !post.collaboratorHandles.isEmpty {
                    Text("With " + post.collaboratorHandles.map { "@\($0)" }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(Color.veilSecondary)
                }

                ForEach(post.media) { media in
                    mediaView(media)
                }

                if let topic = post.topic {
                    Text("#  \(topic.title)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(appearance.accentColor)
                        .accessibilityLabel("Topic: \(topic.title)")
                }

                HStack(spacing: 24) {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { store.toggleLike(postID: post.id) }
                    } label: {
                        Label("\(post.likeCount)", systemImage: post.isLiked ? "heart.fill" : "heart")
                    }
                    .foregroundStyle(post.isLiked ? appearance.accentColor : Color.veilSecondary)
                    .accessibilityLabel(post.isLiked ? "Unlike, \(post.likeCount) likes" : "Like, \(post.likeCount) likes")

                    NavigationLink {
                        PostDetailView(postID: post.id)
                    } label: {
                        Label("\(post.commentCount)", systemImage: "bubble.left")
                    }
                    .accessibilityLabel("\(post.commentCount) comments")

                    if let expiration = post.expiration.shortLabel {
                        Label(expiration, systemImage: "clock")
                            .font(.veilLabel(size: 9))
                            .accessibilityLabel("Expires in \(expiration.replacingOccurrences(of: " left", with: ""))")
                    }

                    Spacer(minLength: 0)

                    ShareLink(item: post.body) {
                        Image(systemName: "arrow.up.right")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Share post")
                }
                .font(.caption)
                .foregroundStyle(Color.veilSecondary)
                .labelStyle(.titleAndIcon)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)

            if showDivider { VeilDivider() }
        }
        .sheet(isPresented: $showsEdit) {
            PostTextSheet(title: "Edit post", actionTitle: "Save", text: $editText) {
                Task { await store.editPost(post.id, body: editText) }
            }
        }
        .sheet(isPresented: $showsQuote) {
            PostTextSheet(title: "Quote post", actionTitle: "Post", text: $quoteText) {
                Task { await store.reshare(post.id, quote: quoteText) }
            }
        }
        .sheet(isPresented: $showsMessageAuthor) {
            PostTextSheet(title: "Message author", actionTitle: "Send", text: $firstMessage) {
                Task {
                    _ = await messagingStore.startConversation(
                        targetProfileID: post.actorProfileID,
                        sourcePostID: post.actor.isAnonymous ? post.id : nil,
                        anonymous: post.actor.isAnonymous,
                        initialText: firstMessage
                    )
                }
            }
        }
        .alert("Delete this post?", isPresented: $showsDeleteConfirmation) {
            Button("Delete", role: .destructive) { Task { await store.deletePost(post.id) } }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the post. Reported content may remain in restricted quarantine for review.")
        }
        .confirmationDialog(
            "Report this post?",
            isPresented: Binding(get: { reportCategory != nil }, set: { if !$0 { reportCategory = nil } }),
            titleVisibility: .visible
        ) {
            Button("Send report", role: .destructive) {
                guard let category = reportCategory else { return }
                Task { await store.report(post.id, category: category) }
                reportCategory = nil
            }
            Button("Cancel", role: .cancel) { reportCategory = nil }
        } message: {
            Text("The report sends the content ID and category. Avoid adding personal information.")
        }
    }

    private var reportCategories: [(VeilShared.ReportCategory, String)] {
        [
            (.illegalMaterial, "Illegal material"),
            (.childSexualAbuseMaterial, "Child sexual abuse material"),
            (.credibleThreat, "Credible threat"),
            (.criminalSolicitation, "Criminal solicitation"),
            (.malwareOrSpam, "Malware or spam"),
            (.privateInformation, "Private information")
        ]
    }

    @ViewBuilder
    private func mediaView(_ media: PostMedia) -> some View {
        ZStack {
            Group {
                switch media {
                case .architecture:
                    ArchitectureArtwork()
                case let .image(_, data):
                    if let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.veilRaised
                            .overlay { Image(systemName: "photo").foregroundStyle(Color.veilSecondary) }
                    }
                case let .remote(_, url):
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else if phase.error != nil {
                            Color.veilRaised.overlay { Image(systemName: "exclamationmark.triangle") }
                        } else {
                            Color.veilRaised.overlay { ProgressView() }
                        }
                    }
                }
            }
            .frame(height: 210)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .blur(radius: post.isSensitive && !revealsSensitiveMedia ? 18 : 0)
            .scaleEffect(post.isSensitive && !revealsSensitiveMedia ? 1.08 : 1)
            .clipped()

            if post.isSensitive && !revealsSensitiveMedia {
                Button("Sensitive content · Show") {
                    withAnimation { revealsSensitiveMedia = true }
                }
                .font(.subheadline.weight(.medium))
                .buttonStyle(.borderedProminent)
                .tint(Color.black.opacity(0.76))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct PostTextSheet: View {
    let title: String
    let actionTitle: String
    @Binding var text: String
    let action: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .font(.title3)
                .padding()
                .scrollContentBackground(.hidden)
                .background(Color.veilBackground)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(actionTitle) {
                            action()
                            dismiss()
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 2_000)
                    }
                }
        }
    }
}
