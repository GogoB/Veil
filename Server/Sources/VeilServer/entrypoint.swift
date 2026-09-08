import Vapor

@main
enum EntryPoint {
    static func main() async throws {
        var environment = try Environment.detect()
        try LoggingSystem.bootstrap(from: &environment)
        let application = try await Application.make(environment)
        do {
            try await configure(application)
            try await application.execute()
        } catch {
            application.logger.report(error: error)
            try? await application.asyncShutdown()
            throw error
        }
        try await application.asyncShutdown()
    }
}
