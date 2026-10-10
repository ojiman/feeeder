import Foundation
import Testing
@testable import ReaderCore

struct NoteSectionTests {
    private let note = "前置き\n\n# 一つ目\n一つ目の本文。\n続き。\n\n# 二つ目\n二つ目の本文。\n"
    private func cursor(_ marker: String, in text: String, after: Bool = false) -> NSRange {
        let found = (text as NSString).range(of: marker)
        return NSRange(location: found.location + (after ? found.length : 0), length: 0)
    }
    private func target(_ text: String, _ selection: NSRange) -> NoteTarget? { NoteSection.target(in: text, selection: selection) }

    @Test func aSelectionIsTheTargetAsTyped() throws {
        let range = (note as NSString).range(of: "本文。\n続き")
        let result = try #require(target(note, range))
        #expect(result.kind == .selection && result.range == range && result.text == "本文。\n続き")
        #expect(result.insertionOffset == range.location + range.length)
        #expect(target(note, NSRange(location: (note as NSString).range(of: "前置き").location, length: 1))?.text == "前")
    }

    @Test func theSectionUnderTheCursorHasNoHeadingAndNoTrailingBlankLines() throws {
        let result = try #require(target(note, cursor("本文", in: note)))
        #expect(result.kind == .section && result.text == "一つ目の本文。\n続き。")
        #expect((note as NSString).substring(with: result.range) == result.text)
        #expect(result.insertionOffset == result.range.location + result.range.length)
        #expect((note as NSString).substring(from: result.insertionOffset).hasPrefix("\n\n# 二つ目"))
    }

    @Test func aCursorOnTheHeadingLineGivesTheSectionUnderIt() throws {
        #expect(try #require(target(note, cursor("# 二つ目", in: note))).text == "二つ目の本文。")
        #expect(try #require(target(note, cursor("# 一つ目", in: note, after: true))).text == "一つ目の本文。\n続き。")
    }

    @Test func theTextBeforeTheFirstHeadingIsASection() throws {
        let result = try #require(target(note, NSRange(location: 0, length: 0)))
        #expect(result.kind == .section && result.text == "前置き")
    }

    @Test func aCursorAtTheEndOfASectionBelongsToItAndTheNextHeadingStartsTheNext() throws {
        let endOfFirst = cursor("続き。", in: note, after: true)
        #expect(try #require(target(note, endOfFirst)).text == "一つ目の本文。\n続き。")
        #expect(try #require(target(note, cursor("# 二つ目", in: note))).text == "二つ目の本文。")
        let end = NSRange(location: (note as NSString).length, length: 0)                        // after the final line break
        #expect(try #require(target(note, end)).text == "二つ目の本文。")
    }

    @Test func aHashInTheMiddleOfALineIsNotAHeading() throws {
        let text = "# 見出し\nこれは # の途中。\n続き"
        #expect(try #require(target(text, cursor("続き", in: text))).text == "これは # の途中。\n続き")
        let bare = "#見出し記号だけ\n本文"                                                          // a line that starts with # is a heading
        #expect(try #require(target(bare, cursor("本文", in: bare))).text == "本文")
    }

    @Test func nothingToWorkOnGivesNil() {
        #expect(target("", NSRange(location: 0, length: 0)) == nil)
        #expect(target("# 見出しだけ", NSRange(location: 2, length: 0)) == nil)
        #expect(target("# 見出し\n\n  \n# 次\n本文", NSRange(location: 2, length: 0)) == nil)     // heading with blank lines only
        #expect(target("本文", NSRange(location: 0, length: 0)) != nil)
        #expect(target("あ  い", NSRange(location: 1, length: 2)) == nil)                       // a selection of white space only
    }

    @Test func crlfNotesKeepTheirLineBreaksInTheTextAndTheRange() throws {
        let text = "# 見出し\r\n一行目\r\n二行目\r\n\r\n# 次\r\n本文"
        let result = try #require(target(text, cursor("一行目", in: text)))
        #expect(result.text == "一行目\r\n二行目" && (text as NSString).substring(with: result.range) == "一行目\r\n二行目")
        #expect((text as NSString).substring(from: result.insertionOffset).hasPrefix("\r\n\r\n# 次"))
    }

    @Test func rangesAreUTF16AndStartAndEndOnCharacterBoundaries() throws {
        let text = "# 題\n😀と👨‍👩‍👧とe\u{301}\n後ろ"
        let result = try #require(target(text, cursor("😀", in: text)))
        #expect(result.text == "😀と👨‍👩‍👧とe\u{301}\n後ろ")
        let swiftRange = try #require(Range(result.range, in: text))
        #expect(String(text[swiftRange]) == result.text)
    }

    @Test func aCursorOutsideTheNoteIsClamped() throws {
        #expect(try #require(target(note, NSRange(location: 9_999, length: 0))).text == "二つ目の本文。")
        #expect(try #require(target(note, NSRange(location: -5, length: 0))).text == "前置き")
    }
}
