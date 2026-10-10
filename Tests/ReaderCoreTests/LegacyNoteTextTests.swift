import Foundation
import Testing
@testable import ReaderCore

struct LegacyNoteTextTests {
    typealias Q = LegacyNoteText.Question
    typealias E = LegacyNoteText.Evidence
    private func compose(_ understanding: String = "", _ questions: [Q] = [], existing: String = "") -> String {
        LegacyNoteText.compose(existingNote: existing, understanding: understanding, questions: questions)
    }

    @Test func understandingThenAnsweredQuestionWithEvidence() {
        let question = Q(text: "問い", answer: "答え", evidence: [E(title: "タイトルA", url: "https://example.com/a"), E(title: "タイトルB", url: nil)])
        #expect(compose("いまの理解", [question]) ==
            "いまの理解\n\n# 問い\n\n答え\n\n根拠の記事:\n- タイトルA <https://example.com/a>\n- タイトルB\n")
    }
    @Test func understandingOnlyAndNothing() {
        #expect(compose("  \n理解だけ\n\n") == "理解だけ\n")
        #expect(compose("  \n ") == "")
        #expect(compose() == "")
    }
    @Test func anUnansweredQuestionStaysAsAHeading() {
        #expect(compose("", [Q(text: "答えのない問い", answer: " \n ", evidence: [])]) == "# 答えのない問い\n")
    }
    @Test func aQuestionWithLineBreaksKeepsItsFirstLineAsTheHeading() {
        #expect(compose("", [Q(text: "一行目\n二行目\n三行目", answer: "答え", evidence: [])]) == "# 一行目\n\n二行目\n三行目\n\n答え\n")
    }
    @Test func aQuestionThatStartsWithAHashIsKeptAsTyped() {
        #expect(compose("", [Q(text: "# 変な問い", answer: "", evidence: [])]) == "# # 変な問い\n")
    }
    @Test func anAnswerIsKeptByteForByteInsideAndTrimmedOnlyOfBlankLinesAtTheEnds() {
        let answer = "\n\n# 自分の見出し\r\n  行末に空白  \r\n本文\r\n\n"
        #expect(compose("", [Q(text: "問い", answer: answer, evidence: [])]) == "# 問い\n\n# 自分の見出し\r\n  行末に空白  \r\n本文\r\n")
        // The CR of the last kept line stays; the blank lines after it are dropped and the note ends with one line break.
    }
    @Test func aTitleWithLineBreaksBecomesOneListLine() {
        let question = Q(text: "問い", answer: "", evidence: [E(title: "二行の\nタイトル", url: "https://example.com")])
        #expect(compose("", [question]) == "# 問い\n\n根拠の記事:\n- 二行の タイトル <https://example.com>\n")
    }
    @Test func existingNoteComesFirstAndQuestionsKeepTheirOrder() {
        let questions = [Q(text: "先", answer: "", evidence: []), Q(text: "後", answer: "", evidence: [])]
        #expect(compose("理解", questions, existing: "\n既存\n") == "既存\n\n理解\n\n# 先\n\n# 後\n")
    }
    @Test func containsEverythingHoldsForComposedTextAndFailsWhenAPieceIsMissing() {
        let questions = [Q(text: "一行目\n二行目", answer: "答え", evidence: [E(title: "T\nU", url: "https://example.com/x")])]
        let note = compose("理解", questions)
        #expect(LegacyNoteText.containsEverything(note, understanding: "理解", questions: questions))
        for piece in ["理解", "一行目", "二行目", "答え", "T U", "https://example.com/x"] {
            let damaged = note.replacingOccurrences(of: piece, with: "")
            #expect(!LegacyNoteText.containsEverything(damaged, understanding: "理解", questions: questions), "\(piece)")
        }
    }

    @Test func textEndingInCarriageReturnsOrStartingWithACombiningMarkPassesTheCheck() {
        // The composed note joins a trailing CR with the line break after it into one Character (CRLF); the check must still find it.
        let cases: [(String, [Q])] = [
            ("", [Q(text: "問い", answer: "a\r\nb\r\n", evidence: [])]),
            ("理解\r\n", []),
            ("理解\r", []),
            ("", [Q(text: "問い", answer: "行末が改行だけのCR\r", evidence: [])]),
            ("", [Q(text: " \u{301}結合文字で始まる問い", answer: "", evidence: [])]),
        ]
        for (understanding, questions) in cases {
            let note = LegacyNoteText.compose(existingNote: "", understanding: understanding, questions: questions)
            #expect(LegacyNoteText.containsEverything(note, understanding: understanding, questions: questions), "\(understanding.debugDescription) \(questions)")
        }
    }
}
