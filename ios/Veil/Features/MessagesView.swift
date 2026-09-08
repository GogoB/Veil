import PhotosUI
import SwiftUI
import UIKit
import VeilShared

struct MessagesView: View {
    @EnvironmentObject private var provider: MessagingStore
    @EnvironmentObject private var appFlow: AppFlowStore

    var body: some View {
        NavigationStack {
            List {
                if !provider.requests.isEmpty {
                    Section("Requests") {
                        ForEach(provider.requests) { conversation in
                            requestRow(conversation)
                        }
                    }
                }
                if !provider.pendingConversations.isEmpty {
                    Section("Waiting for acceptance") {
                        ForEach(provider.pendingConversations) { conversation in
                            NavigationLink {
                                ConversationView(conversation: conversation)
                            } label: {
                                conversationRow(conversation)
                            }
                        }
                    }
                }
                Section("Conversations") {
                    if provider.acceptedConversations.isEmpty && !provider.isLoading {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.title2)
                            Text("No conversations yet").font(.headline)
                            Text("Message a public profile or an anonymous post author.")
                                .font(.caption)
                                .foregroundStyle(Color.veilSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .listRowBackground(Color.clear)
                    }
                    ForEach(provider.acceptedConversations) { conversation in
                        NavigationLink {
                            ConversationView(conversation: conversation)
                        } label: {
                            conversationRow(conversation)
                        }
                    }
                }
            }
            .overlay { if provider.isLoading { ProgressView("Opening encrypted inbox…") } }
            .refreshable { try? await provider.refresh() }
            .scrollContentBackground(.hidden)
            .background(Color.veilBackground)
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink { PrivacySettingsView() } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("Message settings")
                }
            }
            .alert("Inbox unavailable", isPresented: Binding(
                get: { provider.errorMessage != nil },
                set: { if !$0 { provider.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { provider.errorMessage = nil }
            } message: {
                Text(provider.errorMessage ?? "Try again.")
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
                Button("Accept") { Task { await provider.acceptRequest(conversationID: conversation.id) } }
                    .buttonStyle(.borderedProminent)
                Button("Block", role: .destructive) { Task { await provider.block(conversationID: conversation.id) } }
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
    @EnvironmentObject private var provider: MessagingStore
    @State private var draft = ""
    @State private var selectedEventIDs: Set<String> = []
    @State private var reportCategory: VeilShared.ReportCategory?
    @State private var showsSettings = false
    @State private var selectedImage: PhotosPickerItem?
    @State private var isSendingImage = false

    private var messages: [ConversationMessage] { provider.messages(in: conversation.id) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                encryptedNotice
                if !conversation.isAccepted {
                    Text("Your first text was sent. You can continue after the recipient accepts.")
                        .font(.caption)
                        .foregroundStyle(Color.veilSecondary)
                        .padding(12)
                        .background(Color.veilRaised, in: RoundedRectangle(cornerRadius: 10))
                }
                ForEach(messages) { message in
                    messageRow(message)
                }
            }
            .padding()
        }
        .background(Color.veilBackground)
        .safeAreaInset(edge: .bottom) { composer }
        .navigationTitle(conversation.actor.displayName ?? "Anonymous")
        .navigationBarTitleDisplayMode(.inline)
        .task { try? await provider.open(conversationID: conversation.id) }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if !selectedEventIDs.isEmpty {
                    Menu {
                        ForEach(reportCategories, id: \.1) { category, title in
                            Button(title) { reportCategory = category }
                        }
                    } label: {
                        Label("Report selected", systemImage: "exclamationmark.bubble")
                    }
                }
                Menu {
                    Button { showsSettings = true } label: {
                        Label("Conversation settings", systemImage: "timer")
                    }
                    Button(role: .destructive) {
                        Task { await provider.block(conversationID: conversation.id) }
                    } label: {
                        Label("Block", systemImage: "hand.raised")
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showsSettings) {
            ConversationSettingsView(conversationID: conversation.id)
        }
        .confirmationDialog(
            "Send only the selected decrypted messages with this report?",
            isPresented: Binding(get: { reportCategory != nil }, set: { if !$0 { reportCategory = nil } }),
            titleVisibility: .visible
        ) {
            Button("Send selected messages", role: .destructive) {
                guard let category = reportCategory else { return }
                let selected = messages.filter { selectedEventIDs.contains($0.encryptedEventID) }
                Task { await provider.report(selected, conversationID: conversation.id, category: category) }
                selectedEventIDs.removeAll()
                reportCategory = nil
            }
            Button("Cancel", role: .cancel) { reportCategory = nil }
        } message: {
            Text("Other messages stay encrypted and are not attached. Avoid adding unnecessary personal information.")
        }
    }

    private var encryptedNotice: some View {
        Label("End-to-end encrypted · no online status", systemImage: "lock")
            .font(.caption)
            .foregroundStyle(Color.veilSecondary)
            .padding(.vertical, 8)
    }

    private func messageRow(_ message: ConversationMessage) -> some View {
        HStack {
            if message.isMine { Spacer(minLength: 50) }
            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(message.isMine ? Color.accentColor.opacity(0.2) : Color.veilRaised, in: RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        if selectedEventIDs.contains(message.encryptedEventID) {
                            RoundedRectangle(cornerRadius: 14).stroke(Color.accentColor, lineWidth: 2)
                        }
                    }
                Text(message.createdLabel).font(.caption2).foregroundStyle(Color.veilSecondary)
            }
            if !message.isMine { Spacer(minLength: 50) }
        }
        .contentShape(Rectangle())
        .onLongPressGesture {
            guard !message.isMine else { return }
            if selectedEventIDs.contains(message.encryptedEventID) {
                selectedEventIDs.remove(message.encryptedEventID)
            } else {
                selectedEventIDs.insert(message.encryptedEventID)
            }
        }
        .contextMenu {
            if message.isMine {
                Button(role: .destructive) {
                    Task { await provider.deleteForAll(message, conversationID: conversation.id) }
                } label: {
                    Label("Delete for everyone", systemImage: "trash")
                }
            } else {
                Button {
                    selectedEventIDs.insert(message.encryptedEventID)
                } label: {
                    Label("Select for report", systemImage: "checkmark.circle")
                }
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $selectedImage, matching: .images) {
                Image(systemName: isSendingImage ? "hourglass" : "photo")
                    .frame(width: 36, height: 44)
            }
            .disabled(!conversation.isAccepted || isSendingImage)
            .accessibilityLabel("Send encrypted image")
            .onChange(of: selectedImage) { item in
                guard let item else { return }
                isSendingImage = true
                Task {
                    defer {
                        selectedImage = nil
                        isSendingImage = false
                    }
                    do {
                        guard let source = try await item.loadTransferable(type: Data.self) else {
                            throw ImageSanitizerError.unreadable
                        }
                        let data = try ImageSanitizer.sanitizedUploadData(from: source)
                        guard let image = UIImage(data: data) else { throw ImageSanitizerError.unreadable }
                        await provider.sendImage(
                            data,
                            width: Int(image.size.width * image.scale),
                            height: Int(image.size.height * image.scale),
                            in: conversation.id
                        )
                    } catch { provider.errorMessage = error.localizedDescription }
                }
            }
            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.veilRaised, in: RoundedRectangle(cornerRadius: 12))
            Button {
                let value = draft
                draft = ""
                Task { await provider.sendText(value, in: conversation.id) }
            } label: {
                Image(systemName: "arrow.up.right")
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Color.veilBackground)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .disabled(!conversation.isAccepted && !messages.isEmpty)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
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
}

private struct ConversationSettingsView: View {
    let conversationID: UUID
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var provider: MessagingStore
    @State private var timer = 0
    @State private var receipts = false
    @State private var typing = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Disappearing messages") {
                    Picker("Delete after", selection: $timer) {
                        Text("Off").tag(0)
                        Text("5 minutes").tag(300)
                        Text("1 hour").tag(3_600)
                        Text("24 hours").tag(86_400)
                        Text("7 days").tag(604_800)
                    }
                    Text("Deletion is best effort. Screenshots and copies cannot be erased remotely.")
                        .font(.caption)
                        .foregroundStyle(Color.veilSecondary)
                }
                Section("Presence") {
                    Toggle("Read receipts", isOn: $receipts)
                    Toggle("Typing indicators", isOn: $typing)
                }
            }
            .navigationTitle("Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                let settings = provider.settings(in: conversationID)
                timer = settings.disappearingSeconds ?? 0
                receipts = settings.readReceiptsEnabled
                typing = settings.typingIndicatorsEnabled
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await provider.updateSettings(
                                conversationID: conversationID,
                                disappearingSeconds: timer == 0 ? nil : timer,
                                receipts: receipts,
                                typing: typing
                            )
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
