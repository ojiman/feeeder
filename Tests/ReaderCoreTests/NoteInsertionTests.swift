import Testing
@testable import ReaderCore

struct NoteInsertionTests {
    private func insert(_ note: String, at offset: Int, block: String = "要約。\n出典: T") -> (String, Int) {
        let result = NoteInsertion.insert(block, into: note, atCharacterOffset: offset)
        return (result.note, result.cursorOffset)
    }

    @Test func theBlockHasASourceLineWhenThereIsATitleOrALink() {
        #expect(NoteInsertion.summaryBlock(summary: " 要約。 ", title: "二行の\nタイトル", url: "https://example.com/a") == "要約。\n出典: 二行の タイトル <https://example.com/a>")
        #expect(NoteInsertion.summaryBlock(summary: "要約。", title: "T", url: nil) == "要約。\n出典: T")
        #expect(NoteInsertion.summaryBlock(summary: "要約。", title: " ", url: "https://example.com") == "要約。\n出典: https://example.com")
        #expect(NoteInsertion.summaryBlock(summary: "要約。", title: "", url: nil) == "要約。")
    }

    @Test func anEmptyNoteBecomesTheBlock() {
        let (note, cursor) = insert("", at: 0)
        #expect(note == "要約。\n出典: T\n" && cursor == "要約。\n出典: T".count)
        #expect(insert("", at: 99).0 == "要約。\n出典: T\n")                              // out of range is clamped
        #expect(insert("", at: -5).0 == "要約。\n出典: T\n")
    }

    @Test func atTheStartTheBlockComesFirstThenABlankLineThenTheText() {
        #expect(insert("既存のノート", at: 0).0 == "要約。\n出典: T\n\n既存のノート")
    }

    @Test func atTheEndTheBlockFollowsAfterABlankLine() {
        #expect(insert("既存", at: 2).0 == "既存\n\n要約。\n出典: T\n")                    // no trailing line break in the note
        #expect(insert("既存\n", at: 3).0 == "既存\n\n要約。\n出典: T\n")                  // one line break: one more is added
        #expect(insert("既存\n\n", at: 4).0 == "既存\n\n要約。\n出典: T\n")                // already a blank line: none is added
    }

    @Test func inTheMiddleOfALineTheTextAroundIsSeparatedAndNeverChanged() {
        let (note, cursor) = insert("前半後半", at: 2)
        #expect(note == "前半\n\n要約。\n出典: T\n\n後半")
        #expect(cursor == "前半\n\n要約。\n出典: T".count)
        #expect(insert("一行目\n二行目", at: 3).0 == "一行目\n\n要約。\n出典: T\n\n二行目")        // at the end of the first line
        #expect(insert("一行目\n\n二行目", at: 3).0 == "一行目\n\n要約。\n出典: T\n\n二行目")    // before an existing blank line: not doubled
    }

    @Test func crlfNotesKeepTheirLineBreakStyle() {
        let (note, _) = insert("一行目\r\n二行目", at: 3)
        #expect(note == "一行目\r\n\r\n要約。\r\n出典: T\r\n\r\n二行目")
        #expect(!note.contains("\r\n\n") && note.replacingOccurrences(of: "\r\n", with: "").contains("\n") == false)
    }

    @Test func emojiAndCombiningMarksAreNotSplitAndTheOffsetCountsCharacters() {
        let family = "👨‍👩‍👧"
        let note = "a" + family + "e\u{301}b"                                              // 4 characters
        let (inserted, _) = insert(note, at: 2)                                            // after the family emoji
        #expect(inserted == "a" + family + "\n\n要約。\n出典: T\n\ne\u{301}b")
        #expect(insert(note, at: 3).0 == "a" + family + "e\u{301}" + "\n\n要約。\n出典: T\n\nb")
    }

    @Test func theCursorIsRightAfterTheBlockInTheNewText() {
        let (note, cursor) = insert("前半後半", at: 2)
        let index = note.index(note.startIndex, offsetBy: cursor)
        #expect(String(note[..<index]).hasSuffix("出典: T") && note[index...].hasPrefix("\n\n後半"))
    }

    @Test func adoptingUsesTheEndOfTheSelectionAndTheEndOfTheNoteWithoutOne() {
        let note = "前半後半"
        let utf16Two = note.prefix(2).utf16.count
        #expect(NoteInsertion.adopted(summary: "要約", title: "T", url: nil, into: note, selectionEndUTF16: utf16Two).note == "前半\n\n要約\n出典: T\n\n後半")
        #expect(NoteInsertion.adopted(summary: "要約", title: "T", url: nil, into: note, selectionEndUTF16: nil).note == "前半後半\n\n要約\n出典: T\n")
        #expect(NoteInsertion.adopted(summary: "要約", title: "T", url: nil, into: note, selectionEndUTF16: 999).note == "前半後半\n\n要約\n出典: T\n")
        // An emoji is two UTF-16 units: an offset inside it is not a split point.
        let emoji = "a😀b"
        let inside = NoteInsertion.adopted(summary: "要約", title: "T", url: nil, into: emoji, selectionEndUTF16: 2)
        #expect(inside.note.hasPrefix("a") && inside.note.contains("😀") && inside.note.hasSuffix("b"))
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
