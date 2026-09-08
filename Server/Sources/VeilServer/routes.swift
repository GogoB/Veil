import Fluent
import Vapor
import VeilShared

func routes(_ app: Application) throws {
    app.get { _ in "Veil local API" }
    app.get("health") { request async -> Health in
        do {
            _ = try await TopicRecord.query(on: request.db).count()
            return Health(status: "ok", database: "ready", matrix: matrixStatus())
        } catch {
            return Health(status: "degraded", database: "unavailable", matrix: matrixStatus())
        }
    }
    app.get("ready") { request async throws -> Health in
        do {
            _ = try await TopicRecord.query(on: request.db).count()
            return Health(status: "ready", database: "ready", matrix: matrixStatus())
        } catch {
            throw Abort(.serviceUnavailable, reason: "Database is not ready")
        }
    }

    let api = app.grouped("api", "v1")
    try api.register(collection: AccountRoutes())
    try api.register(collection: ProfileRoutes())
    try api.register(collection: SocialRoutes())
    try api.register(collection: MediaRoutes())
    try api.register(collection: ConversationRoutes())
    try api.register(collection: ReportRoutes())
}

private func matrixStatus() -> String {
    Environment.get("MATRIX_HOMESERVER_URL") == nil ? "not-configured" : "configured"
}
