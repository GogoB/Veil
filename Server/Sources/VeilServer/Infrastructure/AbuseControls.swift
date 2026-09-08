import Fluent
import Foundation
import Vapor

protocol AppAttestVerifying: Sendable {
    func verify(assertion: String?, challenge: String, request: Request) async throws
}

struct DebugAppAttestVerifier: AppAttestVerifying {
    let requiresDebugHeader: Bool

    func verify(assertion: String?, challenge: String, request: Request) async throws {
        guard self.requiresDebugHeader else { return }
        guard assertion == "local-debug", !challenge.isEmpty else {
            throw Abort(.unauthorized, reason: "App integrity assertion rejected")
        }
    }
}

struct AppAttestKey: StorageKey { typealias Value = any AppAttestVerifying }

struct RateLimitPolicy: Sendable {
    let bucket: String
    let limit: Int
    let window: TimeInterval

    static let signup = Self(bucket: "signup", limit: 5, window: 3_600)
    static let post = Self(bucket: "post", limit: 30, window: 3_600)
    static let upload = Self(bucket: "upload", limit: 40, window: 3_600)
    static let messageRequest = Self(bucket: "message-request", limit: 15, window: 3_600)
}

struct DatabaseRateLimiter: Sendable {
    func check(policy: RateLimitPolicy, subject: String, request: Request) async throws {
        let digest = request.ownershipCipher.enforcementDigest(subject)
        let now = Date()
        if let record = try await RateLimitRecord.query(on: request.db)
            .filter(\.$bucket == policy.bucket)
            .filter(\.$subjectDigest == digest)
            .first() {
            if now.timeIntervalSince(record.windowStartedAt) >= policy.window {
                record.windowStartedAt = now
                record.count = 1
            } else {
                guard record.count < policy.limit else {
                    throw Abort(.tooManyRequests, reason: "Try again after the current rate-limit window")
                }
                record.count += 1
            }
            try await record.update(on: request.db)
        } else {
            let record = RateLimitRecord()
            record.id = UUID()
            record.bucket = policy.bucket
            record.subjectDigest = digest
            record.windowStartedAt = now
            record.count = 1
            try await record.create(on: request.db)
        }
    }
}

struct RateLimiterKey: StorageKey { typealias Value = DatabaseRateLimiter }

extension Application {
    var appAttestVerifier: any AppAttestVerifying {
        get { self.storage[AppAttestKey.self] ?? DebugAppAttestVerifier(requiresDebugHeader: false) }
        set { self.storage[AppAttestKey.self] = newValue }
    }

    var rateLimiter: DatabaseRateLimiter {
        get { self.storage[RateLimiterKey.self] ?? DatabaseRateLimiter() }
        set { self.storage[RateLimiterKey.self] = newValue }
    }
}
