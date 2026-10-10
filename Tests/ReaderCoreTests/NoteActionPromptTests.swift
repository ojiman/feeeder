import Foundation
import Testing
@testable import ReaderCore

struct NoteActionPromptTests {
    private func request(_ outcome: NoteActionPrompt.Outcome) -> (SuggestionPrompts.Request, Bool)? {
        if case .request(let request, let cut) = outcome { return (request, cut) } else { return nil }
    }

    @Test func clearerAcceptsExactlyTheLimitAndRefusesMoreOrNothing() throws {
        let exact = try #require(request(NoteActionPrompt.make(.clearer, text: String(repeating: "あ", count: 1_300), goal: "ゴール")))
        #expect(!exact.1 && exact.0.maximumTokens == 1_200)
        #expect(NoteActionPrompt.make(.clearer, text: String(repeating: "あ", count: 1_301), goal: "") == .tooLong)
        #expect(NoteActionPrompt.make(.clearer, text: " \n ", goal: "x") == .noText)
        #expect(NoteActionPrompt.make(.essence, text: "", goal: "x") == .noText)
    }

    @Test func clearerNeverSeesTheGoalAndItsInstructionsAreFixedText() throws {
        let made = try #require(request(NoteActionPrompt.make(.clearer, text: "本文です。", goal: "金利を学ぶ")))
        #expect(!made.0.prompt.contains("金利を学ぶ") && made.0.prompt == "文章:\n本文です。")
        let i = NoteActionPrompt.clearerInstructions
        #expect(i.count < 300 && i.contains("意味を変えずに") && i.contains("留保") && i.contains("一人称はそのまま") && i.contains("新しい情報を足しません"))
        #expect(i.contains("書き直した文章だけを出力"))
    }

    @Test func essenceUsesTheFirstLimitCharactersAndTheGoalWhenThereIsOne() throws {
        let long = try #require(request(NoteActionPrompt.make(.essence, text: String(repeating: "あ", count: 2_000), goal: "  金利と\n家計を学ぶ ")))
        #expect(long.1 && long.0.maximumTokens == 300)
        #expect(long.0.prompt == "学習ゴール: 金利と 家計を学ぶ\n文章:\n" + String(repeating: "あ", count: 1_300))
        let none = try #require(request(NoteActionPrompt.make(.essence, text: "短い。", goal: "  ")))
        #expect(!none.1 && none.0.prompt == "文章:\n短い。")
        let i = NoteActionPrompt.essenceInstructions
        #expect(i.count < 300 && i.contains("3行") && i.contains("書かれていることだけ") && i.contains("学習ゴール"))
    }

    @Test func theEssenceCutNeverSplitsACharacter() throws {
        let family = "👨‍👩‍👧"
        let text = String(repeating: "a", count: 1_299) + family + "後ろ"
        let made = try #require(request(NoteActionPrompt.make(.essence, text: text, goal: "")))
        #expect(made.1 && made.0.prompt == "文章:\n" + String(repeating: "a", count: 1_299) + family)
    }

    @Test func aRewriteIsCleanedWithoutTouchingItsInside() {
        #expect(NoteActionPrompt.clean("  「書き直した文章です。」\n", for: .clearer) == "書き直した文章です。")
        #expect(NoteActionPrompt.clean("一行目。\n\n二行目。", for: .clearer) == "一行目。\n\n二行目。")    // inner blank lines are the writer's
        #expect(NoteActionPrompt.clean("見え\u{200B}ない\u{0007}", for: .clearer) == "見えない")
        #expect(NoteActionPrompt.clean("家族👨‍👩‍👧", for: .clearer) == "家族👨‍👩‍👧")
        #expect(NoteActionPrompt.clean("「一つ目」と「二つ目」", for: .clearer) == "「一つ目」と「二つ目」")
        #expect(NoteActionPrompt.clean(" \u{200B}\n", for: .clearer) == nil)
    }

    @Test func theEssenceIsAtMostThreeBulletLines() {
        #expect(NoteActionPrompt.clean("1. 一つ目\n2) 二つ目\n3． 三つ目", for: .essence) == "・一つ目\n・二つ目\n・三つ目")
        #expect(NoteActionPrompt.clean("- 一つ目\n* 二つ目\n・三つ目\n\n・四つ目", for: .essence) == "・一つ目\n・二つ目\n・三つ目")
        #expect(NoteActionPrompt.clean("一つだけの長い文です。", for: .essence) == "・一つだけの長い文です。")
        #expect(NoteActionPrompt.clean("  \n・\n-", for: .essence) == nil)
        #expect(NoteActionPrompt.clean("", for: .essence) == nil)
    }
}
