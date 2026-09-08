import Foundation
import Testing
import VeilShared
@testable import VeilServer

@Suite("Server contract guards")
struct ServerContractTests {
    @Test("Secure digests are deterministic and do not expose the input")
    func secureDigest() {
        let digest = SecureValue.digest("session-secret")
        #expect(digest == SecureValue.digest("session-secret"))
        #expect(!digest.contains("session-secret"))
        #expect(digest.count == 64)
    }

    @Test("Restricted ownership values round-trip and use randomized ciphertext")
    func ownershipCipherRoundTrip() throws {
        let key = Data(repeating: 23, count: 32).base64EncodedString()
        let cipher = try OwnershipCipher(base64Key: key)
        let accountID = UUID()
        let first = try cipher.seal(accountID: accountID)
        let second = try cipher.seal(accountID: accountID)
        #expect(try cipher.open(first) == accountID)
        #expect(first != second)
        #expect(!String(decoding: first, as: UTF8.self).contains(accountID.uuidString))
    }

    @Test("Anonymous identities are stable only inside their scope")
    func scopedAnonymousIdentity() throws {
        let cipher = try OwnershipCipher(base64Key: Data(repeating: 41, count: 32).base64EncodedString())
        let account = AuthenticatedAccount(accountID: UUID(), profileID: UUID(), deviceID: UUID())
        let firstThread = UUID()
        let first = try IdentityService().postIdentity(
            account: account,
            postID: firstThread,
            visibility: .anonymous,
            mode: .generatedAlias,
            customAlias: nil,
            cipher: cipher
        )
        let repeated = try IdentityService().postIdentity(
            account: account,
            postID: firstThread,
            visibility: .anonymous,
            mode: .generatedAlias,
            customAlias: nil,
            cipher: cipher
        )
        let another = try IdentityService().postIdentity(
            account: account,
            postID: UUID(),
            visibility: .anonymous,
            mode: .generatedAlias,
            customAlias: nil,
            cipher: cipher
        )
        #expect(first.profileID == nil)
        #expect(first.sigil == repeated.sigil)
        #expect(first.sigil != another.sigil)
    }

    @Test("Conversation identities do not correlate across conversations")
    func scopedConversationIdentity() throws {
        let cipher = try OwnershipCipher(base64Key: Data(repeating: 83, count: 32).base64EncodedString())
        let accountID = UUID()
        let conversationID = UUID()
        let first = IdentityService().conversationIdentity(accountID: accountID, conversationID: conversationID, cipher: cipher)
        let repeated = IdentityService().conversationIdentity(accountID: accountID, conversationID: conversationID, cipher: cipher)
        let another = IdentityService().conversationIdentity(accountID: accountID, conversationID: UUID(), cipher: cipher)
        #expect(first.alias == repeated.alias)
        #expect(first.sigil == repeated.sigil)
        #expect(first.sigil != another.sigil)
        #expect(first.enforcementToken != repeated.enforcementToken)
    }
}
