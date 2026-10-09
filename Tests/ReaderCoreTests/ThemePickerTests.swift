import Foundation
import Testing
@testable import ReaderCore

struct ThemePickerTests {
    let finance = UUID(), llm = UUID()
    var themes: [(id: UUID, name: String)] { [(finance, "金利と家計"), (llm, "LLMの実用設計")] }

    @Test func emptyQueryListsEveryThemeWithItsMembershipAndNoCreateRow() {
        let rows = ThemePicker.rows(themes: themes, memberOf: [llm], query: "")
        #expect(rows.map(\.title) == ["金利と家計", "LLMの実用設計"])
        #expect(rows.map(\.included) == [false, true])
        #expect(rows.allSatisfy { if case .theme = $0.kind { true } else { false } })
        #expect(ThemePicker.rows(themes: themes, memberOf: [], query: " \n ").count == 2)
    }

    @Test func queryFiltersAndOffersCreationOnlyWithoutAnExactMatch() {
        let partial = ThemePicker.rows(themes: themes, memberOf: [], query: " llm ")
        #expect(partial.map(\.kind) == [.theme(llm), .create("llm")])
        #expect(partial[1].title == "「llm」を新しいテーマとして作る")
        let exact = ThemePicker.rows(themes: themes, memberOf: [], query: "llmの実用設計")
        #expect(exact.map(\.kind) == [.theme(llm)])
        let none = ThemePicker.rows(themes: themes, memberOf: [], query: "宇宙")
        #expect(none.map(\.kind) == [.create("宇宙")])
        #expect(ThemePicker.rows(themes: [], memberOf: [], query: "").isEmpty)
    }

    @Test func highlightPrefersTheExactMatchThenTheFirstRow() {
        func highlight(_ query: String) -> Int? {
            ThemePicker.defaultHighlight(rows: ThemePicker.rows(themes: themes, memberOf: [], query: query), query: query)
        }
        #expect(highlight("") == 0)
        #expect(highlight("金利と家計") == 0)
        #expect(highlight("llm") == 0)          // a partial match selects the existing theme, not a duplicate
        #expect(highlight("宇宙") == 0)          // nothing matches: the create row is the only row
        #expect(ThemePicker.defaultHighlight(rows: [], query: "") == nil)
        let both = [(finance, "LLM"), (llm, "LLMの実用設計")]
        let rows = ThemePicker.rows(themes: both, memberOf: [], query: "LLMの実用設計")
        #expect(ThemePicker.defaultHighlight(rows: rows, query: "LLMの実用設計") == 0)
        let reversed = ThemePicker.rows(themes: [(llm, "LLMの実用設計"), (finance, "LLM")], memberOf: [], query: "LLM")
        #expect(ThemePicker.defaultHighlight(rows: reversed, query: "LLM") == 1)   // the exact name wins over an earlier partial
    }

    @Test func movingClampsAndStartsFromTheEnds() {
        #expect(ThemePicker.move(nil, by: 1, count: 3) == 0)
        #expect(ThemePicker.move(nil, by: -1, count: 3) == 2)
        #expect(ThemePicker.move(0, by: -1, count: 3) == 0)
        #expect(ThemePicker.move(2, by: 1, count: 3) == 2)
        #expect(ThemePicker.move(1, by: 1, count: 3) == 2)
        #expect(ThemePicker.move(0, by: 1, count: 0) == nil)
    }

    @Test func activatingTheHighlightedRowMapsToTheRightAction() {
        let rows = ThemePicker.rows(themes: themes, memberOf: [], query: "llm")
        #expect(ThemePicker.action(rows: rows, highlighted: 0) == .toggle(llm))
        #expect(ThemePicker.action(rows: rows, highlighted: 1) == .create("llm"))
        #expect(ThemePicker.action(rows: rows, highlighted: nil) == nil)
        #expect(ThemePicker.action(rows: rows, highlighted: 5) == nil)
    }

    @Test func commandReturnCreatesWithTheTypedNameUnlessItAlreadyExists() {
        func explicit(_ query: String) -> ThemePickerAction? {
            ThemePicker.explicitAction(rows: ThemePicker.rows(themes: themes, memberOf: [], query: query), query: query)
        }
        #expect(explicit("llm") == .create("llm"))            // partial matches exist, but the person asked for this name
        #expect(explicit("宇宙") == .create("宇宙"))
        #expect(explicit("LLMの実用設計") == .toggle(llm))      // exact name: never a duplicate
        #expect(explicit("") == nil && explicit("  ") == nil)
    }
}
