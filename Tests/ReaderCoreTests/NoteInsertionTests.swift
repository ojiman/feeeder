import Testing
@testable import ReaderCore

struct NoteInsertionTests {
    @Test func theBlockHasASourceLineWhenThereIsATitleOrALink() {
        #expect(NoteInsertion.summaryBlock(summary: " 要約。 ", title: "二行の\nタイトル", url: "https://example.com/a") == "要約。\n出典: 二行の タイトル <https://example.com/a>")
        #expect(NoteInsertion.summaryBlock(summary: "要約。", title: "T", url: nil) == "要約。\n出典: T")
        #expect(NoteInsertion.summaryBlock(summary: "要約。", title: " ", url: "https://example.com") == "要約。\n出典: https://example.com")
        #expect(NoteInsertion.summaryBlock(summary: "要約。", title: "", url: nil) == "要約。")
    }


}

extension NoteInsertionTests {
    @Test func sendingMarksOnlyAIAndDoesNotAddAnEmptySummaryLine() {
        #expect(NoteInsertion.summaryBlock(summary: "要約", title: "二行\nの題", url: "https://example.com", aiMade: true) == "要約\n出典: 二行 の題 <https://example.com>（AI要約）")
        #expect(NoteInsertion.summaryBlock(summary: "", title: "題", url: nil, aiMade: false) == "出典: 題")
        #expect(NoteInsertion.summaryBlock(summary: "要約", title: "", url: nil, aiMade: false) == "要約")
    }
    @Test func sendingCreatesAHeadingAndAppendsWithoutRewritingTheNote() {
        #expect(NoteInsertion.newNoteText(title: "題", block: "要約\n出典: 題") == "# 題\n\n要約\n出典: 題\n")
        #expect(NoteInsertion.newNoteText(title: " ## ", block: "出典") == "# 無題の記事\n\n出典\n")
        for before in ["既存", "既存\n", "既存\n\n"] {
            #expect(NoteInsertion.appended(block: "要約", to: before) == "既存\n\n要約\n")
        }
        #expect(NoteInsertion.appended(block: "要約", to: "") == "要約\n")
        #expect(NoteInsertion.appended(block: "要約\n出典", to: "既存\r\n") == "既存\r\n\r\n要約\r\n出典\r\n")
        let long = String(repeating: "line\n", count: 100_000)
        #expect(NoteInsertion.appended(block: "end", to: long) == long + "\nend\n")
    }
}
