import Foundation
import SwiftData
import Testing
@testable import ReaderCore

@MainActor struct LegacyNoteMigrationTests {
    let at = Date(timeIntervalSince1970: 1_800_000_000)
    final class SaveGate { var failNext = false }

    private func gatedStore(_ library: TestLibrary, _ gate: SaveGate) throws -> ReaderStore {
        let schema = ReaderStore.schema
        let container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration("Reader", schema: schema, url: library.url, cloudKitDatabase: .none)])
        return try ReaderStore(container: container, seedDemo: true, now: at, saveHook: {
            if gate.failNext { gate.failNext = false; throw CocoaError(.fileWriteUnknown) }
        })
    }

    /// Four themes in the shapes an older library can have.
    private struct Library {
        var a, b, c, d: Theme
    }
    private func fill(_ store: ReaderStore) throws -> Library {
        let ids = store.articles.map(\.id)
        let a = try store.createTheme(name: "A", at: at)
        try store.addArticle(ids[0], toTheme: a.id, at: at); try store.addArticle(ids[1], toTheme: a.id, at: at)
        try store.saveUnderstanding(themeID: a.id, text: "Aの理解", at: at)
        let answered = try store.addQuestion(themeID: a.id, lens: .custom, text: "Aの問い1", at: at)
        try store.saveAnswer(questionID: answered.id, answer: "Aの答え1", at: at)
        try store.setEvidence(questionID: answered.id, articleIDs: [ids[0], ids[1]], at: at)
        try store.addQuestion(themeID: a.id, lens: .custom, text: "Aの問い2", at: at.addingTimeInterval(1))
        let b = try store.createTheme(name: "B", at: at.addingTimeInterval(1))
        try store.saveUnderstanding(themeID: b.id, text: "Bの理解", at: at)
        let c = try store.createTheme(name: "C", at: at.addingTimeInterval(2))
        let blank = try store.addQuestion(themeID: c.id, lens: .custom, text: "Cの問い", at: at)
        try store.saveAnswer(questionID: blank.id, answer: " \n ", at: at)
        let d = try store.createTheme(name: "D", at: at.addingTimeInterval(3))
        return Library(a: a, b: b, c: c, d: d)
    }
    private func expectedA(_ store: ReaderStore) -> String {
        let ids = store.articles.map(\.id)
        func line(_ id: UUID) -> String { let link = store.themeArticles.first { $0.articleID == id }!; return "- \(link.title)" + (link.url.map { " <\($0)>" } ?? "") }
        return "Aの理解\n\n# Aの問い1\n\nAの答え1\n\n根拠の記事:\n\(line(ids[0]))\n\(line(ids[1]))\n\n# Aの問い2\n"
    }

    @Test func migrationMovesEverythingAndRemovesTheOldRecords() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let ids: (UUID, UUID, UUID, UUID) = try {
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let l = try fill(store)
            let result = try store.migrateLegacyThemeContent(at: at.addingTimeInterval(50))
            #expect(result == LegacyNoteMigrationResult(themes: 3, questions: 3))
            #expect(l.a.note == expectedA(store) && l.b.note == "Bの理解\n" && l.c.note == "# Cの問い\n" && l.d.note == "")
            #expect(store.themeQuestions.isEmpty && store.themes.allSatisfy { $0.understanding.isEmpty })
            #expect(l.d.updatedAt == at.addingTimeInterval(3) && l.a.updatedAt == at.addingTimeInterval(50))
            return (l.a.id, l.b.id, l.c.id, l.d.id)
        }()
        let reopened = try ReaderStore(url: library.url, now: at)
        #expect(reopened.theme(id: ids.0)?.note == expectedA(reopened) && reopened.theme(id: ids.1)?.note == "Bの理解\n")
        #expect(reopened.theme(id: ids.2)?.note == "# Cの問い\n" && reopened.theme(id: ids.3)?.note == "")
        #expect(reopened.themeQuestions.isEmpty)
    }

    @Test func aSecondCallDoesNothingAndDoesNotNotify() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let l = try fill(store)
        let counter = Counter(); store.onContentPolicyChanged = { counter.count += 1 }
        try store.migrateLegacyThemeContent(at: at)
        #expect(counter.count == 1)
        let stamp = l.a.updatedAt, note = l.a.note
        #expect(try store.migrateLegacyThemeContent(at: at.addingTimeInterval(99)) == LegacyNoteMigrationResult(themes: 0, questions: 0))
        #expect(counter.count == 1 && l.a.updatedAt == stamp && l.a.note == note)
    }
    final class Counter { var count = 0 }

    @Test func nothingToMigrateDoesNotNotify() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        _ = try store.createTheme(name: "Empty", at: at)
        let counter = Counter(); store.onContentPolicyChanged = { counter.count += 1 }
        #expect(try store.migrateLegacyThemeContent(at: at) == LegacyNoteMigrationResult(themes: 0, questions: 0))
        #expect(counter.count == 0)
    }

    @Test func existingNoteTextIsKeptAndTheOldTextFollowsIt() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let theme = try store.createTheme(name: "T", at: at)
        try store.saveNote(themeID: theme.id, text: "もともとのノート\n", at: at)
        try store.saveUnderstanding(themeID: theme.id, text: "古い理解", at: at)
        try store.addQuestion(themeID: theme.id, lens: .custom, text: "古い問い", at: at)
        try store.migrateLegacyThemeContent(at: at)
        #expect(theme.note == "もともとのノート\n\n古い理解\n\n# 古い問い\n")
    }

    @Test func evidenceForAnArticleThatLeftTheThemeIsNotListed() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let ids = store.articles.map(\.id)
        let theme = try store.createTheme(name: "T", at: at)
        try store.addArticle(ids[0], toTheme: theme.id, at: at); try store.addArticle(ids[1], toTheme: theme.id, at: at)
        let question = try store.addQuestion(themeID: theme.id, lens: .custom, text: "問い", at: at)
        try store.setEvidence(questionID: question.id, articleIDs: [ids[0], ids[1]], at: at)
        try store.removeArticle(ids[0], fromTheme: theme.id, at: at)
        try store.migrateLegacyThemeContent(at: at)
        let kept = store.themeArticles.first { $0.articleID == ids[1] }!.title
        let removed = store.article(id: ids[0])!.title
        #expect(theme.note.contains("- " + kept) && !theme.note.contains(removed))
    }

    @Test func aFailedSaveChangesNothingAndARetrySucceeds() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let gate = SaveGate()
        let store = try gatedStore(library, gate)
        let l = try fill(store)
        let counter = Counter(); store.onContentPolicyChanged = { counter.count += 1 }
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.migrateLegacyThemeContent(at: at) }
        #expect(store.themes.allSatisfy { $0.note.isEmpty } && store.themeQuestions.count == 3)
        #expect(store.theme(id: l.a.id)?.understanding == "Aの理解" && store.theme(id: l.b.id)?.understanding == "Bの理解")
        #expect(counter.count == 0)
        #expect(try store.migrateLegacyThemeContent(at: at) == LegacyNoteMigrationResult(themes: 3, questions: 3))
        #expect(store.theme(id: l.a.id)?.note == expectedA(store))
    }

    @Test func aVerificationFailureDeletesNothingAndSavesNothing() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let l = try fill(store)
        #expect(throws: LegacyNoteMigrationError.self) {
            try store.migrateLegacyThemeContent(at: at) { _, understanding, _ in understanding }     // drops every question
        }
        #expect(store.themes.allSatisfy { $0.note.isEmpty } && store.themeQuestions.count == 3)
        #expect(l.a.understanding == "Aの理解")
        let reopened = try ReaderStore(url: library.url, now: at)
        #expect(reopened.themeQuestions.count == 3 && reopened.themes.allSatisfy { $0.note.isEmpty })
    }
}
