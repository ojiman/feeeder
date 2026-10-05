import AppKit
import Testing
@testable import RSSReader

@MainActor struct NativeArticleTextTests {
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
