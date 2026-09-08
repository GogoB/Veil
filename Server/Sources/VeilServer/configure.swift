import Fluent
import FluentPostgresDriver
import Foundation
import Vapor

func configure(_ app: Application) async throws {
    let databaseHost = Environment.get("DATABASE_HOST") ?? "127.0.0.1"
    let databasePort = Environment.get("DATABASE_PORT").flatMap(Int.init) ?? 5432
    let databaseName = Environment.get("DATABASE_NAME") ?? "veil"
    let databaseUser = Environment.get("DATABASE_USERNAME") ?? "veil"
    let databasePassword = Environment.get("DATABASE_PASSWORD") ?? "veil-local-only"
    let ownershipKey = Environment.get("OWNERSHIP_KEY_BASE64") ?? Data(repeating: 7, count: 32).base64EncodedString()
    if app.environment == .production && Environment.get("OWNERSHIP_KEY_BASE64") == nil {
        throw ConfigurationError.invalidOwnershipKey
    }

    app.databases.use(
        .postgres(
            configuration: .init(
                hostname: databaseHost,
                port: databasePort,
                username: databaseUser,
                password: databasePassword,
                database: databaseName,
                tls: .disable
            )
        ),
        as: .psql
    )
    app.ownershipCipher = try OwnershipCipher(base64Key: ownershipKey)
    app.rateLimiter = DatabaseRateLimiter()
    app.appAttestVerifier = DebugAppAttestVerifier(
        requiresDebugHeader: Environment.get("REQUIRE_DEBUG_APP_ATTEST") == "true"
    )

    let uploadPath = Environment.get("UPLOAD_DIRECTORY") ?? app.directory.publicDirectory + "uploads"
    try FileManager.default.createDirectory(atPath: uploadPath, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(atPath: app.directory.workingDirectory + ".tmp-images", withIntermediateDirectories: true)
    app.imageProcessor = VipsImageProcessor(
        temporaryDirectory: URL(fileURLWithPath: app.directory.workingDirectory + ".tmp-images", isDirectory: true)
    )
    if let matrixInternalURL = Environment.get("MATRIX_HOMESERVER_URL"),
       let matrixPublicValue = Environment.get("MATRIX_PUBLIC_HOMESERVER_URL"),
       let matrixPublicURL = URL(string: matrixPublicValue),
       let matrixSecret = Environment.get("MATRIX_REGISTRATION_SECRET"),
       !matrixSecret.isEmpty {
        app.matrixProvisioner = SynapseSharedSecretProvisioner(
            internalHomeserverURL: matrixInternalURL,
            publicHomeserverURL: matrixPublicURL,
            registrationSecret: matrixSecret
        )
    }

    app.middleware.use(APIErrorMiddleware())
    app.middleware.use(CORSMiddleware(configuration: .init(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .PATCH, .DELETE, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
    )))
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.migrations.add(CreateSchema())
    app.migrations.add(SeedTopics())

    try routes(app)
}
