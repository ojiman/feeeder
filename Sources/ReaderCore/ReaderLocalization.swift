import Foundation

/// All app-owned text shares one package catalog. The main app declares the same localizations for native macOS matching.
public enum ReaderLocalization {
    public static let bundle = Bundle.main.url(forResource: "UnagiReader_ReaderCore", withExtension: "bundle")
        .flatMap(Bundle.init(url:)) ?? Bundle.module
    public static var languages: [String] { bundle.localizations.filter { $0 != "Base" }.sorted() }
}

/// AppleLanguages in the app domain is also the value used by System Settings. Absence means Match System.
public enum AppLanguage {
    public static func selection(in defaults: UserDefaults = .standard,
                                 domain: String = Bundle.main.bundleIdentifier ?? "",
                                 supported: [String] = ReaderLocalization.languages) -> String {
        guard let override = defaults.persistentDomain(forName: domain)?["AppleLanguages"] as? [String], !override.isEmpty else { return "" }
        return Bundle.preferredLocalizations(from: supported, forPreferences: override).first ?? "en"
    }
    public static func set(_ language: String, in defaults: UserDefaults = .standard) {
        if language.isEmpty { defaults.removeObject(forKey: "AppleLanguages") }
        else { defaults.set([language], forKey: "AppleLanguages") }
    }
}
