import AppKit
import Testing
import ReaderCore
@testable import RSSReader

@MainActor struct NativeArticleTextTests {
    @Test func namedBodyLinkIsClickableAndQuoteIsIndented() throws {
        let view = ArticleTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let text = "合成🙂：詳細はこちら"
        let range = (text as NSString).range(of: "詳細はこちら")
        let paragraph = BodyParagraph(text: text, links: [BodyLink(location: range.location, length: range.length, url: "https://synthetic.example/detail#section")], quoteDepth: 1)
        view.install(title: "合成", publisher: "SYNTHETIC", date: "", coverage: "RSS", paragraphs: [text], unavailable: nil, bodyParagraphs: [paragraph])
        let body = (view.string as NSString).range(of: text)
        let index = body.location + range.location
        let link = try #require(view.textStorage?.attribute(.link, at: index, effectiveRange: nil) as? URL)
        #expect(link.absoluteString == "https://synthetic.example/detail#section")
        let style = try #require(view.textStorage?.attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle)
        #expect(style.headIndent > 0)
        var opened: URL?
        view.onOpenLink = { opened = $0; return true }
        #expect(view.textView(view, clickedOnLink: link, at: index))
        #expect(opened == link)
        #expect(view.textView(view, clickedOnLink: "file:///private/tmp/forbidden", at: index))
        #expect(opened == link)
        view.install(title: "次の記事", publisher: "SYNTHETIC", date: "", coverage: "RSS", paragraphs: [text], unavailable: nil)
        let plain = (view.string as NSString).range(of: text)
        #expect(view.textStorage?.attribute(.link, at: plain.location + range.location, effectiveRange: nil) == nil)
    }
    @Test func fixedHeroArrivalDoesNotMoveReadingPosition() {
        let view = ArticleTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let scroll = NSScrollView(frame: view.frame); scroll.documentView = view
        let hero = NSImageView()
        view.configureHero(hero)
        view.install(title: "合成", publisher: "SYNTHETIC", date: "", coverage: "RSS要約のみ", paragraphs: (0..<50).map { "段落 \($0)" }, unavailable: nil, hero: true)
        view.restore(anchor: "paragraph-7", offset: 12)
        let before = view.readingPosition()
        hero.image = NSImage(size: NSSize(width: 500, height: 300))
        view.layoutSubtreeIfNeeded()
        let after = view.readingPosition()
        #expect(hero.frame.height == 180)
        #expect(before.anchor == after.anchor && abs(before.offset - after.offset) < 1)
    }
    @Test func nativeListFocusIsRecognizedWithoutSwiftUIFocusState() {
        let table = NSTableView()
        #expect(ReaderKeyboardCommands.listHasFocus(declared: false, responder: table))
        #expect(!ReaderKeyboardCommands.listHasFocus(declared: false, responder: NSTextView()))
        #expect(ReaderKeyboardCommands.listHasFocus(declared: true, responder: nil))
    }
    @Test func paragraphPositionSurvivesNativeScrollAndWidthChange() throws {
        let view = ArticleTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let scroll = NSScrollView(frame: view.frame)
        scroll.documentView = view
        let paragraphs = (0..<80).map { "合成段落\($0)。" + String(repeating: "日本語の長い文章です。", count: 20) }
        view.install(title: "合成タイトル", publisher: "SYNTHETIC", date: "2026/10/05", coverage: "RSS要約のみ", paragraphs: paragraphs, unavailable: nil)
        #expect(view.string.contains(paragraphs.last!))
        view.restore(anchor: "paragraph-7", offset: 23.5)
        let before = view.readingPosition()
        #expect(before.anchor == "paragraph-7")
        #expect(abs(before.offset - 23.5) < 1)
        scroll.setFrameSize(NSSize(width: 850, height: 400))
        view.setFrameSize(NSSize(width: 850, height: view.frame.height))
        view.restore(anchor: before.anchor, offset: before.offset)
        let after = view.readingPosition()
        #expect(after.anchor == before.anchor && abs(after.offset - before.offset) < 1)
    }

    @Test func displayStartPrecedesLayoutWithoutMarkingInvisibleBody() {
        let view = ArticleTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        var textAtStart: String?
        var displayed = 0
        view.onDisplayBegin = { textAtStart = view.string }
        view.onDisplayed = { displayed += 1 }
        view.install(title: "合成", publisher: "SYNTHETIC", date: "", coverage: "RSS要約のみ", paragraphs: ["新しい合成本文"], unavailable: nil)
        #expect(textAtStart == "")
        #expect(view.string.contains("新しい合成本文"))
        #expect(displayed == 0)
    }

    @Test func viewportResizeRoundTripsPreserveParagraphPositionAutomatically() {
        let view = ArticleTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let scroll = NSScrollView(frame: view.frame); scroll.documentView = view
        let paragraphs = (0..<80).map { "合成段落\($0)。" + String(repeating: "日本語の長い文章です。", count: 20) }
        view.install(title: "合成", publisher: "SYNTHETIC", date: "", coverage: "RSS要約のみ", paragraphs: paragraphs, unavailable: nil)
        view.restore(anchor: "paragraph-7", offset: 23.5)
        for _ in 0..<10 {
            for width in [850.0, 600.0] {
                scroll.setFrameSize(NSSize(width: width, height: 400))
                view.setFrameSize(NSSize(width: width, height: view.frame.height))
            }
            let position = view.readingPosition()
            #expect(position.anchor == "paragraph-7" && abs(position.offset - 23.5) < 1)
        }
    }

    @Test func headerOnlyViewportDoesNotCountBodyAsDisplayed() {
        let view = ArticleTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 100))
        let scroll = NSScrollView(frame: view.frame); scroll.documentView = view
        view.install(title: String(repeating: "長い合成タイトル ", count: 20), publisher: "SYNTHETIC", date: "2026/10/05", coverage: "RSS要約のみ", paragraphs: ["取得できた合成要約。"], unavailable: nil)
        view.restore(anchor: nil, offset: 0)
        #expect(!view.hasVisibleBody)
        view.restore(anchor: "paragraph-0", offset: 0)
        #expect(view.hasVisibleBody)
        view.install(title: "期限切れ", publisher: "SYNTHETIC", date: "", coverage: "本文なし", paragraphs: [], unavailable: "本文は利用できません。")
        #expect(!view.hasVisibleBody)
    }
}
