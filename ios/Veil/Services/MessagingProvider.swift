import Foundation

struct ConversationMessage: Identifiable, Equatable {
    let id: UUID
    let text: String
    let isMine: Bool
    let createdLabel: String
}

@MainActor
protocol MessagingProvider: AnyObject {
    var conversations: [DemoConversation] { get }
    func messages(in conversationID: UUID) -> [ConversationMessage]
    func sendText(_ text: String, in conversationID: UUID)
    func acceptRequest(conversationID: UUID)
    func block(conversationID: UUID)
}

@MainActor
final class DemoMessagingProvider: ObservableObject, MessagingProvider {
    @Published private(set) var conversations: [DemoConversation]
    @Published private var messagesByConversation: [UUID: [ConversationMessage]] = [:]

    init() {
        let formID = UUID()
        let requestID = UUID()
        conversations = [
            DemoConversation(id: formID, actor: .profile(handle: "formandfield", displayName: "form & field"), preview: "That corner catches the best afternoon light.", time: "14m", isRequest: false),
            DemoConversation(id: requestID, actor: .anonymous(alias: "faint signal", sigilSeed: 73, role: .participant), preview: "Your post stayed with me.", time: "1h", isRequest: true)
        ]
        messagesByConversation[formID] = [
            ConversationMessage(id: UUID(), text: "That corner catches the best afternoon light.", isMine: false, createdLabel: "14m"),
            ConversationMessage(id: UUID(), text: "I’m going back when the building is empty.", isMine: true, createdLabel: "10m")
        ]
        messagesByConversation[requestID] = [
            ConversationMessage(id: UUID(), text: "Your post stayed with me.", isMine: false, createdLabel: "1h")
        ]
    }

    func messages(in conversationID: UUID) -> [ConversationMessage] {
        messagesByConversation[conversationID] ?? []
    }

    func sendText(_ text: String, in conversationID: UUID) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 2_000 else { return }
        messagesByConversation[conversationID, default: []].append(
            ConversationMessage(id: UUID(), text: normalized, isMine: true, createdLabel: "Now")
        )
        objectWillChange.send()
    }

    func acceptRequest(conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        let current = conversations[index]
        conversations[index] = DemoConversation(
            id: current.id,
            actor: current.actor,
            preview: current.preview,
            time: current.time,
            isRequest: false
        )
    }

    func block(conversationID: UUID) {
        conversations.removeAll { $0.id == conversationID }
        messagesByConversation.removeValue(forKey: conversationID)
    }
}
