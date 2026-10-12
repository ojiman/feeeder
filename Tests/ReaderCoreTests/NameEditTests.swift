import Testing
@testable import ReaderCore

/// What a name typed into a sidebar row means (decision 0043).
struct NameEditTests {
    @Test func aChangedNameIsTheResultAndEverythingElseChangesNothing() {
        #expect(NameEdit.result(old: "金利", typed: " 新しい名前 ") == "新しい名前")              // trimmed like every name
        #expect(NameEdit.result(old: "金利", typed: "金利") == nil)                              // unchanged: nothing to save
        #expect(NameEdit.result(old: "金利", typed: "  金利 ") == nil)
        #expect(NameEdit.result(old: "金利", typed: "") == nil)                                  // an empty name keeps the old one
        #expect(NameEdit.result(old: "金利", typed: " \n ") == nil)
        #expect(NameEdit.result(old: "金利", typed: nil) == nil)                                 // Esc
    }
    @Test func anUntitledNoteStartsEmptyAndTakesAnyName() {
        #expect(NameEdit.result(old: "", typed: "最初の名前") == "最初の名前")
        #expect(NameEdit.result(old: "", typed: "") == nil)
    }
    @Test func lineBreaksBecomeOneSpace() {
        #expect(NameEdit.result(old: "a", typed: "二行\n目") == "二行 目")
    }
    @Test func theNameOfTheRowIsWhatTheFieldStartsWith() {
        #expect(NameEdit.initialText(forNoteTitle: "金利") == "金利")
        #expect(NameEdit.initialText(forNoteTitle: NoteTitle.untitled) == "")                  // 「新規ノート」 is a label, not a name
    }
}
