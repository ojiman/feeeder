import Foundation
import Testing
@testable import ReaderCore

struct NotePickerTests {
    let finance = UUID(), llm = UUID()
    var notes: [(id: UUID, name: String)] { [(finance, "金利と家計"), (llm, "LLMの実用設計")] }

    @Test func emptyQueryListsEveryNoteWithItsMembershipAndNoCreateRow() {
        let rows = NotePicker.rows(notes: notes, memberOf: [llm], query: "")
        #expect(rows.map(\.title) == ["金利と家計", "LLMの実用設計"])
        #expect(rows.map(\.included) == [false, true])
        #expect(rows.allSatisfy { if case .note = $0.kind { true } else { false } })
        #expect(NotePicker.rows(notes: notes, memberOf: [], query: " \n ").count == 2)
    }

    @Test func queryFiltersAndOffersCreationOnlyWithoutAnExactMatch() {
        let partial = NotePicker.rows(notes: notes, memberOf: [], query: " llm ")
        #expect(partial.map(\.kind) == [.note(llm), .create("llm")])
        #expect(partial[1].title == "「llm」を新しいノートとして作る")
        let exact = NotePicker.rows(notes: notes, memberOf: [], query: "llmの実用設計")
        #expect(exact.map(\.kind) == [.note(llm)])
        let none = NotePicker.rows(notes: notes, memberOf: [], query: "宇宙")
        #expect(none.map(\.kind) == [.create("宇宙")])
        #expect(NotePicker.rows(notes: [], memberOf: [], query: "").isEmpty)
    }

    @Test func highlightPrefersTheExactMatchThenTheFirstRow() {
        func highlight(_ query: String) -> Int? {
            NotePicker.defaultHighlight(rows: NotePicker.rows(notes: notes, memberOf: [], query: query), query: query)
        }
        #expect(highlight("") == 0)
        #expect(highlight("金利と家計") == 0)
        #expect(highlight("llm") == 0)          // a partial match selects the existing note, not a duplicate
        #expect(highlight("宇宙") == 0)          // nothing matches: the create row is the only row
        #expect(NotePicker.defaultHighlight(rows: [], query: "") == nil)
        let both = [(finance, "LLM"), (llm, "LLMの実用設計")]
        let rows = NotePicker.rows(notes: both, memberOf: [], query: "LLMの実用設計")
        #expect(NotePicker.defaultHighlight(rows: rows, query: "LLMの実用設計") == 0)
        let reversed = NotePicker.rows(notes: [(llm, "LLMの実用設計"), (finance, "LLM")], memberOf: [], query: "LLM")
        #expect(NotePicker.defaultHighlight(rows: reversed, query: "LLM") == 1)   // the exact name wins over an earlier partial
    }

    @Test func movingClampsAndStartsFromTheEnds() {
        #expect(NotePicker.move(nil, by: 1, count: 3) == 0)
        #expect(NotePicker.move(nil, by: -1, count: 3) == 2)
        #expect(NotePicker.move(0, by: -1, count: 3) == 0)
        #expect(NotePicker.move(2, by: 1, count: 3) == 2)
        #expect(NotePicker.move(1, by: 1, count: 3) == 2)
        #expect(NotePicker.move(0, by: 1, count: 0) == nil)
    }

    @Test func activatingTheHighlightedRowMapsToTheRightAction() {
        let rows = NotePicker.rows(notes: notes, memberOf: [], query: "llm")
        #expect(NotePicker.action(rows: rows, highlighted: 0) == .toggle(llm))
        #expect(NotePicker.action(rows: rows, highlighted: 1) == .create("llm"))
        #expect(NotePicker.action(rows: rows, highlighted: nil) == nil)
        #expect(NotePicker.action(rows: rows, highlighted: 5) == nil)
    }

    @Test func commandReturnCreatesWithTheTypedNameUnlessItAlreadyExists() {
        func explicit(_ query: String) -> NotePickerAction? {
            NotePicker.explicitAction(rows: NotePicker.rows(notes: notes, memberOf: [], query: query), query: query)
        }
        #expect(explicit("llm") == .create("llm"))            // partial matches exist, but the person asked for this name
        #expect(explicit("宇宙") == .create("宇宙"))
        #expect(explicit("LLMの実用設計") == .toggle(llm))      // exact name: never a duplicate
        #expect(explicit("") == nil && explicit("  ") == nil)
    }

    @Test func rowsKeepTheNoteOrderAndTheFirstRowIsHighlighted() {
        let rows = NotePicker.rows(notes: notes, memberOf: [llm], query: "")
        #expect(rows.map(\.kind) == notes.map { .note($0.id) })                       // the order of the notes, nothing reordered
        #expect(rows.map(\.included) == notes.map { $0.id == llm })
        #expect(NotePicker.defaultHighlight(rows: rows, query: "") == 0)
    }
}
