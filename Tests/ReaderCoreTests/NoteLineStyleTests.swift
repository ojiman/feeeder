import Foundation
import Testing
@testable import ReaderCore

struct NoteLineStyleTests {
    private func kinds(_ text: String) -> [NoteLineStyle.Kind] { NoteLineStyle.runs(in: text).map(\.kind) }
    private func text(_ run: NoteLineStyle.Run, in source: String) -> String { (source as NSString).substring(with: run.line) }

    @Test func headingsNeedOneToSixMarksAndASpace() {
        #expect(kinds("# a") == [.heading(level: 1)])
        #expect(kinds("###### a") == [.heading(level: 6)])
        #expect(kinds("## 見出し") == [.heading(level: 2)])
        #expect(kinds("####### a").isEmpty)                         // seven marks
        #expect(kinds("#a").isEmpty && kinds("#\ta").isEmpty && kinds("#タグ").isEmpty)
        #expect(kinds("#") == [.heading(level: 1)])               // a lone mark line
        #expect(kinds("###") == [.heading(level: 3)])
        #expect(kinds(" # a").isEmpty)                            // a heading starts at the first column
    }

    @Test func listItemsNeedAMarkerAndASpace() {
        #expect(kinds("- a") == [.listItem(indentSteps: 0, ordered: false)])
        #expect(kinds("* a") == [.listItem(indentSteps: 0, ordered: false)] && kinds("+ a") == [.listItem(indentSteps: 0, ordered: false)])
        #expect(kinds("1. a") == [.listItem(indentSteps: 0, ordered: true)] && kinds("12) a") == [.listItem(indentSteps: 0, ordered: true)])
        #expect(kinds("-a").isEmpty && kinds("1.a").isEmpty && kinds("--- ").isEmpty && kinds("1 a").isEmpty && kinds("-").isEmpty)
        #expect(kinds("- ") == [.listItem(indentSteps: 0, ordered: false)])     // typing the marker and the space styles at once
        #expect(kinds("1234567890. a").isEmpty)                    // more than nine digits is not a number
    }

    @Test func leadingSpacesIndentUpToEightAndNineIsPlain() {
        #expect(kinds("  - a") == [.listItem(indentSteps: 1, ordered: false)])
        #expect(kinds("    1. a") == [.listItem(indentSteps: 2, ordered: true)])
        #expect(kinds("        - a") == [.listItem(indentSteps: 4, ordered: false)])
        #expect(kinds("         - a").isEmpty)                    // nine spaces
        #expect(kinds("\t- a").isEmpty)                            // a tab is not an indent
    }

    @Test func rangesAreUTF16AndLinesEndAtAnyLineBreak() {
        let source = "😀 plain\r\n# 見出し😀\n- a\r- b\u{2028}1. c\u{2029}text"
        let runs = NoteLineStyle.runs(in: source)
        #expect(runs.map(\.kind) == [.heading(level: 1), .listItem(indentSteps: 0, ordered: false), .listItem(indentSteps: 0, ordered: false), .listItem(indentSteps: 0, ordered: true)])
        #expect(runs.map { text($0, in: source) } == ["# 見出し😀", "- a", "- b", "1. c"])
        #expect(runs.map { (source as NSString).substring(with: $0.marker) } == ["#", "-", "-", "1."])
    }

    @Test func emptyAndUnterminatedAndHugeLinesAreHandled() {
        #expect(NoteLineStyle.runs(in: "").isEmpty && NoteLineStyle.runs(in: "\n\n").isEmpty)
        #expect(kinds("# last line without a break") == [.heading(level: 1)])
        let huge = "- " + String(repeating: "あ", count: 100_000)
        let runs = NoteLineStyle.runs(in: huge)
        #expect(runs.count == 1 && runs[0].line.length == 100_002 && runs[0].marker == NSRange(location: 0, length: 1))
    }

    @Test func aBaseOffsetShiftsEveryRange() {
        let runs = NoteLineStyle.runs(in: "# a\n- b", baseOffset: 100)
        #expect(runs.map(\.line) == [NSRange(location: 100, length: 3), NSRange(location: 104, length: 3)])
        #expect(runs.map(\.marker) == [NSRange(location: 100, length: 1), NSRange(location: 104, length: 1)])
    }

    @Test func aSixtyThousandLineNoteIsScannedQuickly() {
        let note = String(repeating: "# 見出し\n- 項目 日本語もあります。\n本文の行です。\n", count: 20_000)
        let start = Date()
        let runs = NoteLineStyle.runs(in: note)
        #expect(runs.count == 40_000)
        #expect(Date().timeIntervalSince(start) < 0.5, "took \(Date().timeIntervalSince(start)) s")
    }
}
