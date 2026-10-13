import Foundation
import Testing
@testable import ReaderCore

/// Specification 3.6 (core rules). The translator is a fake: the system's session exists only in the app.
@MainActor struct ArticleTranslationTests {
    private func content(_ paragraphs: [BodyParagraph], id: UUID = UUID()) -> ArticleContent {
        ArticleContent(articleID: id, text: paragraphs.map(\.text).joined(separator: "\n\n"), summary: "", coverage: .feedProvided,
                       originalURL: nil, bodyParagraphs: paragraphs)
    }
    private let english = [BodyParagraph(text: "First."), BodyParagraph(text: "  "), BodyParagraph(text: "Quoted.", quoteDepth: 1), BodyParagraph(text: "Last.")]

    /// A fake batch: answers every item with "訳:" and its text, after `before` returns for that item.
    private func fake(failing: Set<Int> = [], throwingAfter: Int? = nil, before: @escaping @Sendable (Int) async -> Void = { _ in }) -> TranslationBatch {
        { items in
            AsyncThrowingStream { continuation in
                Task {
                    for (count, item) in items.enumerated() {
                        if let limit = throwingAfter, count == limit { continuation.finish(throwing: FakeError.broken); return }
                        await before(item.index)
                        continuation.yield(TranslationResponse(index: item.index, text: failing.contains(item.index) ? nil : "訳:" + item.text))
                    }
                    continuation.finish()
                }
            }
        }
    }
    private enum FakeError: Error { case broken }

    // MARK: the plan

    @Test func thePlanHasTheTitleAndTheParagraphsWithTextInOrder() {
        let plan = TranslationPlan(title: "Title", content: content(english), target: "ja")
        #expect(plan.items.map(\.text) == ["Title", "First.", "Quoted.", "Last."])
        #expect(plan.items.map(\.index) == [TranslationPlan.titleIndex, 0, 2, 3])               // empty paragraph 1 is skipped
        let shown = plan.apply([TranslationPlan.titleIndex: "題", 2: "引用。"])
        #expect(shown.title == "題")
        #expect(shown.paragraphs.map(\.text) == ["First.", "  ", "引用。", "Last."])           // untranslated ones keep the original
        #expect(shown.paragraphs[2].quoteDepth == 1 && shown.paragraphs[2].links.isEmpty)
    }

    @Test func thePlanKeyChangesWithTheArticleTheBodyAndTheTarget() {
        let id = UUID()
        let a = TranslationPlan(title: "T", content: content(english, id: id), target: "ja").key
        #expect(a == TranslationPlan(title: "T", content: content(english, id: id), target: "ja").key)
        #expect(a != TranslationPlan(title: "T", content: content(english, id: id), target: "fr").key)
        #expect(a != TranslationPlan(title: "T", content: content(english + [BodyParagraph(text: "More.")], id: id), target: "ja").key)
        #expect(a != TranslationPlan(title: "T", content: content(english, id: UUID()), target: "ja").key)
    }

    // MARK: the state machine

    @Test func aPressTranslatesAndASecondPressShowsTheOriginal() async throws {
        let translation = ArticleTranslation()
        let article = content(english)
        let job = try #require(translation.press(title: "Title", content: article, target: "ja", decision: .translate(source: "en")))
        #expect(translation.state == .translating(done: 0, total: 4))
        await translation.run(job, translate: fake())
        #expect(translation.state == .done(failed: 0, source: "en"))
        #expect(translation.shown?.title == "訳:Title")
        #expect(translation.shown?.paragraphs.map(\.text) == ["訳:First.", "  ", "訳:Quoted.", "訳:Last."])
        #expect(translation.press(title: "Title", content: article, target: "ja", decision: .translate(source: "en")) == nil)
        #expect(translation.state == .idle && translation.shown == nil)
    }

    @Test func progressCountsTheItemsAsTheyArrive() async throws {
        let translation = ArticleTranslation()
        let job = try #require(translation.press(title: "Title", content: content(english), target: "ja", decision: .translate(source: nil)))
        var seen: [ArticleTranslation.State] = []
        await translation.run(job, translate: fake(), onProgress: { seen.append($0) })
        #expect(seen == [.translating(done: 1, total: 4), .translating(done: 2, total: 4), .translating(done: 3, total: 4), .translating(done: 4, total: 4)])
    }

    @Test func aFailedParagraphKeepsItsOriginalAndIsCounted() async throws {
        let translation = ArticleTranslation()
        let job = try #require(translation.press(title: "Title", content: content(english), target: "ja", decision: .translate(source: "en")))
        await translation.run(job, translate: fake(failing: [2]))
        #expect(translation.state == .done(failed: 1, source: "en"))
        #expect(translation.shown?.paragraphs.map(\.text) == ["訳:First.", "  ", "Quoted.", "訳:Last."])
    }

    @Test func aBatchThatBreaksBeforeAnyAnswerFailsAndShowsTheOriginal() async throws {
        let translation = ArticleTranslation()
        let job = try #require(translation.press(title: "Title", content: content(english), target: "ja", decision: .translate(source: "en")))
        await translation.run(job, translate: fake(throwingAfter: 0), describe: { _ in "翻訳できませんでした。" })
        #expect(translation.state == .failed("翻訳できませんでした。"))
        #expect(translation.shown == nil)
    }

    @Test func aBatchThatBreaksHalfwayKeepsWhatArrivedAndCountsTheRestAsFailed() async throws {
        let translation = ArticleTranslation()
        let job = try #require(translation.press(title: "Title", content: content(english), target: "ja", decision: .translate(source: "en")))
        await translation.run(job, translate: fake(throwingAfter: 2))
        #expect(translation.state == .done(failed: 2, source: "en"))
        #expect(translation.shown?.title == "訳:Title")
        #expect(translation.shown?.paragraphs.map(\.text) == ["訳:First.", "  ", "Quoted.", "Last."])
    }

    @Test func preparingIsShownOnlyForTheRunningJob() throws {
        let translation = ArticleTranslation()
        let job = try #require(translation.press(title: "Title", content: content(english), target: "ja", decision: .translate(source: "en")))
        translation.preparing(job)
        #expect(translation.state == .preparing)
        translation.reset()
        translation.preparing(job)                                                            // a late call for a dropped job
        #expect(translation.state == .idle)
    }

    @Test func theLanguageDecisionCanEndThePressWithoutWork() {
        let translation = ArticleTranslation()
        #expect(translation.press(title: "題", content: content(english), target: "ja", decision: .alreadyInTarget) == nil)
        #expect(translation.state == .alreadyInTarget && translation.shown == nil)
        #expect(translation.press(title: "T", content: content(english), target: "xx", decision: .unsupported) == nil)
        #expect(translation.state == .unsupported)
    }

    // MARK: stale answers

    @Test func anAnswerForADroppedJobChangesNothing() async throws {
        let translation = ArticleTranslation()
        let first = content(english)
        let old = try #require(translation.press(title: "Old", content: first, target: "ja", decision: .translate(source: "en")))
        translation.reset()                                                                   // another article was chosen
        let next = try #require(translation.press(title: "New", content: content(english), target: "ja", decision: .translate(source: "en")))
        await translation.run(old, translate: fake())
        #expect(translation.state == .translating(done: 0, total: 4))
        #expect(translation.shown?.title == "New")                                           // nothing of the old article
        await translation.run(next, translate: fake())
        #expect(translation.shown?.title == "訳:New")
    }

    @Test func anotherLanguageOrASecondPressDropsTheRunningJob() async throws {
        let translation = ArticleTranslation()
        let article = content(english)
        let japanese = try #require(translation.press(title: "T", content: article, target: "ja", decision: .translate(source: "en")))
        let french = try #require(translation.press(title: "T", content: article, target: "fr", decision: .translate(source: "en")))
        await translation.run(japanese, translate: fake())
        #expect(translation.state == .translating(done: 0, total: 4))
        #expect(translation.press(title: "T", content: article, target: "fr", decision: .translate(source: "en")) == nil)   // back to the original
        await translation.run(french, translate: fake())
        #expect(translation.state == .idle && translation.shown == nil)
    }

    @Test func aChangedBodyDropsTheTranslation() async throws {
        let translation = ArticleTranslation()
        let id = UUID()
        let job = try #require(translation.press(title: "T", content: content(english, id: id), target: "ja", decision: .translate(source: "en")))
        await translation.run(job, translate: fake())
        translation.contentChanged(title: "T", content: content(english, id: id))                // the same body: kept
        #expect(translation.shown != nil)
        translation.contentChanged(title: "T", content: content(english + [BodyParagraph(text: "Full text.")], id: id))
        #expect(translation.state == .idle && translation.shown == nil)
    }

    @Test func aChangedBodyWhileTranslatingDropsTheLateAnswers() async throws {
        let translation = ArticleTranslation()
        let id = UUID()
        let job = try #require(translation.press(title: "T", content: content(english, id: id), target: "ja", decision: .translate(source: "en")))
        let gate = AsyncStream<Void>.makeStream()
        let running = Task { await translation.run(job, translate: fake(before: { _ in for await _ in gate.stream { return } })) }
        translation.contentChanged(title: "T", content: content([BodyParagraph(text: "Replaced.")], id: id))
        gate.continuation.finish()
        await running.value
        #expect(translation.state == .idle && translation.shown == nil)
    }

    // MARK: the cache

    @Test func theSameArticleBodyAndTargetComeFromTheCache() async throws {
        let translation = ArticleTranslation(cacheSize: 2)
        let a = content(english), b = content(english), c = content(english)
        for article in [a, b] {
            let job = try #require(translation.press(title: "T", content: article, target: "ja", decision: .translate(source: "en")))
            await translation.run(job, translate: fake())
            translation.reset()
        }
        #expect(translation.press(title: "T", content: a, target: "ja", decision: .translate(source: "en")) == nil)   // a hit: no work
        #expect(translation.state == .done(failed: 0, source: "en") && translation.shown?.title == "訳:T")
        translation.reset()
        #expect(translation.press(title: "T", content: a, target: "fr", decision: .translate(source: "en")) != nil)   // another target: a miss
        translation.reset()
        let job = try #require(translation.press(title: "T", content: c, target: "ja", decision: .translate(source: "en")))
        await translation.run(job, translate: fake())
        translation.reset()
        // Two entries at most: c pushed out b, the one used least recently (a was used by the hit).
        #expect(translation.press(title: "T", content: b, target: "ja", decision: .translate(source: "en")) != nil)
        translation.reset()
        #expect(translation.press(title: "T", content: a, target: "ja", decision: .translate(source: "en")) == nil)
    }

    @Test func aTranslationWithFailedParagraphsIsNotCachedSoTheNextPressTriesAgain() async throws {
        let translation = ArticleTranslation()
        let article = content(english)
        let job = try #require(translation.press(title: "T", content: article, target: "ja", decision: .translate(source: "en")))
        await translation.run(job, translate: fake(failing: [0]))
        translation.reset()
        #expect(translation.press(title: "T", content: article, target: "ja", decision: .translate(source: "en")) != nil)
    }

    /// The app's task ended without a new press (the view went away): nothing runs any more, so the original shows.
    @Test func aCancelledRunShowsTheOriginal() async throws {
        let translation = ArticleTranslation()
        let job = try #require(translation.press(title: "T", content: content(english), target: "ja", decision: .translate(source: "en")))
        let gate = AsyncStream<Void>.makeStream()
        let running = Task { await translation.run(job, translate: fake(before: { index in if index == 0 { for await _ in gate.stream { return } } })) }
        while translation.state == .translating(done: 0, total: 4) { await Task.yield() }
        running.cancel()
        gate.continuation.finish()
        await running.value
        #expect(translation.state == .idle && translation.shown == nil)
    }

    @Test func aFailedTranslationIsNotCached() async throws {
        let translation = ArticleTranslation()
        let article = content(english)
        let job = try #require(translation.press(title: "T", content: article, target: "ja", decision: .translate(source: "en")))
        await translation.run(job, translate: fake(throwingAfter: 0))
        translation.reset()
        #expect(translation.press(title: "T", content: article, target: "ja", decision: .translate(source: "en")) != nil)
    }
}

/// Specification 3.6: translate, "already in the target language", or "unsupported pair".
struct LanguageDecisionTests {
    @Test func theSameLanguageNeedsNoTranslation() async {
        let outcome = await LanguageDecision.decide(sample: "日本語の記事", target: "ja", detect: { _ in "ja" }, supported: { _, _ in true })
        #expect(outcome == .alreadyInTarget)
        let regional = await LanguageDecision.decide(sample: "x", target: "en-US", detect: { _ in "en-GB" }, supported: { _, _ in true })
        #expect(regional == .alreadyInTarget)                                                 // the language, not the region, counts
    }

    @Test func anotherSupportedLanguageIsTranslated() async {
        let outcome = await LanguageDecision.decide(sample: "An English article", target: "ja", detect: { _ in "en" }, supported: { $0 == "en" && $1 == "ja" })
        #expect(outcome == .translate(source: "en"))
    }

    @Test func anUnknownLanguageIsLeftToTheSystem() async {
        let outcome = await LanguageDecision.decide(sample: "1234", target: "ja", detect: { _ in nil }, supported: { _, _ in false })
        #expect(outcome == .translate(source: nil))
    }

    @Test func anUnsupportedPairIsSaidSo() async {
        let outcome = await LanguageDecision.decide(sample: "x", target: "ja", detect: { _ in "la" }, supported: { _, _ in false })
        #expect(outcome == .unsupported)
    }

    @Test func theSystemDetectorKnowsPlainEnglishAndJapanese() {
        #expect(LanguageDecision.detect("This is a plain English sentence about reading feeds every day.") == "en")
        #expect(LanguageDecision.detect("これは毎日フィードを読むことについての日本語の文章です。") == "ja")
        #expect(LanguageDecision.detect("") == nil)
    }

    @Test func theSampleIsTheTitleAndTheStartOfTheBody() {
        let long = String(repeating: "word ", count: 400)
        let sample = LanguageDecision.sample(title: "Title", paragraphs: [long, "later"])
        #expect(sample.hasPrefix("Title\n") && sample.count <= LanguageDecision.sampleLength && !sample.contains("later"))
    }
}
