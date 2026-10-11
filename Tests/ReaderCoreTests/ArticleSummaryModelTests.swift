import Foundation
import SwiftData
import Testing
@testable import ReaderCore

@MainActor struct ArticleSummaryModelTests {
    let at = Date(timeIntervalSince1970: 1_800_000_000)
    struct Boom: Error {}

    private func settle(_ model: ArticleSummaryModel, while predicate: @MainActor (ArticleSummaryModel.State) -> Bool = { $0 == .working }) async {
        for _ in 0..<300 { if !predicate(model.state) { return }; try? await Task.sleep(for: .milliseconds(10)) }
    }
    private func makeStore(_ library: TestLibrary) throws -> ReaderStore { try ReaderStore(url: library.url, seedDemo: true, now: at) }
    private func make(_ store: ReaderStore, _ assistant: FakeGenerator, enabled: EnabledSwitch = EnabledSwitch(), deadline: Double = 5,
                      now: Date? = nil) -> ArticleSummaryModel {
        let time = now ?? at
        return ArticleSummaryModel(store: store, assistant: assistant, isEnabled: { enabled.on }, deadline: deadline, now: { time })
    }

    @Test func aSummaryIsShownOnlyAfterTheRequestAndIsCleaned() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library)
        let assistant = FakeGenerator(); await assistant.scriptGeneration(["「要約です。」\n"])
        let model = make(store, assistant)
        #expect(model.state == .idle)
        let early = await assistant.generateCalls
        #expect(early.isEmpty)                                                            // nothing happens by itself
        let id = store.articles[0].id
        model.request(articleID: id, noteID: nil)
        #expect(model.state == .working)
        await settle(model)
        #expect(model.state == .ready(.init(articleID: id, text: "要約です。", wasCut: false, fromNoteSummary: false)))
        let calls = await assistant.generateCalls
        #expect(calls.count == 1 && calls[0].prompt.contains(store.article(id: id)!.title) && calls[0].maximumTokens == 400)
    }

    @Test func nothingIsCalledWhenTheSettingIsOff() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library)
        let assistant = FakeGenerator(); await assistant.scriptGeneration(["x"])
        let enabled = EnabledSwitch(); enabled.on = false
        let model = make(store, assistant, enabled: enabled)
        model.request(articleID: store.articles[0].id, noteID: nil)
        #expect(model.state == .unavailable(.disabled))
        let (calls, availabilityCalls) = (await assistant.generateCalls, await assistant.generationAvailabilityCalls)
        #expect(calls.isEmpty && availabilityCalls == 0)
    }

    @Test func switchingTheSettingOffWhileWorkingDropsTheAnswer() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library)
        let assistant = FakeGenerator(); await assistant.scriptGeneration(["要約"], hold: true)
        let enabled = EnabledSwitch()
        let model = make(store, assistant, enabled: enabled)
        model.request(articleID: store.articles[0].id, noteID: nil)
        while !(await assistant.generationParked) { try await Task.sleep(for: .milliseconds(5)) }
        enabled.on = false
        await assistant.releaseGeneration()
        await settle(model)
        #expect(model.state == .unavailable(.disabled))
    }

    @Test func anUnavailableModelIsExplainedAndNotCalled() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library)
        for (availability, reason) in [(AssistantAvailability.unsupported, ArticleSummaryModel.Reason.unsupported), (.assetsMissing, .assetsMissing)] {
            let assistant = FakeGenerator(); await assistant.scriptGeneration(["x"], availability: availability)
            let model = make(store, assistant)
            model.request(articleID: store.articles[0].id, noteID: nil)
            await settle(model)
            #expect(model.state == .unavailable(reason))
            let made = await assistant.generateCalls
            #expect(made.isEmpty)
        }
        let none = ArticleSummaryModel(store: store, assistant: nil, isEnabled: { true })
        none.request(articleID: store.articles[0].id, noteID: nil)
        #expect(none.state == .unavailable(.unsupported))
    }

    @Test func aFailureABlankAnswerAndTheDeadlineAreFailedAndTheModelCanBeUsedAgain() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library)
        let id = store.articles[0].id
        let failing = FakeGenerator(); await failing.scriptGeneration(failure: Boom())
        let one = make(store, failing); one.request(articleID: id, noteID: nil); await settle(one)
        #expect(one.state == .failed)
        let blank = FakeGenerator(); await blank.scriptGeneration(["  \u{200B}\n"])
        let two = make(store, blank); two.request(articleID: id, noteID: nil); await settle(two)
        #expect(two.state == .failed)
        let slow = FakeGenerator(); await slow.scriptGeneration(["遅い"], hold: true)
        let three = make(store, slow, deadline: 0.05); three.request(articleID: id, noteID: nil); await settle(three)
        #expect(three.state == .failed)
        await slow.releaseGeneration()
        await slow.scriptGeneration(["次は成功"])
        three.request(articleID: id, noteID: nil); await settle(three)
        if case .ready(let summary) = three.state { #expect(summary.text == "次は成功") } else { Issue.record("expected a summary, got \(three.state)") }
    }

    @Test func aLateAnswerForAnotherArticleOrAfterResetOrCancelIsDropped() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library)
        let (first, second) = (store.articles[0].id, store.articles[1].id)
        let assistant = FakeGenerator(); await assistant.scriptGeneration(["古い答え", "新しい答え"], hold: true)
        let model = make(store, assistant)
        model.request(articleID: first, noteID: nil)
        while !(await assistant.generationParked) { try await Task.sleep(for: .milliseconds(5)) }
        model.reset()                                                                     // the person moved on
        #expect(model.state == .idle)
        await assistant.releaseGeneration()                                               // the old call finishes anyway
        try await Task.sleep(for: .milliseconds(100))
        #expect(model.state == .idle)
        model.request(articleID: second, noteID: nil)
        while !(await assistant.generationParked) { try await Task.sleep(for: .milliseconds(5)) }
        model.cancel()
        #expect(model.state == .idle)
        await assistant.releaseGeneration()
        try await Task.sleep(for: .milliseconds(100))
        #expect(model.state == .idle)
    }

    @Test func aSecondRequestReplacesTheFirstAndOnlyItsAnswerShows() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library)
        let (first, second) = (store.articles[0].id, store.articles[1].id)
        let assistant = FakeGenerator(); await assistant.scriptGeneration(["一つ目", "二つ目"], hold: true)
        let model = make(store, assistant)
        model.request(articleID: first, noteID: nil)
        while !(await assistant.generationParked) { try await Task.sleep(for: .milliseconds(5)) }
        model.request(articleID: second, noteID: nil)                                    // replaces; the first call is parked too
        try await Task.sleep(for: .milliseconds(50))
        await assistant.releaseGeneration()
        await settle(model)
        try await Task.sleep(for: .milliseconds(100))
        if case .ready(let summary) = model.state { #expect(summary.articleID == second) } else { Issue.record("expected a summary, got \(model.state)") }
    }

    @Test func noRetainedTextMeansNoCallAndNoteSummaryIsTheFallback() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library)
        let id = store.articles[0].id
        let note = try store.createNote(text: "# T\n", at: at)
        try store.addArticle(id, toNote: note.id, at: at)
        let recorded = try #require(store.noteArticles.first { $0.articleID == id }?.summary)
        #expect(!recorded.isEmpty)
        let late = at.addingTimeInterval(400 * 86_400)                                     // past the longest retention
        let assistant = FakeGenerator(); await assistant.scriptGeneration(["記録からの要約"])
        let withNote = make(store, assistant, now: late)
        withNote.request(articleID: id, noteID: note.id); await settle(withNote)
        if case .ready(let summary) = withNote.state { #expect(summary.fromNoteSummary && summary.text == "記録からの要約") } else { Issue.record("got \(withNote.state)") }
        let firstCall = await assistant.generateCalls.first
        #expect(firstCall?.prompt.contains(recorded) == true)
        let noNote = make(store, assistant, now: late)
        noNote.request(articleID: id, noteID: nil)
        #expect(noNote.state == .unavailable(.noText))
        let other = try store.createNote(text: "# Other\n", at: at)
        noNote.request(articleID: id, noteID: other.id)                                  // not a member of that note
        #expect(noNote.state == .unavailable(.noText))
        let total = await assistant.generateCalls.count
        #expect(total == 1)
    }

    @Test func aLongBodyIsMarkedAsCutAndTheStoreIsNeverWritten() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library)
        let article = store.articles[0]
        let result = ExtractionResult(text: String(repeating: "長い本文。", count: 1_000), coverage: .extracted, sourceURL: URL(string: "https://example.com/a")!)
        try store.saveExtractedContent(articleID: article.id, result: result, at: at)
        let note = try store.createNote(text: "# T\n", at: at)
        try store.addArticle(article.id, toNote: note.id, at: at)
        try store.saveNote(noteID: note.id, text: "自分のノート", at: at)
        let stamp = note.updatedAt, links = store.noteArticles.count, read = article.isRead
        let assistant = FakeGenerator(); await assistant.scriptGeneration(["要約"])
        let model = make(store, assistant)
        model.request(articleID: article.id, noteID: note.id); await settle(model)
        if case .ready(let summary) = model.state { #expect(summary.wasCut && !summary.fromNoteSummary) } else { Issue.record("got \(model.state)") }
        #expect(note.text == "自分のノート" && note.updatedAt == stamp && store.noteArticles.count == links && article.isRead == read)
        let prompt = try #require(await assistant.generateCalls.first?.prompt)
        #expect(prompt.count < 3_100)
    }
}
