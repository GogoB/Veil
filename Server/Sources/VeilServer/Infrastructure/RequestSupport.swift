import Foundation
import Vapor

enum APIError: Error {
    case invalidInput(String)
    case conflict(String)
    case forbidden(String)
    case notFound(String)
}

struct APIErrorMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch let error as APIError {
            let status: HTTPResponseStatus
            let message: String
            switch error {
            case let .invalidInput(value): status = .badRequest; message = value
            case let .conflict(value): status = .conflict; message = value
            case let .forbidden(value): status = .forbidden; message = value
            case let .notFound(value): status = .notFound; message = value
            }
            return try await ErrorEnvelope(error: message).encodeResponse(status: status, for: request)
        }
    }
}

struct ErrorEnvelope: Content {
    let error: String
}

struct EmptyResponse: Content {
    let ok: Bool
    static let success = Self(ok: true)
}

extension String {
    var nilIfBlank: String? {
        let value = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

extension Request {
    var shortLivedNetworkSubject: String {
        let address = self.remoteAddress?.ipAddress ?? "unknown"
        return self.ownershipCipher.rotatingNetworkDigest(address)
    }
}
