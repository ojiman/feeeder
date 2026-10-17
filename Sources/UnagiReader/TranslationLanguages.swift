import Foundation
import ReaderCore
@preconcurrency import Translation

/// Article defaults read the Mac's language list, never the per-app AppleLanguages override.
enum TranslationLanguages {
    static var preferred: [String] {
        CFPreferencesCopyValue("AppleLanguages" as CFString, kCFPreferencesAnyApplication,
                               kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String] ?? ["en"]
    }
    static func available() async -> [String] {
        await LanguageAvailability().supportedLanguages.map(\.minimalIdentifier)
    }
    static func name(_ identifier: String) -> String {
        Locale(identifier: ReaderLocalization.bundle.preferredLocalizations.first ?? "en").localizedString(forIdentifier: identifier) ?? identifier
    }
}
