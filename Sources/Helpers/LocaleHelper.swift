import Foundation

enum LocaleHelper {
    static let validLocales: Set<String> = [
        "ar-SA", "ca", "cs", "da", "de-DE", "el", "en-AU", "en-CA", "en-GB", "en-US",
        "es-ES", "es-MX", "fi", "fr-CA", "fr-FR", "he", "hi", "hr", "hu", "id",
        "it", "ja", "ko", "ms", "nl-NL", "no", "pl", "pt-BR", "pt-PT", "ro",
        "ru", "sk", "sv", "th", "tr", "uk", "vi", "zh-Hans", "zh-Hant",
    ]

    static func validate(_ locale: String) -> Bool {
        validLocales.contains(locale)
    }
}

enum KeywordValidator {
    struct ValidationResult: Sendable {
        let isValid: Bool
        let charCount: Int
        let maxChars: Int
        let warnings: [String]
        let error: String?
    }

    static func validate(_ keywords: String, maxChars: Int = 100) -> ValidationResult {
        var warnings: [String] = []

        if keywords.count > maxChars {
            return ValidationResult(
                isValid: false,
                charCount: keywords.count,
                maxChars: maxChars,
                warnings: [],
                error: "Keywords exceed \(maxChars) character limit (\(keywords.count) chars)"
            )
        }

        // Check for spaces after commas
        if keywords.contains(", ") {
            warnings.append("Spaces found after commas — these waste characters. Remove spaces between keywords.")
        }

        // Check for duplicates
        let words = keywords.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let uniqueWords = Set(words)
        if uniqueWords.count < words.count {
            let duplicates = Dictionary(grouping: words, by: { $0 }).filter { $0.value.count > 1 }.keys
            warnings.append("Duplicate keywords found: \(duplicates.sorted().joined(separator: ", "))")
        }

        // Check for simple plural forms
        for word in words {
            let singular = word.hasSuffix("s") ? String(word.dropLast()) : nil
            if let singular, words.contains(singular) {
                warnings.append("Possible plural/singular duplicate: '\(word)' and '\(singular)'")
            }
        }

        return ValidationResult(
            isValid: true,
            charCount: keywords.count,
            maxChars: maxChars,
            warnings: warnings,
            error: nil
        )
    }
}

enum CharLimitValidator {
    static func validate(_ text: String, field: String, maxChars: Int) -> (isValid: Bool, error: String?) {
        if text.count > maxChars {
            return (false, "\(field) exceeds \(maxChars) character limit (\(text.count) chars)")
        }
        return (true, nil)
    }
}
