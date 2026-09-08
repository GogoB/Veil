import Foundation
import Testing
@testable import VeilShared

@Suite("Public privacy contracts")
struct PrivacyContractTests {
    @Test("Anonymous actors cannot contain profiles")
    func anonymousActorRejectsProfile() throws {
        let profile = ProfileSummary(id: UUID(), username: "public_name")
        #expect(throws: ContractError.invalidActorPresentation) {
            try ActorPresentation(
                kind: .generatedAlias,
                role: .participant,
                profile: profile,
                threadAlias: "quiet signal",
                sigil: "sigil"
            )
        }
    }

    @Test("Anonymous post JSON has no private identity keys")
    func anonymousPostSerializationIsUnlinkable() throws {
        let actor = try ActorPresentation(
            kind: .generatedAlias,
            role: .originalPoster,
            threadAlias: "quiet signal",
            sigil: "thread-7",
            enforcementToken: "opaque-enforcement"
        )
        let post = Post(
            id: UUID(),
            actor: actor,
            visibility: .anonymous,
            body: "A public thought",
            createdAt: .now
        )

        let object = try jsonObject(post)
        assertForbiddenKeysAreAbsent(object)
        #expect(path(object, "actor.profile") == nil)
        #expect(path(object, "actor.threadAlias") as? String == "quiet signal")
    }

    @Test("Moderator cases expose opaque tokens only")
    func moderatorSerializationHasNoProfiles() throws {
        let value = ModeratorCase(
            id: UUID(),
            caseToken: "opaque-case",
            enforcementToken: "opaque-enforcement",
            contentID: UUID(),
            category: .privateInformation
        )
        let object = try jsonObject(value)
        assertForbiddenKeysAreAbsent(object)
        #expect(path(object, "caseToken") as? String == "opaque-case")
        #expect(path(object, "enforcementToken") as? String == "opaque-enforcement")
    }

    @Test("Report requests contain no reporter identity")
    func reportSerializationHasNoReporter() throws {
        let value = ReportRequest(contentID: UUID(), category: .credibleThreat, explanation: "Review this")
        let object = try jsonObject(value)
        assertForbiddenKeysAreAbsent(object)
        #expect(path(object, "reporter") == nil)
        #expect(path(object, "reporterID") == nil)
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> Any {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try JSONSerialization.jsonObject(with: encoder.encode(value))
    }

    private func assertForbiddenKeysAreAbsent(_ object: Any) {
        let forbidden = ["accountid", "ownerid", "age", "birthdate", "adultconfirmation", "recoverycode", "matrixuserid", "matrixroomid"]
        for key in allKeys(in: object) {
            #expect(!forbidden.contains(key.lowercased()), "Forbidden public key: \(key)")
        }
    }

    private func allKeys(in object: Any) -> [String] {
        if let dictionary = object as? [String: Any] {
            return dictionary.keys.flatMap { [$0] + allKeys(in: dictionary[$0] as Any) }
        }
        if let array = object as? [Any] {
            return array.flatMap(allKeys)
        }
        return []
    }

    private func path(_ object: Any, _ path: String) -> Any? {
        path.split(separator: ".").reduce(object as Any?) { current, component in
            (current as? [String: Any])?[String(component)]
        }
    }
}
