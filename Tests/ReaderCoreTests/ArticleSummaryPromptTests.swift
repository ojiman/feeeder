import Foundation
import Testing
@testable import ReaderCore

struct ArticleSummaryPromptTests {
    private func body(of input: ArticleSummaryPrompt.Input) -> String {
        let prompt = input.request.prompt
        return String(prompt[prompt.range(of: "本文:\n")!.upperBound...])
    }

    @Test func aShortBodyIsKeptWholeWithTheTitleAndTheCap() throws {
        let input = try #require(ArticleSummaryPrompt.make(title: "日銀が利上げ", text: "本文です。"))
        #expect(!input.wasCut && body(of: input) == "本文です。")
        #expect(input.request.prompt.hasPrefix("タイトル: 日銀が利上げ\n"))
        #expect(input.request.maximumTokens == 400 && input.request.instructions == ArticleSummaryPrompt.instructions)
    }

    @Test func theBodyIsCutAtExactlyTheLimitInCharacters() throws {
        let exact = try #require(ArticleSummaryPrompt.make(title: "T", text: String(repeating: "あ", count: 3_000)))
        #expect(!exact.wasCut && body(of: exact).count == 3_000)
        for length in [3_001, 10_000] {
            let cut = try #require(ArticleSummaryPrompt.make(title: "T", text: String(repeating: "あ", count: length)))
            #expect(cut.wasCut && body(of: cut) == String(repeating: "あ", count: 3_000))
        }
    }

    @Test func theCutNeverSplitsACharacter() throws {
        let family = "👨‍👩‍👧"                                                       // one Character, many scalars
        let text = String(repeating: "a", count: 2_999) + family + "後ろの文章"
        let input = try #require(ArticleSummaryPrompt.make(title: "T", text: text))
        #expect(input.wasCut && body(of: input) == String(repeating: "a", count: 2_999) + family)
        let combining = String(repeating: "a", count: 2_999) + "e\u{301}" + "続き"        // e + combining acute
        let second = try #require(ArticleSummaryPrompt.make(title: "T", text: combining))
        #expect(body(of: second).hasSuffix("e\u{301}") && body(of: second).count == 3_000)
        let crlf = String(repeating: "a", count: 2_999) + "\r\n" + "続き"
        let third = try #require(ArticleSummaryPrompt.make(title: "T", text: crlf))
        #expect(body(of: third).count == 3_000 && body(of: third).hasSuffix("\r\n"))
    }

    @Test func blankTextGivesNoRequestAndATitleIsOptional() throws {
        #expect(ArticleSummaryPrompt.make(title: "T", text: " \n\t ") == nil)
        #expect(ArticleSummaryPrompt.make(title: "T", text: "") == nil)
        #expect(try #require(ArticleSummaryPrompt.make(title: "  ", text: "本文")).request.prompt.hasPrefix("タイトル: \n"))
        #expect(try #require(ArticleSummaryPrompt.make(title: "二行の\nタイトル", text: "本文")).request.prompt.hasPrefix("タイトル: 二行の タイトル\n"))
    }

    @Test func theInstructionsAreFixedText() {
        #expect(ArticleSummaryPrompt.instructions.contains("3文以内") && ArticleSummaryPrompt.instructions.contains("記事に書かれていることだけ"))
        #expect(ArticleSummaryPrompt.instructions.contains("強めたり逆にしたりしません") && ArticleSummaryPrompt.instructions.contains("数字はそのまま"))
        #expect(ArticleSummaryPrompt.instructions.count < 300)                         // decision 0013: instructions stay small
    }

    @Test func theAnswerIsMadeSafeToShow() {
        #expect(ArticleSummaryPrompt.clean("  「要約です。」 \n") == "要約です。")
        #expect(ArticleSummaryPrompt.clean("一文目。\n\n二文目。") == "一文目。\n二文目。")
        #expect(ArticleSummaryPrompt.clean("見え\u{200B}ない\u{0007}文字") == "見えない文字")
        #expect(ArticleSummaryPrompt.clean("「一つ目」と「二つ目」") == "「一つ目」と「二つ目」")       // not one wrapping pair
        #expect(ArticleSummaryPrompt.clean(" \n\u{200B} ") == nil && ArticleSummaryPrompt.clean("") == nil)
        #expect(ArticleSummaryPrompt.clean(String(repeating: "あ", count: 2_000))?.count == 1_200)
    }
}
