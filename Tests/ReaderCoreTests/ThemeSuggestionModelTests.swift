import Foundation
import Testing
@testable import ReaderCore

/// Scripted stand-in for the real model. A held call parks until released, so tests can finish requests in any order.
actor FakeAssistant: ThemeAssistant {
    struct NearestCall: Sendable { let item: SuggestionItem; let candidates: [ThemeCandidateInput]; let background: [SuggestionItem] }
    struct ClusterCall: Sendable { let items: [SuggestionItem]; let background: [SuggestionItem] }
    private var availabilityValue = AssistantAvailability.available
    private var nearestByArticle: [UUID: [ThemeMatch]] = [:]
    private var groups: [[UUID]] = []
    private var failure: (any Error)?
    private var holding = false
    private(set) var nearestCalls: [NearestCall] = []
    private(set) var clusterCalls: [ClusterCall] = []
    private(set) var availabilityCalls = 0
    private var parked: [UUID: CheckedContinuation<Void, Never>] = [:]
    private var parkedClusters: CheckedContinuation<Void, Never>?
    private var generated: [String] = []
    private var generationFailure: (any Error)?
    private var generationAvailabilityValue = AssistantAvailability.available
    private var holdGeneration = false
    private var parkedGeneration: CheckedContinuation<Void, Never>?
    private(set) var generateCalls: [SuggestionPrompts.Request] = []
    private(set) var generationAvailabilityCalls = 0

    func scriptGeneration(_ outputs: [String] = [], failure: (any Error)? = nil, hold: Bool = false, availability: AssistantAvailability = .available) {
        generated = outputs; generationFailure = failure; holdGeneration = hold; generationAvailabilityValue = availability
    }
    var generationParked: Bool { parkedGeneration != nil }
    func releaseGeneration() { parkedGeneration?.resume(); parkedGeneration = nil }

    func generationAvailability() async -> AssistantAvailability { generationAvailabilityCalls += 1; return generationAvailabilityValue }
    func generate(_ request: SuggestionPrompts.Request) async throws -> String {
        generateCalls.append(request)
        if holdGeneration { await withCheckedContinuation { parkedGeneration = $0 } }
        if let generationFailure { throw generationFailure }
        return generated.isEmpty ? "" : generated.removeFirst()
    }

    func script(nearest: [UUID: [ThemeMatch]] = [:], groups: [[UUID]] = [], failure: (any Error)? = nil, hold: Bool = false,
                availability: AssistantAvailability = .available) {
        nearestByArticle = nearest; self.groups = groups; self.failure = failure; holding = hold; availabilityValue = availability
    }
    var parkedCount: Int { parked.count + (parkedClusters == nil ? 0 : 1) }
    func release(article id: UUID) { parked.removeValue(forKey: id)?.resume() }
    func releaseClusters() { parkedClusters?.resume(); parkedClusters = nil }

    func availability() async -> AssistantAvailability { availabilityCalls += 1; return availabilityValue }
    func nearestThemes(for item: SuggestionItem, candidates: [ThemeCandidateInput], background: [SuggestionItem]) async throws -> [ThemeMatch] {
        nearestCalls.append(NearestCall(item: item, candidates: candidates, background: background))
        if holding { await withCheckedContinuation { parked[item.id] = $0 } }
        if let failure { throw failure }
        return nearestByArticle[item.id] ?? []
    }
    func clusters(of items: [SuggestionItem], background: [SuggestionItem]) async throws -> [[UUID]] {
        clusterCalls.append(ClusterCall(items: items, background: background))
        if holding { await withCheckedContinuation { parkedClusters = $0 } }
        if let failure { throw failure }
        return groups
    }
}

/// A switch the tests can flip while a request is in flight, without capturing a mutable local in a Sendable closure.
@MainActor final class SuggestionSwitch { var on = true }

@MainActor struct ThemeSuggestionModelTests {
    let at = Date(timeIntervalSince1970: 1_791_152_000)
    struct Boom: Error {}

    /// `count` synthetic articles, newest first: 記事 0 is the newest.
    func makeStore(_ library: TestLibrary, articles count: Int) throws -> ReaderStore {
        let store = try ReaderStore(url: library.url, now: at)
        let entries = (0..<count).map { index in
            ParsedEntry(sourceID: "s-\(index)", title: "記事 \(index)", url: URL(string: "https://synthetic.example/\(index)"),
                        summary: "要約 \(index)", body: "本文 \(index)", coverage: .feedProvided,
                        publishedAt: at.addingTimeInterval(Double(-index) * 60))
        }
        _ = try store.importFeed(ParsedFeed(title: "合成購読", sourceURL: URL(string: "https://synthetic.example/feed")!,
                                            entries: entries, skippedEntries: 0), receivedAt: at)
        return store
    }
    func model(_ store: ReaderStore, _ assistant: (any ThemeAssistant)?, enabled: Bool = true) -> ThemeSuggestionModel {
        ThemeSuggestionModel(store: store, assistant: assistant, isEnabled: { enabled }, now: { self.at })
    }
    func waitUntil(_ condition: () async -> Bool) async throws {
        for _ in 0..<200 { if await condition() { return }; try await Task.sleep(for: .milliseconds(10)) }
        let reached = await condition()
        #expect(reached, "condition not reached")
    }

    @Test func aDisabledOrMissingAssistantIsNeverCalledAndLeavesNothing() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 4)
        let theme = try store.createTheme(name: "A", adding: [store.articles[1].id], at: at)
        let fake = FakeAssistant()
        let off = model(store, fake, enabled: false)
        await off.loadNearest(for: store.articles[0].id)
        for id in store.articles.prefix(3).map(\.id) { try store.setStar(articleID: id, isStarred: true, at: at) }
        await off.loadClusters(); await off.refreshAvailability()
        let (nearestCalls, clusterCalls, availabilityCalls) = (await fake.nearestCalls, await fake.clusterCalls, await fake.availabilityCalls)
        #expect(nearestCalls.isEmpty && clusterCalls.isEmpty && availabilityCalls == 0)
        #expect(off.nearestThemes.isEmpty && off.clusters == .empty && off.availability == nil)
        let none = model(store, nil)
        await none.loadNearest(for: store.articles[0].id); await none.loadClusters(); await none.refreshAvailability()
        #expect(none.nearestThemes.isEmpty && none.clusters == .empty && none.availability == .unsupported)
        _ = theme
    }

    @Test func nearestSendsSnapshotCandidatesNewestFirstCappedAndAnItemWithSummary() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 70)
        let ids = store.articles.map(\.id)
        let subject = ids[0]
        let theme = try store.createTheme(name: "A", at: at)
        for (offset, id) in ids[20..<35].enumerated() { try store.addArticle(id, toTheme: theme.id, at: at.addingTimeInterval(Double(offset))) }
        _ = try store.createTheme(name: "空", at: at)
        let fake = FakeAssistant()
        let suggestions = model(store, fake)
        await suggestions.loadNearest(for: subject)
        let nearestCalls = await fake.nearestCalls
        let call = try #require(nearestCalls.first)
        #expect(call.item.id == subject && call.item.text == "記事 0\n要約 0")
        #expect(call.candidates.count == 1)                                   // the empty theme is not a candidate
        let members = call.candidates[0].members
        #expect(members.count == SuggestionTuning.maximumMembersPerTheme)
        #expect(members.first?.id == ids[34] && members.last?.id == ids[25])    // newest additions first
        #expect(members.first?.text == "記事 34\n要約 34")                       // the theme's recorded snapshot
        #expect(call.background.count == SuggestionTuning.backgroundItems)
        let used = Set([subject] + members.map(\.id))
        #expect(call.background.allSatisfy { !used.contains($0.id) })
        #expect(call.background.first?.id == ids[1])                             // newest articles first
    }

    @Test func expiredContentContributesOnlyItsTitleAndLongTextIsCut() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 3)
        let expired = store.articles[0], long = store.articles[1]
        expired.contentDeletedAt = at
        long.summary = String(repeating: "あ", count: 1_000)
        let fake = FakeAssistant()
        let suggestions = model(store, fake)
        _ = try store.createTheme(name: "A", adding: [store.articles[2].id], at: at)
        await suggestions.loadNearest(for: expired.id)
        await suggestions.loadNearest(for: long.id)
        let calls = await fake.nearestCalls
        #expect(calls[0].item.text == "記事 0")
        #expect(calls[1].item.text.count == SuggestionTuning.textCharacterLimit && calls[1].item.text.hasPrefix("記事 1\nあ"))
    }

    @Test func noThemesMeansNoCallAndNoSuggestions() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 3)
        _ = try store.createTheme(name: "空", at: at)
        let fake = FakeAssistant()
        let suggestions = model(store, fake)
        await suggestions.loadNearest(for: store.articles[0].id)
        let calls = await fake.nearestCalls
        #expect(calls.isEmpty && suggestions.nearestThemes.isEmpty)
        #expect(suggestions.nearestArticleID == store.articles[0].id)
    }

    @Test func aLateAnswerForAnEarlierArticleIsDiscarded() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 4)
        let theme = try store.createTheme(name: "A", adding: [store.articles[3].id], at: at)
        let (first, second) = (store.articles[0].id, store.articles[1].id)
        let fake = FakeAssistant()
        await fake.script(nearest: [first: [ThemeMatch(themeID: theme.id, score: 0.2)], second: [ThemeMatch(themeID: theme.id, score: 0.9)]], hold: true)
        let suggestions = model(store, fake)
        let early = Task { await suggestions.loadNearest(for: first) }
        try await waitUntil { await fake.parkedCount == 1 }
        let late = Task { await suggestions.loadNearest(for: second) }
        try await waitUntil { await fake.parkedCount == 2 }
        await fake.release(article: second); await late.value
        await fake.release(article: first); await early.value          // arrives last, must not overwrite
        #expect(suggestions.nearestArticleID == second && suggestions.nearestThemes.map(\.score) == [0.9])
    }

    @Test func switchingTheAssistantOffWhileWaitingDiscardsTheAnswer() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 3)
        let theme = try store.createTheme(name: "A", adding: [store.articles[2].id], at: at)
        let subject = store.articles[0].id
        let fake = FakeAssistant()
        await fake.script(nearest: [subject: [ThemeMatch(themeID: theme.id, score: 0.5)]], hold: true)
        let enabled = SuggestionSwitch()
        let suggestions = ThemeSuggestionModel(store: store, assistant: fake, isEnabled: { enabled.on }, now: { self.at })
        let task = Task { await suggestions.loadNearest(for: subject) }
        try await waitUntil { await fake.parkedCount == 1 }
        enabled.on = false
        await fake.release(article: subject); await task.value
        #expect(suggestions.nearestThemes.isEmpty)
    }

    @Test func suggestionsForDeletedThemesAreDroppedAndFailuresAreQuiet() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 3)
        let theme = try store.createTheme(name: "A", adding: [store.articles[2].id], at: at)
        let subject = store.articles[0].id
        let fake = FakeAssistant()
        await fake.script(nearest: [subject: [ThemeMatch(themeID: theme.id, score: 0.5), ThemeMatch(themeID: UUID(), score: 0.4)]])
        let suggestions = model(store, fake)
        await suggestions.loadNearest(for: subject)
        #expect(suggestions.nearestThemes.map(\.themeID) == [theme.id])
        await fake.script(failure: Boom())
        await suggestions.loadNearest(for: subject)
        #expect(suggestions.nearestThemes.isEmpty)
    }

    @Test func clustersNeedThreeUnfiledArticlesAndUseTheNewestOnesUpToTheCap() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 130)
        let ids = store.articles.map(\.id)
        for id in ids.prefix(2) { try store.setStar(articleID: id, isStarred: true, at: at) }
        let fake = FakeAssistant()
        let suggestions = model(store, fake)
        await suggestions.loadClusters()
        let earlyCalls = await fake.clusterCalls
        #expect(earlyCalls.isEmpty && suggestions.clusters == .empty)
        for id in ids { try store.setStar(articleID: id, isStarred: true, at: at) }
        await fake.script(groups: [[ids[0], ids[1]], [ids[2], ids[3], ids[4]], [ids[5]]])
        await suggestions.loadClusters()
        let clusterCalls = await fake.clusterCalls
        let call = try #require(clusterCalls.first)
        #expect(call.items.count == SuggestionTuning.maximumClusterItems && call.items.first?.id == ids[0])
        #expect(suggestions.clusters.usedCount == 120 && suggestions.clusters.totalCount == 130)
        #expect(suggestions.clusters.groups == [[ids[0], ids[1]], [ids[2], ids[3], ids[4]]])   // a single member is not a cluster
        #expect(!suggestions.isFindingClusters)
    }

    @Test func clusterMembersWhoLeftTheInboxAreRemovedAndAtMostFiveGroupsRemain() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 16)
        let ids = store.articles.map(\.id)
        for id in ids { try store.setStar(articleID: id, isStarred: true, at: at) }
        let fake = FakeAssistant()
        let pairs = stride(from: 0, to: 14, by: 2).map { [ids[$0], ids[$0 + 1]] }      // 7 pairs
        await fake.script(groups: pairs, hold: true)
        let suggestions = model(store, fake)
        let task = Task { await suggestions.loadClusters() }
        try await waitUntil { await fake.parkedCount == 1 }
        #expect(suggestions.isFindingClusters)
        _ = try store.createTheme(name: "先に作った", adding: [ids[1]], at: at)        // leaves the inbox while the model works
        await fake.releaseClusters(); await task.value
        #expect(suggestions.clusters.groups.count == 5)
        #expect(!suggestions.clusters.groups.joined().contains(ids[1]) && !suggestions.clusters.groups.contains([ids[0]]))
        #expect(suggestions.clusters.groups.first == [ids[2], ids[3]])                  // the pair broken by the new theme is gone
    }

    @Test func invalidateDiscardsWhatIsStillInFlight() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 5)
        let ids = store.articles.map(\.id)
        for id in ids.prefix(4) { try store.setStar(articleID: id, isStarred: true, at: at) }
        let fake = FakeAssistant()
        await fake.script(groups: [[ids[0], ids[1]]], hold: true)
        let suggestions = model(store, fake)
        let task = Task { await suggestions.loadClusters() }
        try await waitUntil { await fake.parkedCount == 1 }
        suggestions.invalidate()
        #expect(!suggestions.isFindingClusters)
        await fake.releaseClusters(); await task.value
        #expect(suggestions.clusters == .empty)
    }

    @Test func switchingTheAssistantOffWhileFindingClustersDiscardsTheGroups() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 5)
        let ids = store.articles.map(\.id)
        for id in ids.prefix(4) { try store.setStar(articleID: id, isStarred: true, at: at) }
        let fake = FakeAssistant()
        await fake.script(groups: [[ids[0], ids[1]]], hold: true)
        let enabled = SuggestionSwitch()
        let suggestions = ThemeSuggestionModel(store: store, assistant: fake, isEnabled: { enabled.on }, now: { self.at })
        let task = Task { await suggestions.loadClusters() }
        try await waitUntil { await fake.parkedCount == 1 }
        enabled.on = false
        await fake.releaseClusters(); await task.value
        #expect(suggestions.clusters == .empty && !suggestions.isFindingClusters)
    }

    @Test func availabilityIsReportedOnlyWhileEnabled() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 1)
        let fake = FakeAssistant()
        await fake.script(availability: .assetsMissing)
        let suggestions = model(store, fake)
        await suggestions.refreshAvailability()
        #expect(suggestions.availability == .assetsMissing)
    }

    @Test func aNameIsProposedFromTheGroupsArticlesAndJunkIsCleaned() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 20)
        let ids = store.articles.map(\.id)
        let fake = FakeAssistant()
        await fake.scriptGeneration(["「住宅ローンの金利変動と家計の負担」}」この記事は…"])
        let suggestions = model(store, fake)
        let name = await suggestions.proposeName(forArticles: Array(ids.prefix(18)))
        #expect(name == "住宅ローンの金利変動と家計の負担")
        let calls = await fake.generateCalls
        let lines = calls[0].prompt.split(separator: "\n").filter { $0.hasPrefix("- ") }
        #expect(lines.count == SuggestionPrompts.maximumItems && lines.first == "- 記事 0 要約 0")
        #expect(await suggestions.proposeName(forArticles: [ids[0]]) == nil)          // one article is not a group
        let after = await fake.generateCalls
        #expect(after.count == 1)
    }

    @Test func aBrokenNameOrAFailureOrADisabledSwitchGivesNoProposalAndNoCall() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 4)
        let ids = Array(store.articles.map(\.id).prefix(3))
        let fake = FakeAssistant()
        await fake.scriptGeneration([""])
        let suggestions = model(store, fake)
        #expect(await suggestions.proposeName(forArticles: ids) == nil)               // empty output
        await fake.scriptGeneration(failure: Boom())
        #expect(await suggestions.proposeName(forArticles: ids) == nil)               // guardrail / overflow / anything
        await fake.scriptGeneration(["金利と家計"])
        let off = model(store, fake, enabled: false)
        #expect(await off.proposeName(forArticles: ids) == nil)
        await off.refreshAvailability()
        let (calls, availabilityCalls) = (await fake.generateCalls, await fake.generationAvailabilityCalls)
        #expect(calls.count == 2 && availabilityCalls == 0)                           // the disabled model called nothing
        #expect(await model(store, nil).proposeName(forArticles: ids) == nil)
    }

    @Test func aProposalThatArrivesAfterTheSwitchWasTurnedOffIsDropped() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 4)
        let ids = Array(store.articles.map(\.id).prefix(3))
        let fake = FakeAssistant()
        await fake.scriptGeneration(["金利と家計"], hold: true)
        let enabled = SuggestionSwitch()
        let suggestions = ThemeSuggestionModel(store: store, assistant: fake, isEnabled: { enabled.on }, now: { self.at })
        let task = Task { await suggestions.proposeName(forArticles: ids) }
        try await waitUntil { await fake.generationParked }
        enabled.on = false
        await fake.releaseGeneration()
        #expect(await task.value == nil)
    }

    @Test func aQuestionProposalUsesTheThemesRecordedArticlesAndTheTemplate() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 30)
        let ids = store.articles.map(\.id)
        let theme = try store.createTheme(name: "金利と家計", at: at)
        for (offset, id) in ids[5..<25].enumerated() { try store.addArticle(id, toTheme: theme.id, at: at.addingTimeInterval(Double(offset))) }
        let question = try store.addQuestion(themeID: theme.id, lens: .tradeoff, at: at)
        let fake = FakeAssistant()
        await fake.scriptGeneration(["住宅ローンを組む家計は、金利上昇と引き換えに何を手放すのか。"])
        let suggestions = model(store, fake)
        let proposal = await suggestions.proposeQuestion(for: question.id)
        #expect(proposal == "住宅ローンを組む家計は、金利上昇と引き換えに何を手放すのか。")
        let request = try #require(await fake.generateCalls.first)
        #expect(request.prompt.contains(question.text) && request.prompt.contains("テーマ: 金利と家計"))
        let lines = request.prompt.split(separator: "\n").filter { $0.hasPrefix("- ") }
        #expect(lines.count == SuggestionPrompts.maximumItems && lines.first == "- 記事 24 要約 24")      // newest additions first
    }

    @Test func noQuestionProposalForAnEditedAFreeOrAMissingQuestionOrAnUnchangedAnswer() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 4)
        let theme = try store.createTheme(name: "A", adding: [store.articles[0].id, store.articles[1].id], at: at)
        let edited = try store.addQuestion(themeID: theme.id, lens: .assumption, at: at)
        try store.updateQuestion(id: edited.id, text: "自分で直した問いです、どうなるか。", at: at)
        let free = try store.addQuestion(themeID: theme.id, lens: .custom, text: "自由な問いをここに書きます。", at: at)
        let plain = try store.addQuestion(themeID: theme.id, lens: .exception, at: at)
        let fake = FakeAssistant()
        let suggestions = model(store, fake)
        await fake.scriptGeneration(["自分で直した問いです、どうなるか。"])
        #expect(await suggestions.proposeQuestion(for: edited.id) == nil)
        #expect(await suggestions.proposeQuestion(for: free.id) == nil)
        #expect(await suggestions.proposeQuestion(for: UUID()) == nil)
        let untouched = await fake.generateCalls
        #expect(untouched.isEmpty)
        await fake.scriptGeneration([plain.text])                                        // the model just repeats the template
        #expect(await suggestions.proposeQuestion(for: plain.id) == nil)
        await fake.scriptGeneration(["これは問いではなく、記事の要約です。"])
        #expect(await suggestions.proposeQuestion(for: plain.id) == nil)                 // not a question
    }

    @Test func aQuestionProposalIsDroppedWhenTheQuestionWasEditedWhileWaiting() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 4)
        let theme = try store.createTheme(name: "A", adding: [store.articles[0].id, store.articles[1].id], at: at)
        let question = try store.addQuestion(themeID: theme.id, lens: .condition, at: at)
        let fake = FakeAssistant()
        await fake.scriptGeneration(["この条件が変わると、結論はどう変わるのだろうか。"], hold: true)
        let suggestions = model(store, fake)
        let task = Task { await suggestions.proposeQuestion(for: question.id) }
        try await waitUntil { await fake.generationParked }
        try store.updateQuestion(id: question.id, text: "本人が書き直した問いはこちらです。", at: at)
        await fake.releaseGeneration()
        #expect(await task.value == nil)
    }

    @Test func generationAvailabilityIsReportedOnlyWhileEnabled() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 1)
        let fake = FakeAssistant()
        await fake.scriptGeneration(availability: .assetsMissing)
        let suggestions = model(store, fake)
        await suggestions.refreshAvailability()
        #expect(suggestions.generationAvailability == .assetsMissing)
        let off = model(store, fake, enabled: false)
        await off.refreshAvailability()
        #expect(off.generationAvailability == nil)
    }
}
