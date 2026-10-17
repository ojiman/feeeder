import Foundation
import Testing
@testable import ReaderCore

// Checks PRD-20 with a temporary app domain; no global or personal preferences are changed.
@Suite(EnglishLanguage()) @MainActor struct AppLanguageTests {
    @Test func selectionUsesOnlyTheAppsNativeOverrideAndCanReturnToTheSystem() throws {
        let domain = "unagi-language-test-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.register(defaults: ["AppleLanguages": ["ja"]])
        #expect(AppLanguage.selection(in: defaults, domain: domain, supported: ["en", "ja"]) == "")
        AppLanguage.set("ja", in: defaults)
        #expect(defaults.persistentDomain(forName: domain)?["AppleLanguages"] as? [String] == ["ja"])
        #expect(AppLanguage.selection(in: defaults, domain: domain, supported: ["en", "ja"]) == "ja")
        // The same key can be written by macOS outside the app.
        defaults.set(["en-GB"], forKey: "AppleLanguages")
        #expect(AppLanguage.selection(in: defaults, domain: domain, supported: ["en", "ja"]) == "en")
        AppLanguage.set("", in: defaults)
        #expect(defaults.persistentDomain(forName: domain)?["AppleLanguages"] == nil)
        #expect(AppLanguage.selection(in: defaults, domain: domain, supported: ["en", "ja"]) == "")
    }

    @Test func missingSourceMetadataStaysAbsentAcrossImportRefreshAndReopening() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let url = URL(string: "https://metadata.example/feed")!
        let xml = Data("<rss><channel><title>Source</title><item><guid>synthetic-no-title</guid><description>Body.</description></item></channel></rss>".utf8)
        let parsed = try FeedParser.parse(xml, sourceURL: url)
        #expect(parsed.entries.first?.title == "")
        let store = try ReaderStore(url: library.url)
        let feed = try store.importFeed(parsed)
        let article = try #require(store.articles.first)
        #expect(article.title.isEmpty && article.publisher.isEmpty)
        _ = try store.importFeed(FeedParser.parse(xml, sourceURL: url))
        #expect(store.feed(id: feed.id)?.title == "Source" && article.title.isEmpty && article.publisher.isEmpty)
        let reopened = try ReaderStore(url: library.url)
        #expect(reopened.articles.first?.title == "" && reopened.articles.first?.publisher == "")
    }

    @Test func presentationFallbacksNeverReplaceActualSourceWordsOrModifyTheModel() {
        let article = Article(feedID: UUID(), title: "", summary: "", publisher: "", publishedAt: .now)
        #expect(article.displayTitle == "Untitled" && article.displayPublisher == "Unknown site")
        #expect(article.title.isEmpty && article.publisher.isEmpty)
        article.title = "無題"; article.publisher = "掲載サイト不明"
        #expect(article.displayTitle == "無題" && article.displayPublisher == "掲載サイト不明")
    }

    @Test func bundledLocalizationsHaveEnglishSourceAndJapaneseResources() throws {
        #expect(Set(ReaderLocalization.languages).isSuperset(of: ["en", "ja"]))
        let japanese = try #require(ReaderLocalization.bundle.path(forResource: "ja", ofType: "lproj"))
        let bundle = try #require(Bundle(path: japanese))
        #expect(bundle.localizedString(forKey: "General", value: nil, table: nil) == "一般")
        #expect(bundle.localizedString(forKey: "An English fallback", value: nil, table: nil) == "An English fallback")
        #expect(String(localized: "General", bundle: ReaderLocalization.bundle) == "General")
    }
}

@Suite(EnglishLanguage()) struct CatalogTests {
    @Test func everyBundledLanguageIsCompleteAndKeepsTheSameArguments() throws {
        let url = try #require(ReaderLocalization.bundle.url(forResource: "Localizable", withExtension: "xcstrings"))
        let catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        #expect(catalog["sourceLanguage"] as? String == "en")
        let strings = try #require(catalog["strings"] as? [String: [String: Any]])
        let pattern = try NSRegularExpression(pattern: "%([0-9]+\\$)?(@|lld|ld|d|f)")
        func arguments(_ text: String) -> [String] {
            pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
                // Numbered arguments may be reordered by a translator.
                (text as NSString).substring(with: $0.range).replacingOccurrences(of: "%[0-9]+\\$", with: "%", options: .regularExpression)
            }.sorted()
        }
        func values(_ object: Any) -> [String] {
            guard let dictionary = object as? [String: Any] else { return [] }
            if let unit = dictionary["stringUnit"] as? [String: Any], let value = unit["value"] as? String { return [value] }
            return dictionary.values.flatMap(values)
        }
        for (key, entry) in strings {
            let translations = try #require(entry["localizations"] as? [String: Any])
            #expect(Set(translations.keys) == Set(ReaderLocalization.languages), "Incomplete: \(key)")
            for (language, translation) in translations {
                let forms = values(translation)
                #expect(!forms.isEmpty, "No text: \(language), \(key)")
                for value in forms {
                    #expect(!value.isEmpty && arguments(value) == arguments(key), "Arguments changed: \(language), \(key)")
                }
            }
        }
    }

    @Test func nativeMatchingHandlesRegionAndChineseScriptWithoutACustomMatcher() {
        let languages = ["en", "ja", "zh-Hans", "zh-Hant", "ko", "es", "pt-BR"]
        for (preferences, expected) in [(["zh-TW"], "zh-Hant"), (["zh-CN"], "zh-Hans"), (["pt-PT"], "pt-BR"), (["fr", "ja-JP"], "ja"), (["fr"], "en")] {
            #expect(Bundle.preferredLocalizations(from: languages, forPreferences: preferences).first == expected)
        }
    }
}
