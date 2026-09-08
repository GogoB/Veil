import Foundation

public enum VeilValidation {
    public static let maximumPostCharacters = 2_000
    public static let maximumPostImages = 4
    public static let maximumImageBytes = 12 * 1_024 * 1_024
    public static let maximumImagePixels = 24_000_000
    public static let maximumImageDimension = 8_000

    private static let reservedAliases: Set<String> = [
        "admin", "administrator", "moderator", "mod", "official", "support", "system", "veil"
    ]

    public static func normalizedUsername(_ value: String) throws -> String {
        let username = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard (3...24).contains(username.count) else { throw ValidationError.invalidUsername }
        guard username.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }) else {
            throw ValidationError.invalidUsername
        }
        guard !reservedAliases.contains(username) else { throw ValidationError.reservedName }
        return username
    }

    public static func validatedThreadAlias(_ value: String) throws -> String {
        let alias = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...24).contains(alias.count) else { throw ValidationError.invalidAlias }
        let allowed = CharacterSet.letters
            .union(.decimalDigits)
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "._-"))
        guard alias.unicodeScalars.allSatisfy(allowed.contains) else { throw ValidationError.invalidAlias }
        let words = Set(alias.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted))
        guard reservedAliases.isDisjoint(with: words) else { throw ValidationError.reservedName }
        return alias
    }

    public static func validatePost(body: String, mediaCount: Int) throws {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || mediaCount > 0 else { throw ValidationError.emptyPost }
        guard body.count <= maximumPostCharacters else { throw ValidationError.postTooLong }
        guard (0...maximumPostImages).contains(mediaCount) else { throw ValidationError.tooManyImages }
    }

    public static func expirationDate(for preset: ExpirationPreset, from date: Date = .now) -> Date? {
        let seconds: TimeInterval
        switch preset {
        case .oneDay: seconds = 86_400
        case .sevenDays: seconds = 7 * 86_400
        case .thirtyDays: seconds = 30 * 86_400
        case .never: return nil
        }
        return date.addingTimeInterval(seconds)
    }
}

public enum ValidationError: Error, Equatable {
    case invalidUsername
    case reservedName
    case invalidAlias
    case emptyPost
    case postTooLong
    case tooManyImages
}
