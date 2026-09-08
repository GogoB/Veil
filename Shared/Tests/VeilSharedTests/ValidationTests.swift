import Foundation
import Testing
@testable import VeilShared

@Suite("Shared validation")
struct ValidationTests {
    @Test func normalizesUsername() throws {
        #expect(try VeilValidation.normalizedUsername("  Quiet.User  ") == "quiet.user")
        #expect(throws: ValidationError.invalidUsername) {
            try VeilValidation.normalizedUsername("has a space")
        }
        #expect(throws: ValidationError.reservedName) {
            try VeilValidation.normalizedUsername("moderator")
        }
    }

    @Test func validatesPostLimits() throws {
        try VeilValidation.validatePost(body: "valid", mediaCount: 4)
        #expect(throws: ValidationError.emptyPost) {
            try VeilValidation.validatePost(body: "  ", mediaCount: 0)
        }
        #expect(throws: ValidationError.postTooLong) {
            try VeilValidation.validatePost(body: String(repeating: "a", count: 2_001), mediaCount: 0)
        }
        #expect(throws: ValidationError.tooManyImages) {
            try VeilValidation.validatePost(body: "valid", mediaCount: 5)
        }
    }

    @Test func expirationPresets() {
        let start = Date(timeIntervalSince1970: 1_000)
        #expect(VeilValidation.expirationDate(for: .oneDay, from: start) == start.addingTimeInterval(86_400))
        #expect(VeilValidation.expirationDate(for: .never, from: start) == nil)
    }
}
