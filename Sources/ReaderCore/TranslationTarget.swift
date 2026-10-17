import Foundation

/// The article's own target preference; an empty value follows the Mac (specification 3.6).
public enum TranslationTarget {
    public static let key = "articleTranslationTarget"

    public static func resolve(stored: String, preferred: [String], supported: [String]) -> String {
        guard stored.isEmpty else { return stored }
        for preference in preferred {
            if let match = supported.first(where: { LanguageDecision.sameLanguage(preference, $0) }) { return match }
        }
        return "en"
    }
}
