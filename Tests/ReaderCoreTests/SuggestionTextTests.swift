import Foundation
import Testing
@testable import ReaderCore

struct SuggestionTextTests {
    @Test func aCleanNameIsKeptAndWrappingMarksAreRemoved() {
        #expect(SuggestionText.name(from: "金利と家計") == "金利と家計")
        #expect(SuggestionText.name(from: "  「住宅ローンの金利変動と家計の負担」\n") == "住宅ローンの金利変動と家計の負担")
        #expect(SuggestionText.name(from: "テーマ名: 睡眠習慣と体内時計。") == "睡眠習慣と体内時計")
        #expect(SuggestionText.name(from: "1. 小型AIモデルの端末内推論") == "小型AIモデルの端末内推論")
        #expect(SuggestionText.name(from: "- AI（端末内）の推論") == "AI（端末内）の推論")
    }

    @Test func junkAfterTheNameIsCutAndUnusableNamesAreRejected() {
        #expect(SuggestionText.name(from: "睡眠」}」この記事は睡眠について書かれています") == "睡眠")    // spike §2: text after 」}」
        #expect(SuggestionText.name(from: "金利と家計\nこのテーマは、金利が家計に与える影響を扱います。") == "金利と家計")
        #expect(SuggestionText.name(from: "") == nil)
        #expect(SuggestionText.name(from: " \n ") == nil)
        #expect(SuggestionText.name(from: "。") == nil)
        #expect(SuggestionText.name(from: "あ") == nil)                                          // too short
        #expect(SuggestionText.name(from: String(repeating: "あ", count: 25)) == nil)            // too long
        #expect(SuggestionText.name(from: "{\"name\": \"金利\"}") == nil)
    }

    @Test func aQuestionMustBeAQuestionOnOneLineWithinTheLength() {
        #expect(SuggestionText.question(from: "預金金利の上昇で家計の貯蓄行動はどう変わるか") == "預金金利の上昇で家計の貯蓄行動はどう変わるか。")
        #expect(SuggestionText.question(from: "「住宅ローンを変動金利型で組んでいると、返済負担は増えるだろうか。」") == "住宅ローンを変動金利型で組んでいると、返済負担は増えるだろうか。")
        #expect(SuggestionText.question(from: "1. 朝の光を浴びる時間は、睡眠の質にどう影響するのか？\n補足の説明です。") == "朝の光を浴びる時間は、睡眠の質にどう影響するのか？")
        #expect(SuggestionText.question(from: "How does sleep affect memory in daily life?") == "How does sleep affect memory in daily life?")
    }

    @Test func statementsTooShortTooLongAndBlankQuestionsAreRejected() {
        #expect(SuggestionText.question(from: "夜の睡眠の質は、朝の光を浴びることで向上する。") == nil)      // a statement
        #expect(SuggestionText.question(from: "なぜか") == nil)                                       // too short
        #expect(SuggestionText.question(from: String(repeating: "あ", count: 80) + "か。") == nil)     // too long
        #expect(SuggestionText.question(from: "") == nil)
        #expect(SuggestionText.question(from: "{\"q\": \"どうなるか\"}") == nil)
    }

    @Test func aFixedLensQuestionPassesThroughUnchanged() {
        // The model may repeat the template; it must still be recognised as the template, not mangled by the quote handling.
        for lens in QuestionLens.allCases where lens != .custom {
            let template = lens.draft(themeName: "金利と家計")
            #expect(SuggestionText.question(from: template) == template)
        }
    }

    @Test func promptsKeepTheNewestItemsAndCutTheirLength() {
        let items = (0..<40).map { SuggestionItem(id: UUID(), text: "記事 \($0)\n" + String(repeating: "あ", count: 400)) }
        let request = SuggestionPrompts.name(items: items)
        let lines = request.prompt.split(separator: "\n").filter { $0.hasPrefix("- ") }
        #expect(lines.count == SuggestionPrompts.maximumItems)
        #expect(lines.first?.hasPrefix("- 記事 0 ") == true && lines.last?.hasPrefix("- 記事 15 ") == true)   // input is newest first
        #expect(lines.allSatisfy { $0.count <= SuggestionPrompts.itemTextLimit + 2 })                      // "- " + text
        #expect(!request.prompt.contains("記事 16"))
        #expect(request.maximumTokens == SuggestionPrompts.nameTokenLimit && request.instructions.contains("名前だけ"))
    }

    @Test func aQuestionPromptCarriesTheAngleTheTemplateAndTheThemeName() throws {
        let items = [SuggestionItem(id: UUID(), text: "金利が上がる\n家計の返済負担が増える")]
        let template = QuestionLens.tradeoff.draft(themeName: "金利と家計")
        let request = try #require(SuggestionPrompts.question(lens: .tradeoff, template: template, themeName: "金利と家計", items: items))
        #expect(request.prompt.contains("金利と家計") && request.prompt.contains(template) && request.prompt.contains("手放して"))
        #expect(request.prompt.contains("- 金利が上がる 家計の返済負担が増える"))               // newline inside an item becomes a space
        #expect(request.maximumTokens == SuggestionPrompts.questionTokenLimit && request.instructions.contains("疑問文"))
        #expect(SuggestionPrompts.question(lens: .custom, template: "", themeName: "A", items: items) == nil)
    }

    @Test func onlyAnUneditedTemplateOfAFixedLensIsEligible() {
        let template = QuestionLens.assumption.draft(themeName: "金利と家計")
        #expect(QuestionProposalEligibility.isEligible(lens: .assumption, text: template, themeName: "金利と家計"))
        #expect(QuestionProposalEligibility.isEligible(lens: .assumption, text: "  " + template + "\n", themeName: " 金利と家計 "))
        #expect(!QuestionProposalEligibility.isEligible(lens: .assumption, text: template + "追記", themeName: "金利と家計"))
        #expect(!QuestionProposalEligibility.isEligible(lens: .assumption, text: template, themeName: "改名後"))
        #expect(!QuestionProposalEligibility.isEligible(lens: .custom, text: "", themeName: "A"))
        #expect(!QuestionProposalEligibility.isEligible(lens: .custom, text: "自由な問い", themeName: "A"))
    }

    @Test func namesKeepNumbersApostrophesAndStripMarkdownAndControlCharacters() {
        #expect(SuggestionText.name(from: "3.11と防災の備え") == "3.11と防災の備え")            // "3." is not a list mark
        #expect(SuggestionText.name(from: "2. 防災の備え") == "防災の備え")
        #expect(SuggestionText.name(from: "Apple's AI strategy") == "Apple's AI strategy")
        #expect(SuggestionText.name(from: "**金利と家計**") == "金利と家計")
        #expect(SuggestionText.name(from: "【金利と家計】") == "金利と家計")
        #expect(SuggestionText.name(from: "金利と\u{202E}家計") == "金利と家計")                     // bidi / control characters are dropped
        #expect(SuggestionText.question(from: "1. 問い: 金利が上がると家計はどう変わるのか。") == "金利が上がると家計はどう変わるのか。")
    }
}
