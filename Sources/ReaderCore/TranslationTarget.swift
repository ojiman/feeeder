import Foundation

/// The article's own target preference; an empty value follows the Mac (specification 3.6).
public enum TranslationTarget {
    public static let key = "articleTranslationTarget"

    public static func resolve(stored: String, preferred: [String], supported: [String]) -> String {
        guard stored.isEmpty else { return stored }
        for preference in preferred + ["en"] {
            let matches = supported.filter { LanguageDecision.sameLanguage(preference, $0) }
            if let exact = matches.first(where: { $0 == Locale.Language(identifier: preference).minimalIdentifier }) { return exact }
            // Prefer the unqualified language over an arbitrary regional variant.
            if let match = matches.min(by: { $0.count < $1.count }) { return match }
        }
        return "en"
    }
}
