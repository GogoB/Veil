import Fluent
import Foundation
import Vapor
import VeilShared

struct ReportRoutes: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let authenticated = routes.grouped(SessionAuthenticator()).grouped(AuthenticatedAccount.guardMiddleware())
        authenticated.post("reports", use: self.reportPublicContent)
        authenticated.post("reports", "messages", use: self.reportSelectedMessages)
        routes.get("moderation", "cases", use: self.moderatorCases)
    }

    private func reportPublicContent(_ request: Request) async throws -> ReportReceipt {
        let reporter = try request.authenticatedAccount
        let payload = try request.content.decode(ReportRequest.self)
        guard (payload.explanation?.count ?? 0) <= 500 else {
            throw APIError.invalidInput("Keep report context to 500 characters or fewer")
        }
        let enforcementToken: String
        if let post = try await PostRecord.find(payload.contentID, on: request.db), post.deletedAt == nil {
            enforcementToken = post.enforcementToken
        } else if let comment = try await CommentRecord.find(payload.contentID, on: request.db) {
            enforcementToken = comment.enforcementToken
        } else {
            throw APIError.notFound("Content is unavailable")
        }
        let caseToken = SecureValue.token(byteCount: 24)
        let record = ReportRecord()
        record.id = UUID(); record.caseToken = caseToken; record.enforcementToken = enforcementToken
        record.contentID = payload.contentID; record.category = payload.category.rawValue
        record.explanation = payload.explanation?.nilIfBlank
        record.sealedReporterID = try request.ownershipCipher.seal(accountID: reporter.accountID)
        record.status = "open"
        try await record.create(on: request.db)
        return ReportReceipt(caseToken: caseToken)
    }

    private func reportSelectedMessages(_ request: Request) async throws -> ReportReceipt {
        let reporter = try request.authenticatedAccount
        let payload = try request.content.decode(SelectedMessageReportRequest.self)
        guard !payload.selectedMessages.isEmpty, payload.selectedMessages.count <= 20,
              (payload.explanation?.count ?? 0) <= 500,
              let conversation = try await ConversationRecord.find(payload.conversationID, on: request.db),
              ConversationService().participant(reporter.accountID, in: conversation) else {
            throw APIError.invalidInput("Select between one and twenty messages from your conversation")
        }
        let knownEvents = Set(try await MessageEventRecord.query(on: request.db)
            .filter(\.$conversationID == payload.conversationID).all().map(\.encryptedEventID))
        guard payload.selectedMessages.allSatisfy({
            knownEvents.contains($0.encryptedEventID) && !$0.body.isEmpty && $0.body.count <= 2_000
        }) else {
            throw APIError.invalidInput("Selected message evidence is invalid")
        }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let evidence = try payload.selectedMessages.map { item in
            ReportedEvidencePayload(
                encryptedEventID: item.encryptedEventID,
                senderJSON: String(decoding: try encoder.encode(item.sender), as: UTF8.self),
                body: item.body,
                sentAt: item.sentAt
            )
        }
        let caseToken = SecureValue.token(byteCount: 24)
        let record = MessageReportRecord(); record.id = UUID(); record.caseToken = caseToken
        record.conversationID = payload.conversationID; record.selectedEvidence = evidence
        record.category = payload.category.rawValue; record.explanation = payload.explanation?.nilIfBlank
        record.sealedReporterID = try request.ownershipCipher.seal(accountID: reporter.accountID)
        try await record.create(on: request.db)
        return ReportReceipt(caseToken: caseToken)
    }

    private func moderatorCases(_ request: Request) async throws -> [ModeratorCase] {
        guard let configured = Environment.get("MODERATOR_API_KEY"), !configured.isEmpty,
              request.headers.first(name: "X-Veil-Moderator-Key") == configured else {
            throw Abort(.unauthorized)
        }
        let reports = try await ReportRecord.query(on: request.db).filter(\.$status == "open").sort(\.$createdAt).all()
        return reports.compactMap { report in
            guard let id = report.id, let category = ReportCategory(rawValue: report.category) else { return nil }
            return ModeratorCase(
                id: id,
                caseToken: report.caseToken,
                enforcementToken: report.enforcementToken,
                contentID: report.contentID,
                category: category,
                explanation: report.explanation
            )
        }
    }
}
