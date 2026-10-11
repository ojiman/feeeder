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

    @Test func renamingChangesOnlyTheTitleLineAndKeepsItsMarks() {
        #expect(NoteTitle.renamed("# 金利\n本文", to: "新しい名前") == "# 新しい名前\n本文")
        #expect(NoteTitle.renamed("## 小見出し\nx", to: "新") == "## 新\nx")                   // the heading level stays
        #expect(NoteTitle.renamed("plain\nsecond", to: "新") == "新\nsecond")                   // a plain first line stays plain
        #expect(NoteTitle.renamed("\n\n# A\n# B", to: "新") == "\n\n# 新\n# B")                // blank lines before it stay
        #expect(NoteTitle.renamed("# Rates\r\nbody\r\n", to: "新") == "# 新\r\nbody\r\n")      // the line ending stays
        #expect(NoteTitle.renamed("# 😀 e\u{301}\nbody", to: "新") == "# 新\nbody")
        #expect(NoteTitle.make(from: NoteTitle.renamed("# 金利\n本文", to: "新しい名前") ?? "") == "新しい名前")
    }
    @Test func renamingANoteWithoutATitleMakesTheNameItsHeading() {
        #expect(NoteTitle.renamed("", to: "新") == "# 新")
        #expect(NoteTitle.renamed("#\n##\n", to: "新") == "# 新\n#\n##\n")                    // only marks: the name goes in front
        #expect(NoteTitle.renamed("\n\n", to: "新") == "# 新\n\n\n")
    }
    @Test func theNewNameIsTrimmedAndAnEmptyNameChangesNothing() {
        #expect(NoteTitle.renamed("# A", to: "  新 \n") == "# 新")
        #expect(NoteTitle.renamed("# A", to: "   ") == nil)
        #expect(NoteTitle.renamed("# A", to: "") == nil)
    }
}
