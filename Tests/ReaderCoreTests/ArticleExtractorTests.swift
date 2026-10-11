import Foundation
import Testing
@testable import ReaderCore

struct ArticleExtractorTests {
    static let url = URL(string: "https://synthetic.example/posts/1")!
    static let html = """
    <html><meta charset="utf-8"><body><nav>広告</nav><article><h1>合成記事</h1>
    <p>最初の段落です。これは合成の日本語本文です。</p><script>秘密のscript</script><style>style広告</style>
    <p>次の段落です。日本語と改行を保持します。</p><pre>let value = 1\n  print(value)</pre>
    <nav>関連記事の広告</nav><form>ログイン</form><iframe>広告</iframe></article></body></html>
    """
    private func extract(_ html: String, headers: [String: String] = [:]) throws -> ExtractionResult? {
        let data = Data(html.utf8)
        return try ArticleExtractor.extract(html: data, response: HTTPResponse(data: data, finalURL: Self.url, statusCode: 200, headers: headers))
    }
    @Test func japaneseParagraphsAndCodeExcludeAdjacentAds() throws {
        let result = try #require(try extract(Self.html))
        #expect(result.coverage == .extracted && result.sourceURL == Self.url)
        #expect(result.text.contains("最初の段落です。"))
        #expect(result.text.contains("\n\n次の段落です。"))
        #expect(result.text.contains("let value = 1\n  print(value)"))
        #expect(!result.text.contains("広告") && !result.text.contains("script") && !result.text.contains("ログイン"))
    }
    /// The shape of a page whose `<article>` holds the page's chrome (breadcrumbs, a date, tags, counters) around a little text.
    static let chromeHeavy = """
    <html><meta charset="utf-8"><body><article class="single-page">
    <p>トップ</p><p>2026年</p><p>10月</p><p>11日</p><p>合成の話題について、長いタイトルが一つだけあります</p>
    <p>公開 2026年10月11日20:33（8時間前）</p><p>AI 合成 テスト</p><p>27</p><p>94</p><p>0</p><p>27973</p><p>29</p><p>87</p>
    <p>ポスト</p><p>27</p><p>いいね！0</p><p>ブックマーク</p><p>44</p><p>共有</p><p>0</p><p>返信</p>
    <p>これは合成の本文です。まとまった文章は、これだけです。</p>
    </article></body></html>
    """
    @Test func aPageOfMostlyChromeIsNotTakenAsTheArticle() throws {
        #expect(try extract(Self.chromeHeavy) == nil)                                           // the feed's own text stays on screen instead
        let paragraphs = [BodyParagraph(text: "トップ"), BodyParagraph(text: "27"), BodyParagraph(text: "これは十分に長い、まとまった一つの段落の文章です。")]
        #expect(!ExtractionQuality.isArticleText(paragraphs))                                   // two of three are tiny
        #expect(ExtractionQuality.isArticleText([BodyParagraph(text: "見出し"), BodyParagraph(text: "最初の段落です。これは合成の日本語本文です。"), BodyParagraph(text: "次の段落です。")]))
        #expect(!ExtractionQuality.isArticleText([]))
    }
    @Test func mainAndMalformedHTMLRemainReadable() throws {
        let html = "<main><p>壊れたHTMLでも日本語の段落を保持します。<p>次の段落も読みやすく表示できる合成本文です。"
        let result = try #require(try extract(html))
        #expect(result.text.contains("\n\n次の段落"))
    }
    @Test func missingArticleAndRestrictionPagesFallBack() throws {
        for html in ["<body>ナビゲーションだけ</body>", "<article><p>短い</p></article>",
                     "<article><form>ログインして続きを読む</form></article>",
                     "<article><p>Subscribe to continue reading. Sign in to read this premium article.</p></article>",
                     "<article><p>Please verify you are human to continue with this CAPTCHA challenge.</p></article>"] {
            #expect(try extract(html) == nil)
        }
        #expect(try extract(Self.html, headers: ["content-type": "text/html; charset=made-up"]) == nil)
    }
    @Test func shiftJISFromHTTPAndMetaIsStrictlyDecoded() throws {
        let html = "<html><meta charset='Shift_JIS'><article><p>日本語の合成本文です。文字コードを保ち、段落をそのまま読めます。</p></article></html>"
        let data = try #require(html.data(using: .shiftJIS))
        for headers in [[:], ["content-type": "text/html; charset=Shift_JIS"]] {
            let result = try #require(try ArticleExtractor.extract(html: data, response: HTTPResponse(data: data, finalURL: Self.url, statusCode: 200, headers: headers)))
            #expect(result.text.contains("日本語の合成本文"))
        }
    }
}
