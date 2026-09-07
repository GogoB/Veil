import SwiftUI
import UIKit

struct PostCardView: View {
    let post: DemoPost
    var showDivider: Bool = true

    @EnvironmentObject private var store: DemoSocialStore
    @EnvironmentObject private var appearance: AppearanceStore
    @State private var revealsSensitiveMedia = false

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
                        Button { } label: {
                            Label("Report", systemImage: "exclamationmark.bubble")
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
