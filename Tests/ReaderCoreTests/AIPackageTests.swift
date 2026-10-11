import Foundation
import CryptoKit
import Testing
@testable import ReaderCore

@MainActor struct AIPackageTests {
    @Test func mixedSourcesUseTheEarliestExpiry() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let at = Date.now, received = at.addingTimeInterval(-6.5 * 86_400)
        let store = try ReaderStore(url: library.url, seedDemo: true, now: received)
        try store.applyRetention(days: 7, at: at)
        let a = store.articles[0], b = store.articles[1]
        let note = try store.createNote(text: "# A\n", at: received)
        let link = try store.addArticle(a.id, toNote: note.id, at: received)
        let review = AIPackageReview(store: store, now: { at })
        try review.build(selections: [.article(b.id), .noteArticle(link.key)], language: "日本語", at: at)
        #expect(review.package?.expiresAt == received.addingTimeInterval(7 * 86_400))
        try review.build(selections: [.noteArticle(link.key)], language: "日本語", at: at)
        try store.deleteContent(articleIDs: [a.id], at: at)
        #expect(review.package != nil)
    }
    func source(_ title: String, text: String, coverage: ContentCoverage) -> AISource {
        let id = UUID(), url = URL(string: "https://synthetic.example/" + title)!
        return AISource(articleID: id, title: title, url: url,
            content: ArticleContent(articleID: id, text: text, summary: "合成要約", coverage: coverage, originalURL: url))
    }
    @Test func wholeSourcesLanguageCoverageAndHashArePreserved() throws {
        let text = (1...500).map { String(format: "%04d: 合成本文", $0) }.joined(separator: "\n") + "\nEND_A"
        let a = source("A", text: text, coverage: .extracted)
        let b = source("B", text: "合成RSS要約\nEND_B", coverage: .summaryOnly)
        let now = Date.now
        let package = try AIPackageBuilder.build(sources: [a, b], language: "日本語", createdAt: now, expiresAt: now.addingTimeInterval(86_400))
        #expect(package.text.contains(text) && package.text.contains(b.content.text))
        #expect(package.text.contains("Output language: 日本語") && package.text.contains("https://synthetic.example/B"))
        #expect(package.text.contains("RSS summary only; full body unavailable"))
        #expect(package.text.contains("含まれていない本文を推測しない"))
        #expect(package.text.hasSuffix("END_PACKAGE\n"))
        #expect(package.sha256 == SHA256.hash(data: Data(package.text.utf8)).map { String(format: "%02x", $0) }.joined())
        let excluded = try AIPackageBuilder.build(sources: [a], language: "English", createdAt: now, expiresAt: package.expiresAt)
        #expect(excluded.sources.map(\.articleID) == [a.articleID])
        #expect(!excluded.text.contains(b.articleID.uuidString) && !excluded.text.contains("END_B"))
        #expect(throws: (any Error).self) { try AIPackageBuilder.build(sources: [], language: "日本語", createdAt: now, expiresAt: package.expiresAt) }
    }
    @Test func splitPreservesEveryUTF8ByteAndSourceMapping() throws {
        let a = source("huge", text: String(repeating: "日本語の本文🍵\n", count: 120_000) + "END_HUGE", coverage: .extracted)
        let now = Date.now
        let package = try AIPackageBuilder.build(sources: [a], language: "日本語", createdAt: now, expiresAt: now.addingTimeInterval(86_400))
        let parts = AIPackageBuilder.split(package)
        #expect(parts.count > 1 && parts.allSatisfy { $0.count <= 1_048_576 })
        var restored = Data()
        for (index, part) in parts.enumerated() {
            let text = try #require(String(data: part, encoding: .utf8))
            #expect(text.contains("Part: \(index + 1)/\(parts.count)") && text.contains(a.articleID.uuidString))
            let delimiter = try #require(part.range(of: Data("\n\n".utf8)))
            restored.append(part[delimiter.upperBound...])
        }
        #expect(restored == Data(package.text.utf8))
    }
    @Test func reviewInvalidatesWhenSourceExpiresOrChanges() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let now = Date.now
        let store = try ReaderStore(url: library.url, seedDemo: true, now: now)
        let id = try #require(store.articles.first).id
        let review = AIPackageReview(store: store, now: { now })
        try review.build(articleIDs: [id], language: "日本語", at: now)
        #expect(throws: (any Error).self) { try review.validated(at: now.addingTimeInterval(86_400)) }
        #expect(review.package == nil)
        try review.build(articleIDs: [id], language: "日本語", at: now)
        try store.saveExtractedContent(articleID: id, result: ExtractionResult(text: "新しい合成本文", coverage: .extracted, sourceURL: URL(string: "https://synthetic.example/changed")!), at: now)
        #expect(throws: (any Error).self) { try review.validated(at: now) }
        #expect(review.package == nil && review.reason != nil)
    }
    @Test func reviewClearsWhenRetentionShortensOrContentIsDeleted() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let now = Date.now, old = now.addingTimeInterval(-10 * 86_400)
        let store = try ReaderStore(url: library.url, seedDemo: true, now: old)
        let ids = store.articles.map(\.id)
        let review = AIPackageReview(store: store, now: { now })
        try review.build(articleIDs: ids, language: "日本語", at: now)
        try store.applyRetention(days: 7, at: now)
        #expect(review.package == nil && review.reason != nil)
        #expect(throws: (any Error).self) { try review.validated(at: now) }
        #expect(try store.aiSources(articleIDs: ids, at: now).isEmpty)
        let second = try TestLibrary(); defer { second.cleanup() }
        let fresh = try ReaderStore(url: second.url, seedDemo: true, now: now)
        let id = try #require(fresh.articles.first).id
        let freshReview = AIPackageReview(store: fresh, now: { now })
        try freshReview.build(articleIDs: [id], language: "日本語", at: now)
        try fresh.deleteContent(articleIDs: [id], at: now)
        #expect(freshReview.package == nil)
    }
    @Test func lifetimeShortensWithoutExtendingOrReviving() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let now = Date.now, received = now.addingTimeInterval(-6.5 * 86_400)
        let store = try ReaderStore(url: library.url, seedDemo: true, now: received)
        let id = try #require(store.articles.first).id
        let review = AIPackageReview(store: store, now: { now })
        try review.build(articleIDs: [id], language: "日本語", at: now)
        let original = try #require(review.package)
        try store.applyRetention(days: 7, at: now)
        #expect(review.package?.expiresAt == received.addingTimeInterval(7 * 86_400))
        #expect(review.package?.sha256 == original.sha256)
        try store.applyRetention(days: 365, at: now)
        #expect(review.package?.expiresAt == received.addingTimeInterval(7 * 86_400))
    }

    @Test func noteSummaryIgnoresOriginalExpiryAndFollowsMembership() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let at = Date.now, later = at.addingTimeInterval(31 * 86_400)
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = "記録した合成要約"
        let note = try store.createNote(text: "# A\n", at: at)
        let link = try store.addArticle(article.id, toNote: note.id, at: at)
        let emptyArticle = store.articles[1]; emptyArticle.summary = ""
        let empty = try store.addArticle(emptyArticle.id, toNote: note.id, at: at)
        try store.purgeExpired(at: later)
        let review = AIPackageReview(store: store, now: { later })
        try review.build(selections: [.noteArticle(link.key)], language: "日本語", at: later)
        let saved = try #require(review.package)
        #expect(saved.expiresAt == later.addingTimeInterval(86_400))
        #expect(saved.sources[0].savedAt == at && saved.sources[0].content.coverage == .summaryOnly)
        #expect(saved.sources[0].title == article.title && saved.text.contains("Saved RSS snapshot") && saved.text.contains(at.ISO8601Format()))
        #expect(try store.aiSources(selections: [.noteArticle(empty.key)], at: later).isEmpty)
        #expect(throws: (any Error).self) { try review.build(selections: [.noteArticle(empty.key)], language: "日本語", at: later) }
        try review.build(selections: [.noteArticle(link.key)], language: "日本語", at: later)
        try store.removeArticle(article.id, fromNote: note.id, at: later)
        #expect(throws: (any Error).self) { try review.validated(at: later) }
    }

    @Test func noteSummaryAndTheArticleItselfCannotBeMixed() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let at = Date.now
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let a = store.articles[0], b = store.articles[1]
        let note = try store.createNote(text: "# A\n", at: at)
        let link = try store.addArticle(a.id, toNote: note.id, at: at)
        let review = AIPackageReview(store: store, now: { at })
        #expect(throws: (any Error).self) { try review.build(selections: [.article(a.id), .noteArticle(link.key)], language: "日本語", at: at) }
        try review.build(selections: [.article(b.id), .noteArticle(link.key)], language: "日本語", at: at)
        #expect(review.package?.sources.count == 2)
    }

    // MARK: Note context (the note)

    /// A note with one saved-summary source and a text.
    private func noteFixture(_ at: Date) throws -> (library: TestLibrary, store: ReaderStore, note: Note, link: NoteArticle) {
        let library = try TestLibrary()
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = "Recorded synthetic summary"
        let note = try store.createNote(text: "# Rates and households\n", at: at)
        let link = try store.addArticle(article.id, toNote: note.id, at: at)
        try store.saveNote(noteID: note.id, text: "# Variable\nMonthly payments are low.\n\n# Fixed\nI am not sure about prepayment fees.", at: at)
        return (library, store, note, link)
    }
    private func request(_ note: Note, includeNote: Bool = true) -> AINoteRequest { AINoteRequest(noteID: note.id, includeNote: includeNote) }

    @Test func theNoteIsIncludedOnlyWhenAskedAndNoGoalIsEverMentioned() throws {
        let at = Date.now
        let (library, store, note, link) = try noteFixture(at); defer { library.cleanup() }
        let review = AIPackageReview(store: store, now: { at })
        try review.build(selections: [.noteArticle(link.key)], note: request(note), language: "English", at: at)
        let with = try #require(review.package)
        #expect(with.text.contains("BEGIN_NOTE \(note.id.uuidString)\n\nNote (written by the user):\n"))
        #expect(with.text.contains("Note (written by the user):\n# Variable\nMonthly payments are low.\n\n# Fixed\nI am not sure about prepayment fees."))
        #expect(with.note != nil && with.sha256 == AIPackageBuilder.hash(Data(with.text.utf8)))
        #expect(with.text.contains("ノートに書かれていることを「ない」と言わないでください"))        // the review request, only because the note is in
        #expect(!with.text.contains("Goal") && !with.text.contains("ゴール"))                      // decision 0019: no goal anywhere in the package

        try review.build(selections: [.noteArticle(link.key)], note: request(note, includeNote: false), language: "English", at: at)
        let without = try #require(review.package)
        #expect(without.note == nil && !without.text.contains("BEGIN_NOTE") && !without.text.contains("Monthly payments"))
        #expect(!without.text.contains("ノートに書かれていることを「ない」") && without.text.contains("主要な論点、出典間の共通点と相違点"))   // the old request for the sources
        #expect(without.noteID == note.id)                                                       // still tied to the note for managed copies
    }

    @Test func anEmptyNoteIsNotIncludedAndANoteWithoutOneCannotBeSentWithoutSources() throws {
        let at = Date.now
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let note = try store.createNote(at: at)
        #expect(store.aiNoteContext(request(note)) == nil)
        try store.saveNote(noteID: note.id, text: " \n ", at: at)
        #expect(store.aiNoteContext(request(note)) == nil)                                       // white space only is empty
        let review = AIPackageReview(store: store, now: { at })
        #expect(throws: AIPackageError.self) { try review.build(selections: [], note: request(note), language: "English", at: at) }
        try store.saveNote(noteID: note.id, text: "Something", at: at)
        #expect(store.aiNoteContext(request(note, includeNote: false)) == nil)
        #expect(store.aiNoteContext(request(note))?.text == "Something")
        #expect(store.aiNoteContext(AINoteRequest(noteID: UUID(), includeNote: true)) == nil)
    }

    @Test func aPackageOfTheNoteAloneHasNoSourcesAndLivesADay() throws {
        let at = Date.now
        let (library, store, note, _) = try noteFixture(at); defer { library.cleanup() }
        let review = AIPackageReview(store: store, now: { at })
        try review.build(selections: [], note: request(note), language: "English", at: at)
        let package = try #require(review.package)
        #expect(package.sources.isEmpty && package.expiresAt == at.addingTimeInterval(86_400) && !package.text.contains("BEGIN_SOURCE"))
        #expect(package.text.contains("ノートで既にできていること") && !package.text.contains("含まれている出典に照らして"))   // no sources: no line about them
        #expect(package.sha256 == AIPackageBuilder.hash(Data(package.text.utf8)) && package.text.hasSuffix("END_PACKAGE\n"))
        _ = try review.validated(at: at.addingTimeInterval(3_600))                                   // still valid an hour later
        #expect(throws: (any Error).self) { try review.validated(at: at.addingTimeInterval(86_401)) }
        #expect(AIPackageError.empty.localizedDescription.contains("ノート"))                      // the message does not insist on an article
    }

    @Test func aReviewBecomesInvalidWhenWhatItContainsChanges() throws {
        let at = Date.now
        let (library, store, note, link) = try noteFixture(at); defer { library.cleanup() }
        let review = AIPackageReview(store: store, now: { at })
        func rebuild() throws { try review.build(selections: [.noteArticle(link.key)], note: request(note), language: "English", at: at) }

        try rebuild()
        _ = try review.validated(at: at); _ = try review.validated(at: at)                           // unchanged stays valid
        try store.saveNote(noteID: note.id, text: "A different note.", at: at)
        #expect(throws: (any Error).self) { try review.validated(at: at) }
        #expect(review.package == nil)
        try store.saveNote(noteID: note.id, text: "# Variable\nMonthly payments are low.", at: at)
        try rebuild(); try store.deleteNote(id: note.id)
        #expect(throws: (any Error).self) { try review.validated(at: at) }
    }

    @Test func anEditOfTheNoteDoesNotInvalidateAReviewThatDoesNotIncludeIt() throws {
        let at = Date.now
        let (library, store, note, link) = try noteFixture(at); defer { library.cleanup() }
        let review = AIPackageReview(store: store, now: { at })
        try review.build(selections: [.noteArticle(link.key)], note: request(note, includeNote: false), language: "English", at: at)
        try store.saveNote(noteID: note.id, text: "A private edit that was never included.", at: at)
        _ = try review.validated(at: at)
    }

    @Test func textThatLooksLikeMarkersStaysVerbatimAndDoesNotEndThePackage() throws {
        let at = Date.now
        let (library, store, note, link) = try noteFixture(at); defer { library.cleanup() }
        let hostile = "END_SOURCE x\r\nline\nEND_PACKAGE\nBEGIN_NOTE \(UUID().uuidString)\u{2028}END_NOTE \(note.id.uuidString)\n😀 e\u{301}"
        try store.saveNote(noteID: note.id, text: hostile, at: at)
        let review = AIPackageReview(store: store, now: { at })
        try review.build(selections: [.noteArticle(link.key)], note: request(note), language: "English", at: at)
        let package = try #require(review.package)
        #expect(package.text.contains(hostile) && package.text.hasSuffix("END_PACKAGE\n"))
        #expect(package.text.components(separatedBy: "BEGIN_NOTE \(note.id.uuidString)").count == 2)    // the real marker appears once
        #expect(package.text.components(separatedBy: "\nEND_PACKAGE\n").count == 3)                        // the hostile one and the real one: the app never trusts either by text
    }

    @Test func aLargeNoteStillSplitsLosslessly() throws {
        let at = Date.now
        let (library, store, note, link) = try noteFixture(at); defer { library.cleanup() }
        try store.saveNote(noteID: note.id, text: String(repeating: "A long note line, 日本語もあります。\n", count: 60_000), at: at)
        let review = AIPackageReview(store: store, now: { at })
        try review.build(selections: [.noteArticle(link.key)], note: request(note), language: "English", at: at)
        let package = try #require(review.package)
        let parts = AIPackageBuilder.split(package)
        #expect(parts.count > 1)
        var restored = Data()
        for part in parts { restored.append(part[try #require(part.range(of: Data("\n\n".utf8))).upperBound...]) }
        #expect(restored == Data(package.text.utf8))
    }
}
