import Foundation
import Testing
@testable import ReaderCore

struct NoteTitleTests {
    @Test func theTitleIsTheFirstNonEmptyLineWithoutItsLeadingMarks() {
        #expect(NoteTitle.make(from: "# 金利 の話\n本文") == "金利 の話")
        #expect(NoteTitle.make(from: "## 小見出し") == "小見出し")
        #expect(NoteTitle.make(from: "###   spaced  ") == "spaced")
        #expect(NoteTitle.make(from: "plain first line\nsecond") == "plain first line")
        #expect(NoteTitle.make(from: "\n\n  \n# A\n# B") == "A")                         // blank lines are skipped
    }

    @Test func anEmptyNoteOrOneOfMarksAndSpacesIsNamedNewNote() {
        for text in ["", " ", "\n\n", " \t\n ", "#", "###", "# #", "#\n##\n", "\u{3000}\n"] {
            #expect(NoteTitle.make(from: text) == NoteTitle.untitled, "text: \(text.debugDescription)")
        }
        #expect(NoteTitle.untitled == "新規ノート")
    }

    @Test func lineEndingsAndUnicodeAreHandledAsTheyAre() {
        #expect(NoteTitle.make(from: "# Rates\r\nbody\r\n") == "Rates")                  // CRLF
        #expect(NoteTitle.make(from: "# Rates\rbody") == "Rates")                        // CR
        #expect(NoteTitle.make(from: "# Rates\u{2028}body") == "Rates")                  // line separator
        #expect(NoteTitle.make(from: "# 😀 e\u{301}") == "😀 e\u{301}")                  // emoji and combining marks stay whole
        #expect(NoteTitle.make(from: "#タイトル") == "タイトル")                           // no space after the mark
    }

    @Test func aVeryLongFirstLineIsReturnedWholeAndNeverCutInsideACharacter() {
        let long = String(repeating: "👨‍👩‍👧", count: 10_000)
        #expect(NoteTitle.make(from: "# " + long + "\nrest") == long)
    }

    @Test func aMarkNotAtTheStartIsKept() {
        #expect(NoteTitle.make(from: "C# in depth") == "C# in depth")
        #expect(NoteTitle.make(from: "Issue #12") == "Issue #12")
    }
}
