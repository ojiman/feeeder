import Foundation
import Testing
@testable import ReaderCore

struct SummarySettingsTests {
    @Test func settingsValidateStoredValuesAndKeepWholeCharacters() {
        let name = "summary-test-" + UUID().uuidString
        let d = UserDefaults(suiteName: name)!
        defer { d.removePersistentDomain(forName: name) }
        #expect(SummarySettings.load(from: d) == SummarySettings())
        d.set("wrong", forKey: SummarySettings.lengthKey)
        d.set(99, forKey: SummarySettings.formatKey)
        #expect(SummarySettings.load(from: d) == SummarySettings())
        d.set(true, forKey: SummarySettings.lengthKey)
        #expect(SummarySettings.load(from: d).length == .three)
        d.set(1.5, forKey: SummarySettings.lengthKey)
        #expect(SummarySettings.load(from: d).length == .three)
        d.set(5, forKey: SummarySettings.lengthKey)
        d.set("bullets", forKey: SummarySettings.formatKey)
        #expect(SummarySettings.load(from: d).length == .five && SummarySettings.load(from: d).format == .bullets)
        let emoji = "👨‍👩‍👧"
        let value = SummarySettings(extraInstruction: "  line\r\nnext " + String(repeating: emoji, count: 220))
        #expect(value.extraInstruction.hasPrefix("line next "))
        #expect(value.extraInstruction.count == 200)
        #expect(value.extraInstruction.last == Character(emoji))
    }
    @Test func settingsStayInInstructionsAndArticleTextStaysInThePrompt() throws {
        for length in SummaryLength.allCases {
            let input = try #require(ArticleSummaryPrompt.make(title: "T", text: "HOSTILE ARTICLE", settings: SummarySettings(length: length, format: .bullets, extraInstruction: "自分の指示")))
            #expect(input.request.instructions.contains("\(length.rawValue)文"))
            #expect(input.request.instructions.contains("本人の言葉: 自分の指示"))
            #expect(!input.request.instructions.contains("HOSTILE ARTICLE"))
            #expect(input.request.prompt.contains("HOSTILE ARTICLE"))
        }
        #expect(ArticleSummaryPrompt.clean("• 一\n\n2. 二\n- 三", format: .bullets) == "- 一\n- 二\n- 三")
        #expect(ArticleSummaryPrompt.clean(String(repeating: "あ", count: 2000), format: .bullets)?.count == 1200)
    }
}
