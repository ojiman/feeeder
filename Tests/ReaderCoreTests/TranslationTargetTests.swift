import Foundation
import Testing
@testable import ReaderCore

// Checks PRD-18.
struct TranslationTargetTests {
    @Test func systemUsesPreferenceOrderAndIgnoresRegion() {
        #expect(TranslationTarget.resolve(stored: "", preferred: ["fr-FR", "ja-JP", "en-US"], supported: ["en", "ja"]) == "ja")
        #expect(TranslationTarget.resolve(stored: "", preferred: ["pt-PT"], supported: ["en", "pt-BR"]) == "pt-BR")
    }
    @Test func systemKeepsChineseScriptsDistinct() {
        #expect(TranslationTarget.resolve(stored: "", preferred: ["zh-TW"], supported: ["zh-Hans", "zh-Hant", "en"]) == "zh-Hant")
        #expect(TranslationTarget.resolve(stored: "", preferred: ["zh-CN"], supported: ["zh-Hant", "en"]) == "en")
    }
    @Test func systemFollowsChangedPreferencesAndFallsBackToEnglish() {
        #expect(TranslationTarget.resolve(stored: "", preferred: ["ja"], supported: ["ja", "en"]) == "ja")
        #expect(TranslationTarget.resolve(stored: "", preferred: ["en-GB"], supported: ["ja", "en"]) == "en")
        #expect(TranslationTarget.resolve(stored: "", preferred: ["xx"], supported: ["ja", "en"]) == "en")
    }
    @Test func manualTargetSurvivesPreferenceAndAvailabilityChanges() {
        #expect(TranslationTarget.resolve(stored: "ko", preferred: ["en"], supported: ["en", "ja"]) == "ko")
        #expect(TranslationTarget.resolve(stored: "ja", preferred: ["en"], supported: ["en", "ja"]) == "ja")
    }
}
