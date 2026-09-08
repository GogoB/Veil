import Foundation
import VeilShared

struct APIClient {
    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = APIClient.configuredBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    static var configuredBaseURL: URL {
        let configured = UserDefaults.standard.string(forKey: "veil.api.base-url")
            ?? Bundle.main.object(forInfoDictionaryKey: "VEILApiBaseURL") as? String
            ?? "http://127.0.0.1:8080"
        return URL(string: configured) ?? URL(string: "http://127.0.0.1:8080")!
    }

    func health() async throws -> VeilShared.Health {
        try await request("ready")
    }

    func createAccount(
        username: String,
        mode: VeilShared.AccountMode,
        devicePublicKey: String,
        passphrase: String?
    ) async throws -> VeilShared.SessionEnvelope {
        try await request(
            "api/v1/accounts/create",
            method: "POST",
            body: VeilShared.AccountCreateRequest(
                username: username,
                mode: mode,
                devicePublicKey: devicePublicKey,
                securityPassphrase: passphrase
            )
        )
    }

    func recoverAccount(
        username: String,
        passphrase: String,
        recoveryCode: String,
        replacementDevicePublicKey: String
    ) async throws -> VeilShared.SessionEnvelope {
        try await request(
            "api/v1/accounts/recover",
            method: "POST",
            body: VeilShared.AccountRecoveryRequest(
                username: username,
                securityPassphrase: passphrase,
                recoveryCode: recoveryCode,
                replacementDevicePublicKey: replacementDevicePublicKey
            )
        )
    }

    func currentProfile(token: String) async throws -> VeilShared.Profile {
        try await request("api/v1/accounts/me", token: token)
    }

    func profile(id: UUID, token: String?) async throws -> VeilShared.Profile {
        try await request("api/v1/profiles/\(id.uuidString)", token: token)
    }

    func updateProfile(_ body: VeilShared.ProfileUpdateRequest, token: String) async throws -> VeilShared.Profile {
        try await request("api/v1/profiles/me", method: "PATCH", token: token, body: body)
    }

    func setFollowing(profileID: UUID, following: Bool, token: String) async throws {
        let _: APIAcknowledgement = try await request(
            "api/v1/profiles/\(profileID.uuidString)/follow",
            method: following ? "POST" : "DELETE",
            token: token
        )
    }

    func preferences(token: String) async throws -> VeilShared.ContentPreferences {
        try await request("api/v1/preferences", token: token)
    }

    func updatePreferences(_ value: VeilShared.ContentPreferences, token: String) async throws -> VeilShared.ContentPreferences {
        try await request("api/v1/preferences", method: "PUT", token: token, body: value)
    }

    func logout(token: String) async throws {
        let _: APIAcknowledgement = try await request("api/v1/accounts/logout", method: "POST", token: token)
    }

    func messagingSession(token: String) async throws -> VeilShared.MessagingSessionConfiguration {
        try await request("api/v1/accounts/messaging-session", token: token)
    }

    func topics(token: String?) async throws -> [VeilShared.Topic] {
        try await request("api/v1/topics", token: token)
    }

    func feed(_ kind: VeilShared.FeedKind, token: String?) async throws -> VeilShared.Page<VeilShared.Post> {
        try await request("api/v1/feeds/\(kind.rawValue)", token: token)
    }

    func post(id: UUID, token: String?) async throws -> VeilShared.Post {
        try await request("api/v1/posts/\(id.uuidString)", token: token)
    }

    func createPost(_ body: VeilShared.PostCreateRequest, token: String) async throws -> VeilShared.PostCreationEnvelope {
        try await request("api/v1/posts", method: "POST", token: token, body: body)
    }

    func editPost(id: UUID, body: VeilShared.PostEditRequest, token: String) async throws -> VeilShared.Post {
        try await request("api/v1/posts/\(id.uuidString)", method: "PATCH", token: token, body: body)
    }

    func deletePost(id: UUID, token: String) async throws {
        let _: APIAcknowledgement = try await request("api/v1/posts/\(id.uuidString)", method: "DELETE", token: token)
    }

    func setPostLike(id: UUID, liked: Bool, token: String) async throws {
        let _: APIAcknowledgement = try await request(
            "api/v1/posts/\(id.uuidString)/likes",
            method: liked ? "POST" : "DELETE",
            token: token
        )
    }

    func comments(postID: UUID, token: String?) async throws -> VeilShared.Page<VeilShared.Comment> {
        try await request("api/v1/posts/\(postID.uuidString)/comments", token: token)
    }

    func profilePosts(profileID: UUID, token: String?) async throws -> VeilShared.Page<VeilShared.Post> {
        try await request("api/v1/profiles/\(profileID.uuidString)/posts", token: token)
    }

    func createComment(
        postID: UUID,
        body: VeilShared.CommentCreateRequest,
        token: String
    ) async throws -> VeilShared.Comment {
        try await request("api/v1/posts/\(postID.uuidString)/comments", method: "POST", token: token, body: body)
    }

    func editComment(id: UUID, body: String, token: String) async throws -> VeilShared.Comment {
        try await request(
            "api/v1/comments/\(id.uuidString)",
            method: "PATCH",
            token: token,
            body: VeilShared.CommentEditRequest(body: body)
        )
    }

    func deleteComment(id: UUID, token: String) async throws {
        let _: APIAcknowledgement = try await request("api/v1/comments/\(id.uuidString)", method: "DELETE", token: token)
    }

    func setCommentLike(id: UUID, liked: Bool, token: String) async throws {
        let _: APIAcknowledgement = try await request(
            "api/v1/comments/\(id.uuidString)/likes",
            method: liked ? "POST" : "DELETE",
            token: token
        )
    }

    func collaborationInvitations(token: String) async throws -> [VeilShared.CollaborationInvitation] {
        try await request("api/v1/collaborations/invitations", token: token)
    }

    func acceptCollaboration(postID: UUID, profileID: UUID, token: String) async throws {
        let _: APIAcknowledgement = try await request(
            "api/v1/posts/\(postID.uuidString)/collaborators/\(profileID.uuidString)/accept",
            method: "POST",
            token: token
        )
    }

    func leaveCollaboration(postID: UUID, token: String) async throws {
        let _: APIAcknowledgement = try await request(
            "api/v1/posts/\(postID.uuidString)/collaborators/me",
            method: "DELETE",
            token: token
        )
    }

    func search(_ query: String, token: String?) async throws -> VeilShared.SearchResults {
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return try await request("api/v1/search?\(components.percentEncodedQuery ?? "")", token: token)
    }

    func veiledActivity(token: String) async throws -> VeilShared.VeiledActivity {
        try await request("api/v1/veiled-activity", token: token)
    }

    func conversations(token: String) async throws -> [VeilShared.Conversation] {
        try await request("api/v1/conversations", token: token)
    }

    func createConversation(_ body: VeilShared.ConversationRequest, token: String) async throws -> VeilShared.Conversation {
        try await request("api/v1/conversations", method: "POST", token: token, body: body)
    }

    func messagingRoom(conversationID: UUID, token: String) async throws -> VeilShared.MessagingRoomConfiguration {
        try await request("api/v1/conversations/\(conversationID.uuidString)/messaging-room", token: token)
    }

    func conversationEvents(conversationID: UUID, token: String) async throws -> [VeilShared.Message] {
        try await request("api/v1/conversations/\(conversationID.uuidString)/events", token: token)
    }

    func registerEncryptedEvent(
        conversationID: UUID,
        eventID: String,
        sentAt: Date,
        disappearingSeconds: Int?,
        containsLink: Bool,
        containsMedia: Bool,
        token: String
    ) async throws -> VeilShared.Message {
        try await request(
            "api/v1/conversations/\(conversationID.uuidString)/events",
            method: "POST",
            token: token,
            body: VeilShared.EncryptedEventRequest(
                encryptedEventID: eventID,
                sentAt: sentAt,
                disappearingSeconds: disappearingSeconds,
                containsLink: containsLink,
                containsMedia: containsMedia
            )
        )
    }

    func acceptConversation(id: UUID, token: String) async throws -> VeilShared.Conversation {
        try await request("api/v1/conversations/\(id.uuidString)/accept", method: "POST", token: token)
    }

    func deleteEncryptedEvent(conversationID: UUID, eventID: String, token: String) async throws {
        var pathComponentCharacters = CharacterSet.alphanumerics
        pathComponentCharacters.insert(charactersIn: "-._~")
        let encoded = eventID.addingPercentEncoding(withAllowedCharacters: pathComponentCharacters) ?? eventID
        let _: APIAcknowledgement = try await request(
            "api/v1/conversations/\(conversationID.uuidString)/events/\(encoded)",
            method: "DELETE",
            token: token
        )
    }

    func updateConversationSettings(
        id: UUID,
        settings: VeilShared.ConversationSettingsRequest,
        token: String
    ) async throws -> VeilShared.Conversation {
        try await request("api/v1/conversations/\(id.uuidString)/settings", method: "PUT", token: token, body: settings)
    }

    func blockConversation(id: UUID, token: String) async throws {
        let _: APIAcknowledgement = try await request("api/v1/conversations/\(id.uuidString)/block", method: "POST", token: token)
    }

    func report(contentID: UUID, category: VeilShared.ReportCategory, explanation: String?, token: String) async throws -> VeilShared.ReportReceipt {
        try await request(
            "api/v1/reports",
            method: "POST",
            token: token,
            body: VeilShared.ReportRequest(contentID: contentID, category: category, explanation: explanation)
        )
    }

    func reportSelectedMessages(_ body: VeilShared.SelectedMessageReportRequest, token: String) async throws -> VeilShared.ReportReceipt {
        try await request("api/v1/reports/messages", method: "POST", token: token, body: body)
    }

    func uploadImage(_ data: Data, width: Int, height: Int, token: String) async throws -> VeilShared.Media {
        let boundary = "veil-\(UUID().uuidString)"
        var payload = Data()
        payload.appendMultipart(name: "width", value: String(width), boundary: boundary)
        payload.appendMultipart(name: "height", value: String(height), boundary: boundary)
        payload.append("--\(boundary)\r\n")
        payload.append("Content-Disposition: form-data; name=\"file\"; filename=\"upload.jpg\"\r\n")
        payload.append("Content-Type: image/jpeg\r\n\r\n")
        payload.append(data)
        payload.append("\r\n--\(boundary)--\r\n")
        return try await request(
            "api/v1/media/images",
            method: "POST",
            token: token,
            contentType: "multipart/form-data; boundary=\(boundary)",
            rawBody: payload
        )
    }

    private func request<Response: Decodable, Body: Encodable>(
        _ path: String,
        method: String = "GET",
        token: String? = nil,
        body: Body
    ) async throws -> Response {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try await request(path, method: method, token: token, rawBody: encoder.encode(body))
    }

    private func request<Response: Decodable>(
        _ path: String,
        method: String = "GET",
        token: String? = nil,
        contentType: String = "application/json",
        rawBody: Data? = nil
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else { throw APIClientError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let rawBody {
            request.httpBody = rawBody
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            throw APIClientError.server(status: http.statusCode, message: envelope?.error ?? "Request failed")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if data.isEmpty, let acknowledgement = APIAcknowledgement(ok: true) as? Response {
            return acknowledgement
        }
        do { return try decoder.decode(Response.self, from: data) }
        catch { throw APIClientError.decoding(error.localizedDescription) }
    }
}

private struct APIAcknowledgement: Decodable { let ok: Bool? }
private struct APIErrorEnvelope: Decodable { let error: String }

enum APIClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(status: Int, message: String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The API address is invalid."
        case .invalidResponse: return "The server returned an unreadable response."
        case let .server(_, message): return message
        case let .decoding(message): return "The app could not read the server response: \(message)"
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }

    mutating func appendMultipart(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }
}
