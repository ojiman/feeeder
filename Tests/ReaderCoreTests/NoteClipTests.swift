import Testing
@testable import ReaderCore

// Checks PRD-19: the text that 「記事をノートに送る」 inserts (specification 3.3).
struct NoteClipTests {
    private let url = "https://example.com/posts/1"

    @Test func withoutSelectionItIsOneMarkdownLink() {
        #expect(NoteClip.text(title: "小さく作って、毎日触ってみる。", url: url, selection: nil) == "[小さく作って、毎日触ってみる。](https://example.com/posts/1)")
        #expect(NoteClip.text(title: "A title", url: url, selection: "") == "[A title](https://example.com/posts/1)")
        #expect(NoteClip.text(title: "A title", url: url, selection: " \n\t ") == "[A title](https://example.com/posts/1)")
    }

    @Test func aSelectionIsQuotedLineByLineWithItsSource() {
        let text = NoteClip.text(title: "A title", url: url, selection: "First line.\nSecond line.")
        #expect(text == "> First line.\n> Second line.\n> — [A title](https://example.com/posts/1)")
    }

    @Test func emptyLinesInsideTheSelectionStayQuotedAndOuterOnesGo() {
        let text = NoteClip.text(title: "T", url: url, selection: "\n\nOne.\n\nTwo.\n  \n")
        #expect(text == "> One.\n>\n> Two.\n> — [T](https://example.com/posts/1)")
    }

    @Test func everyKindOfLineBreakInTheSelectionIsOneLine() {
        let text = NoteClip.text(title: "T", url: url, selection: "a\r\nb\rc\u{2028}d\u{2029}e")
        #expect(text == "> a\n> b\n> c\n> d\n> e\n> — [T](https://example.com/posts/1)")
    }

    @Test func japaneseSelectionKeepsItsCharacters() {
        let text = NoteClip.text(title: "要約の前に、原文を大切にする。", url: url, selection: "まずは原文を読む場所を整えています。😀")
        #expect(text == "> まずは原文を読む場所を整えています。😀\n> — [要約の前に、原文を大切にする。](https://example.com/posts/1)")
    }

    @Test func bracketsInTheTitleAreEscaped() {
        #expect(NoteClip.text(title: "[PR] Swift [6.3]", url: url, selection: nil) == "[\\[PR\\] Swift \\[6.3\\]](https://example.com/posts/1)")
        #expect(NoteClip.text(title: "[PR] only", url: nil, selection: nil) == "\\[PR\\] only")
    }

    @Test func aTitleIsOneLineWithoutOuterSpaces() {
        #expect(NoteClip.text(title: "  Two\nlines\r\n here ", url: url, selection: nil) == "[Two lines here](https://example.com/posts/1)")
    }

    @Test func aMissingTitleGivesTheURLAndAMissingURLGivesTheTitle() {
        #expect(NoteClip.text(title: nil, url: url, selection: nil) == "https://example.com/posts/1")
        #expect(NoteClip.text(title: "  ", url: url, selection: nil) == "https://example.com/posts/1")
        #expect(NoteClip.text(title: "A title", url: nil, selection: nil) == "A title")
        #expect(NoteClip.text(title: "A title", url: " ", selection: nil) == "A title")
        #expect(NoteClip.text(title: nil, url: url, selection: "Quoted.") == "> Quoted.\n> — https://example.com/posts/1")
    }

    @Test func withNeitherTitleNorURLThereIsNothingToInsert() {
        #expect(NoteClip.text(title: nil, url: nil, selection: nil) == nil)
        #expect(NoteClip.text(title: " ", url: "", selection: "Quoted.") == nil)
    }

    @Test func aURLThatWouldBreakTheLinkIsWrappedInAngleBrackets() {
        #expect(NoteClip.text(title: "T", url: "https://example.com/a b", selection: nil) == "[T](<https://example.com/a b>)")
        #expect(NoteClip.text(title: "T", url: "https://example.com/a)", selection: nil) == "[T](<https://example.com/a)>)")
        #expect(NoteClip.text(title: "T", url: "https://en.wikipedia.org/wiki/Swift_(language)", selection: nil)
                == "[T](https://en.wikipedia.org/wiki/Swift_(language))")
    }
}
