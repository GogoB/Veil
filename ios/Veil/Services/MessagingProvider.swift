import Foundation
import VeilShared

struct ConversationMessage: Identifiable, Equatable, Sendable {
    let id: String
    let encryptedEventID: String
    let text: String
    let isMine: Bool
    let sentAt: Date

    var createdLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: sentAt, relativeTo: Date())
    }
}

struct ConversationSettingsSnapshot: Sendable {
    let disappearingSeconds: Int?
    let readReceiptsEnabled: Bool
    let typingIndicatorsEnabled: Bool
}

/// Keeps Matrix symbols out of screens and view models. Server-owned request,
/// block, and timer metadata is coordinated by `MessagingStore`.
protocol MessagingProvider: Sendable {
    func configure(with configuration: VeilShared.MessagingSessionConfiguration) async throws
    func synchronize() async throws
    func observeMessages(
        in roomID: String,
        onUpdate: @escaping @Sendable ([MatrixDecryptedMessage]) -> Void
    ) async throws
    func sendText(_ text: String, to roomID: String) async throws -> String
    func sendImage(_ data: Data, mimeType: String, width: Int, height: Int, to roomID: String) async throws -> String
    func acceptRequest(in roomID: String) async throws
    func deleteForAll(eventID: String, in roomID: String) async throws
    func setDisappearingTimer(_ seconds: Int?, in roomID: String) async throws
    func block(roomID: String) async
    func exportOldDeviceKeys() async throws -> String
    func importTransferredKeys(_ recoveryKey: String) async throws
}

@MainActor
final class MessagingStore: ObservableObject {
    @Published private(set) var conversations: [DemoConversation] = []
    @Published private(set) var messagesByConversation: [UUID: [ConversationMessage]] = [:]
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: APIClient
    private let encryptedProvider: any MessagingProvider
    private var sessionToken: String?
    private var sharedConversations: [UUID: VeilShared.Conversation] = [:]
    private var roomIDs: [UUID: String] = [:]
    private var demoMode = true

    init(
        apiClient: APIClient = .init(),
        encryptedProvider: any MessagingProvider = MatrixMessagingProvider()
    ) {
        self.apiClient = apiClient
        self.encryptedProvider = encryptedProvider
        loadDemoContent()
    }

    var requests: [DemoConversation] { conversations.filter(\.isRequest) }
    var acceptedConversations: [DemoConversation] { conversations.filter(\.isAccepted) }
    var pendingConversations: [DemoConversation] { conversations.filter { !$0.isRequest && !$0.isAccepted } }

    func configure(token: String?, demoMode: Bool) async {
        self.demoMode = demoMode
        sessionToken = token
        errorMessage = nil
        guard !demoMode, let token else {
            loadDemoContent()
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let configuration = try await apiClient.messagingSession(token: token)
            try await encryptedProvider.configure(with: configuration)
            try await refresh()
        } catch {
            conversations = []
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async throws {
        guard let sessionToken else { return }
        let values = try await apiClient.conversations(token: sessionToken)
        sharedConversations = Dictionary(uniqueKeysWithValues: values.map { ($0.id, $0) })
        conversations = values.map(\.localConversation)
        for conversation in values { try await open(conversationID: conversation.id) }
    }

    func messages(in conversationID: UUID) -> [ConversationMessage] {
        messagesByConversation[conversationID] ?? []
    }

    func open(conversationID: UUID) async throws {
        guard !demoMode, let sessionToken else { return }
        if roomIDs[conversationID] != nil { return }
        let room = try await apiClient.messagingRoom(conversationID: conversationID, token: sessionToken)
        roomIDs[conversationID] = room.roomID
        try await encryptedProvider.observeMessages(in: room.roomID) { [weak self] decrypted in
            Task { @MainActor in
                self?.messagesByConversation[conversationID] = decrypted.map {
                    ConversationMessage(
                        id: $0.eventID,
                        encryptedEventID: $0.eventID,
                        text: $0.body,
                        isMine: $0.isMine,
                        sentAt: $0.sentAt
                    )
                }
            }
        }
    }

    func sendText(_ text: String, in conversationID: UUID) async {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 2_000 else { return }
        if conversations.first(where: { $0.id == conversationID })?.isAccepted == false,
           Self.containsLink(normalized) {
            errorMessage = "Links stay unavailable until the recipient accepts the request."
            return
        }
        if demoMode {
            messagesByConversation[conversationID, default: []].append(
                ConversationMessage(
                    id: UUID().uuidString,
                    encryptedEventID: "demo-\(UUID().uuidString)",
                    text: normalized,
                    isMine: true,
                    sentAt: Date()
                )
            )
            return
        }
        guard let sessionToken else { return }
        do {
            try await open(conversationID: conversationID)
            guard let roomID = roomIDs[conversationID] else { throw MatrixMessagingError.roomUnavailable }
            let eventID = try await encryptedProvider.sendText(normalized, to: roomID)
            let timer = sharedConversations[conversationID]?.disappearingSeconds
            _ = try await apiClient.registerEncryptedEvent(
                conversationID: conversationID,
                eventID: eventID,
                sentAt: Date(),
                disappearingSeconds: timer,
                containsLink: Self.containsLink(normalized),
                containsMedia: false,
                token: sessionToken
            )
        } catch { errorMessage = error.localizedDescription }
    }

    func sendImage(_ data: Data, width: Int, height: Int, in conversationID: UUID) async {
        guard conversations.first(where: { $0.id == conversationID })?.isAccepted == true else { return }
        if demoMode {
            messagesByConversation[conversationID, default: []].append(
                ConversationMessage(
                    id: UUID().uuidString,
                    encryptedEventID: "demo-\(UUID().uuidString)",
                    text: "Encrypted image",
                    isMine: true,
                    sentAt: Date()
                )
            )
            return
        }
        guard let sessionToken else { return }
        do {
            try await open(conversationID: conversationID)
            guard let roomID = roomIDs[conversationID] else { throw MatrixMessagingError.roomUnavailable }
            let eventID = try await encryptedProvider.sendImage(
                data,
                mimeType: "image/jpeg",
                width: width,
                height: height,
                to: roomID
            )
            _ = try await apiClient.registerEncryptedEvent(
                conversationID: conversationID,
                eventID: eventID,
                sentAt: Date(),
                disappearingSeconds: sharedConversations[conversationID]?.disappearingSeconds,
                containsLink: false,
                containsMedia: true,
                token: sessionToken
            )
        } catch { errorMessage = error.localizedDescription }
    }

    func settings(in conversationID: UUID) -> ConversationSettingsSnapshot {
        let value = sharedConversations[conversationID]
        return ConversationSettingsSnapshot(
            disappearingSeconds: value?.disappearingSeconds,
            readReceiptsEnabled: value?.readReceiptsEnabled ?? false,
            typingIndicatorsEnabled: value?.typingIndicatorsEnabled ?? false
        )
    }

    @discardableResult
    func startConversation(
        targetProfileID: UUID?,
        sourcePostID: UUID?,
        anonymous: Bool,
        initialText: String
    ) async -> UUID? {
        let normalized = initialText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        if demoMode {
            let id = UUID()
            conversations.insert(
                DemoConversation(
                    id: id,
                    actor: anonymous
                        ? .anonymous(alias: "new signal", sigilSeed: Int.random(in: 1...10_000), role: .participant)
                        : .profile(handle: "new_contact", displayName: "New contact"),
                    preview: normalized,
                    time: "Now",
                    isRequest: false
                ),
                at: 0
            )
            messagesByConversation[id] = [
                ConversationMessage(id: "demo-\(UUID().uuidString)", encryptedEventID: "demo", text: normalized, isMine: true, sentAt: Date())
            ]
            return id
        }
        guard let sessionToken else { return nil }
        do {
            let created = try await apiClient.createConversation(
                .init(
                    targetProfileID: targetProfileID,
                    sourcePostID: sourcePostID,
                    identity: anonymous ? .anonymous : .identified,
                    containsLink: Self.containsLink(normalized),
                    containsMedia: false
                ),
                token: sessionToken
            )
            sharedConversations[created.id] = created
            conversations.insert(created.localConversation, at: 0)
            try await open(conversationID: created.id)
            await sendText(normalized, in: created.id)
            return created.id
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func acceptRequest(conversationID: UUID) async {
        if demoMode {
            replaceConversation(conversationID, isRequest: false)
            return
        }
        guard let sessionToken else { return }
        do {
            try await open(conversationID: conversationID)
            if let roomID = roomIDs[conversationID] { try await encryptedProvider.acceptRequest(in: roomID) }
            let updated = try await apiClient.acceptConversation(id: conversationID, token: sessionToken)
            sharedConversations[conversationID] = updated
            replaceConversation(conversationID, isRequest: false)
        } catch { errorMessage = error.localizedDescription }
    }

    func block(conversationID: UUID) async {
        if let roomID = roomIDs[conversationID] { await encryptedProvider.block(roomID: roomID) }
        if !demoMode, let sessionToken {
            do { try await apiClient.blockConversation(id: conversationID, token: sessionToken) }
            catch { errorMessage = error.localizedDescription; return }
        }
        conversations.removeAll { $0.id == conversationID }
        messagesByConversation.removeValue(forKey: conversationID)
        sharedConversations.removeValue(forKey: conversationID)
        roomIDs.removeValue(forKey: conversationID)
    }

    func updateSettings(conversationID: UUID, disappearingSeconds: Int?, receipts: Bool, typing: Bool) async {
        guard !demoMode, let sessionToken else { return }
        do {
            try await open(conversationID: conversationID)
            guard let roomID = roomIDs[conversationID] else { throw MatrixMessagingError.roomUnavailable }
            try await encryptedProvider.setDisappearingTimer(disappearingSeconds, in: roomID)
            let updated = try await apiClient.updateConversationSettings(
                id: conversationID,
                settings: .init(
                    disappearingSeconds: disappearingSeconds,
                    readReceiptsEnabled: receipts,
                    typingIndicatorsEnabled: typing
                ),
                token: sessionToken
            )
            sharedConversations[conversationID] = updated
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteForAll(_ message: ConversationMessage, conversationID: UUID) async {
        guard message.isMine else { return }
        if demoMode {
            messagesByConversation[conversationID]?.removeAll { $0.id == message.id }
            return
        }
        guard let sessionToken, let roomID = roomIDs[conversationID] else { return }
        do {
            try await encryptedProvider.deleteForAll(eventID: message.encryptedEventID, in: roomID)
            try await apiClient.deleteEncryptedEvent(
                conversationID: conversationID,
                eventID: message.encryptedEventID,
                token: sessionToken
            )
        } catch { errorMessage = error.localizedDescription }
    }

    func report(_ selected: [ConversationMessage], conversationID: UUID, category: VeilShared.ReportCategory) async {
        guard !demoMode, let sessionToken, let conversation = sharedConversations[conversationID] else { return }
        let received = selected.filter { !$0.isMine }
        guard !received.isEmpty else { return }
        do {
            _ = try await apiClient.reportSelectedMessages(
                .init(
                    conversationID: conversationID,
                    selectedMessages: received.map {
                        .init(
                            encryptedEventID: $0.encryptedEventID,
                            sender: conversation.actor,
                            body: $0.text,
                            sentAt: $0.sentAt
                        )
                    },
                    category: category
                ),
                token: sessionToken
            )
        } catch { errorMessage = error.localizedDescription }
    }

    func exportMessageRecoveryKey() async throws -> String {
        try await encryptedProvider.exportOldDeviceKeys()
    }

    func importMessageRecoveryKey(_ key: String) async throws {
        try await encryptedProvider.importTransferredKeys(key)
    }

    private func replaceConversation(_ id: UUID, isRequest: Bool) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        let current = conversations[index]
        conversations[index] = DemoConversation(
            id: current.id,
            actor: current.actor,
            preview: current.preview,
            time: current.time,
            isRequest: isRequest,
            isAccepted: !isRequest
        )
    }

    private func loadDemoContent() {
        let accepted = UUID()
        let request = UUID()
        conversations = [
            DemoConversation(
                id: accepted,
                actor: .profile(handle: "formandfield", displayName: "form & field"),
                preview: "That corner catches the best afternoon light.",
                time: "14m",
                isRequest: false
            ),
            DemoConversation(
                id: request,
                actor: .anonymous(alias: "faint signal", sigilSeed: 73, role: .participant),
                preview: "Your post stayed with me.",
                time: "1h",
                isRequest: true,
                isAccepted: false
            )
        ]
        messagesByConversation = [
            accepted: [
                ConversationMessage(id: "demo-1", encryptedEventID: "demo-1", text: "That corner catches the best afternoon light.", isMine: false, sentAt: Date().addingTimeInterval(-840)),
                ConversationMessage(id: "demo-2", encryptedEventID: "demo-2", text: "I’m going back when the building is empty.", isMine: true, sentAt: Date().addingTimeInterval(-600))
            ],
            request: [
                ConversationMessage(id: "demo-3", encryptedEventID: "demo-3", text: "Your post stayed with me.", isMine: false, sentAt: Date().addingTimeInterval(-3_600))
            ]
        ]
    }

    private static func containsLink(_ text: String) -> Bool {
        text.range(of: #"https?://|www\."#, options: .regularExpression) != nil
    }
}
