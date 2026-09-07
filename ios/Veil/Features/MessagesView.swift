import SwiftUI

struct MessagesView: View {
    @StateObject private var provider = DemoMessagingProvider()

    private var requests: [DemoConversation] { provider.conversations.filter(\.isRequest) }
    private var conversations: [DemoConversation] { provider.conversations.filter { !$0.isRequest } }

    var body: some View {
        NavigationStack {
            List {
                if !requests.isEmpty {
                    Section("Requests") {
                        ForEach(requests) { conversation in
                            requestRow(conversation)
                        }
                    }
                }
                Section("Conversations") {
                    ForEach(conversations) { conversation in
                        NavigationLink {
                            ConversationView(conversation: conversation, provider: provider)
                        } label: {
                            conversationRow(conversation)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.veilBackground)
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink { PrivacySettingsView() } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("Message settings")
                }
            }
        }
    }

    private func requestRow(_ conversation: DemoConversation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            conversationRow(conversation)
            Text("One text-only request. Images and links stay unavailable until you accept.")
                .font(.caption)
                .foregroundStyle(Color.veilSecondary)
            HStack {
                Button("Accept") { provider.acceptRequest(conversationID: conversation.id) }
                    .buttonStyle(.borderedProminent)
                Button("Block", role: .destructive) { provider.block(conversationID: conversation.id) }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 6)
    }

    private func conversationRow(_ conversation: DemoConversation) -> some View {
        HStack(spacing: 12) {
            ActorBadge(actor: conversation.actor, size: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.actor.displayName ?? "Anonymous")
                    .font(.subheadline.weight(.semibold))
                Text(conversation.preview)
                    .font(.subheadline)
                    .foregroundStyle(Color.veilSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(conversation.time).font(.caption).foregroundStyle(Color.veilSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ConversationView: View {
    let conversation: DemoConversation
    @ObservedObject var provider: DemoMessagingProvider
    @State private var draft = ""

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(provider.messages(in: conversation.id)) { message in
                    HStack {
                        if message.isMine { Spacer(minLength: 50) }
                        VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                            Text(message.text)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .background(message.isMine ? Color.accentColor.opacity(0.2) : Color.veilRaised, in: RoundedRectangle(cornerRadius: 14))
                            Text(message.createdLabel).font(.caption2).foregroundStyle(Color.veilSecondary)
                        }
                        if !message.isMine { Spacer(minLength: 50) }
                    }
                    .id(message.id)
                }
            }
            .padding()
        }
        .background(Color.veilBackground)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color.veilRaised, in: RoundedRectangle(cornerRadius: 12))
                Button {
                    provider.sendText(draft, in: conversation.id)
                    draft = ""
                } label: {
                    Image(systemName: "arrow.up.right")
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Color.veilBackground)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .navigationTitle(conversation.actor.displayName ?? "Anonymous")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        provider.block(conversationID: conversation.id)
                    } label: {
                        Label("Block", systemImage: "hand.raised")
                    }
                    Button { } label: {
                        Label("Report selected messages", systemImage: "exclamationmark.bubble")
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
    }
}
