import Foundation
import Testing
@testable import ReaderCore

struct NoteMarkdownTests {
    @Test func fileNamesAreSafeAndFoldSeparators() {
        #expect(NoteMarkdown.fileName(forTitle: "金利の話") == "金利の話.md")
        #expect(NoteMarkdown.fileName(forTitle: "a/b") == "a b.md")
        #expect(NoteMarkdown.fileName(forTitle: "a:b") == "a b.md")
        #expect(NoteMarkdown.fileName(forTitle: "a\u{0}\tb") == "a b.md")
        #expect(NoteMarkdown.fileName(forTitle: "../x") == "x.md")
    }

    @Test func emptyDotAndMarkOnlyTitlesUseTheFallback() {
        for title in ["", "...", "  . .  ", "\u{301}\u{301}", "\u{200B}"] {
            #expect(NoteMarkdown.fileName(forTitle: title) == "ノート.md")
        }
    }

    @Test func namesFitTheFileSystemByteLimitWithoutSplittingGraphemes() {
        for title in [String(repeating: "🙂", count: 100), String(repeating: "e\u{301}", count: 100)] {
            let fileName = NoteMarkdown.fileName(forTitle: title)
            #expect(fileName.hasSuffix(".md"))
            #expect(fileName.decomposedStringWithCanonicalMapping.utf8.count <= 255)
            #expect(title.hasPrefix(String(fileName.dropLast(3))))
        }
    }

    @Test func dataIsTheExactUTF8TextWithoutAnAddedLineBreak() {
        for text in ["line one\r\nline two 😀 e\u{301}", String(repeating: "a🙂\r\n", count: 400_000), ""] {
            let bytes = NoteMarkdown.data(for: text)
            #expect(bytes == Data(text.utf8))
            #expect(!bytes.starts(with: [0xEF, 0xBB, 0xBF]))
        }
    }
}
