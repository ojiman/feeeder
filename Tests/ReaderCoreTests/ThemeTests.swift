import Foundation
import SwiftData
import Testing
@testable import ReaderCore

@MainActor struct ThemeTests {
    let at = Date(timeIntervalSince1970: 1_791_152_000)
    let day: TimeInterval = 86_400

    /// Decision 0019: no questions, no understanding text. A store that still has them opens and drops them (PreNoteStoreUpgradeTests).
    @Test func theSchemaHasNoQuestionModel() {
        let names = ReaderStore.schema.entities.map(\.name)
        #expect(!names.contains("ThemeQuestion") && names.contains("Theme") && names.contains("ThemeArticle"))
        #expect(Theme(name: "x", at: at).note == "")
    }

    @Test func createTrimsNameAndRejectsBlank() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let theme = try store.createTheme(name: "  LLMの実用設計  ", at: at)
        #expect(theme.name == "LLMの実用設計" && theme.note.isEmpty)
        #expect(store.themes.map(\.id) == [theme.id] && store.theme(id: theme.id)?.id == theme.id)
        #expect(throws: ThemeError.self) { try store.createTheme(name: "   \n", at: at) }
        #expect(store.themes.count == 1)
    }

    @Test func renameAndNotePersistAcrossReopen() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let id = try autoreleasepool {
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let theme = try store.createTheme(name: "金利", at: at)
            try store.renameTheme(id: theme.id, to: " 金利と家計 ", at: at.addingTimeInterval(10))
            try store.saveNote(themeID: theme.id, text: "いまのノート", at: at.addingTimeInterval(20))
            #expect(throws: ThemeError.self) { try store.renameTheme(id: theme.id, to: " ", at: at) }
            #expect(store.theme(id: theme.id)?.name == "金利と家計")
            return theme.id
        }
        let reopened = try ReaderStore(url: library.url, now: at)
        let theme = try #require(reopened.theme(id: id))
        #expect(theme.name == "金利と家計" && theme.note == "いまのノート")
        #expect(theme.createdAt == at && theme.updatedAt == at.addingTimeInterval(20))
    }

    @Test func unknownThemeIsANoOp() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let missing = UUID()
        #expect(throws: ThemeError.missingTheme) { try store.renameTheme(id: missing, to: "存在しない", at: at) }   // never a silent drop
        #expect(throws: (any Error).self) { try store.saveNote(themeID: missing, text: "書けない", at: at) }   // never a silent drop
        try store.deleteTheme(id: missing)
        #expect(store.themes.isEmpty)
    }

    @Test func addingSnapshotsSummaryAndRepeatKeepsTheRecord() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = "合成RSS要約"
        let theme = try store.createTheme(name: "A", at: at)
        let first = try store.addArticle(article.id, toTheme: theme.id, at: at)
        article.summary = "更新後の要約"
        let repeated = try store.addArticle(article.id, toTheme: theme.id, at: at.addingTimeInterval(30))
        #expect(first.key == repeated.key && store.themeArticles.count == 1)
        #expect(repeated.summary == "合成RSS要約" && repeated.addedAt == at)
        #expect(store.themeArticleIDs(themeID: theme.id) == [article.id])
        #expect(store.themeArticleCount(themeID: theme.id) == 1)
    }

    @Test func missingOrExpiredSummaryStoresAnEmptySummary() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = ""
        let theme = try store.createTheme(name: "A", at: at)
        let empty = try store.addArticle(article.id, toTheme: theme.id, at: at)
        #expect(empty.summary.isEmpty)
        let other = store.articles[1]
        let expired = try store.addArticle(other.id, toTheme: theme.id, at: at.addingTimeInterval(31 * day))
        #expect(expired.summary.isEmpty && store.article(id: other.id)?.title == other.title)
    }

    @Test func recordSurvivesExpiryUnsubscribeAndReopen() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = "合成RSS要約"
        article.originalURL = "https://synthetic.example/article"
        let (id, title, url) = (article.id, article.title, article.originalURL)
        let theme = try store.createTheme(name: "A", at: at)
        try store.addArticle(id, toTheme: theme.id, at: at)
        let later = at.addingTimeInterval(31 * day)
        try store.purgeExpired(at: later)
        for feed in store.feeds { try store.unsubscribe(feed) }
        #expect(store.article(id: id)?.summary.isEmpty == true)
        let reopened = try ReaderStore(url: library.url, now: later)
        let link = try #require(reopened.themeArticles.first)
        #expect(link.summary == "合成RSS要約" && link.articleID == id)
        #expect(link.title == title && link.url == url)
        #expect(reopened.article(id: id)?.title == title && reopened.article(id: id)?.originalURL == url)
    }

    @Test func starAndThemeAreIndependent() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let a = store.articles[0], b = store.articles[1]
        try store.setStar(articleID: a.id, isStarred: true, at: at)
        let theme = try store.createTheme(name: "A", at: at)
        try store.addArticle(a.id, toTheme: theme.id, at: at)
        try store.addArticle(b.id, toTheme: theme.id, at: at)
        #expect(a.starredAt == at && b.starredAt == nil)
        #expect(a.firstReadAt == nil && b.firstReadAt == nil && !a.isRead && !b.isRead)
        try store.setStar(articleID: a.id, isStarred: false, at: at)
        #expect(Set(store.themeArticleIDs(themeID: theme.id)) == [a.id, b.id])
        #expect(store.themeIDs(containing: a.id) == [theme.id])
    }

    @Test func oneArticleCanBelongToSeveralThemes() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]
        let first = try store.createTheme(name: "A", at: at)
        let second = try store.createTheme(name: "B", at: at.addingTimeInterval(1))
        try store.addArticle(article.id, toTheme: second.id, at: at)
        try store.addArticle(article.id, toTheme: first.id, at: at)
        #expect(store.themeIDs(containing: article.id) == [first.id, second.id])
        try store.removeArticle(article.id, fromTheme: first.id, at: at)
        #expect(store.themeIDs(containing: article.id) == [second.id])
        try store.removeArticle(article.id, fromTheme: first.id, at: at)
        #expect(store.themeArticleCount(themeID: first.id) == 0 && store.themeArticleCount(themeID: second.id) == 1)
    }

    @Test func unknownIDsThrowWithoutChangingData() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let theme = try store.createTheme(name: "A", at: at)
        #expect(throws: ThemeError.self) { try store.addArticle(UUID(), toTheme: theme.id, at: at) }
        #expect(throws: ThemeError.self) { try store.addArticle(store.articles[0].id, toTheme: UUID(), at: at) }
        #expect(store.themeArticles.isEmpty)
    }

    @Test func deletingAThemeRemovesOnlyItsOwnRecords() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]
        try store.setStar(articleID: article.id, isStarred: true, at: at)
        let first = try store.createTheme(name: "A", at: at)
        let second = try store.createTheme(name: "B", at: at.addingTimeInterval(1))
        for theme in [first, second] {
            try store.addArticle(article.id, toTheme: theme.id, at: at)
            try store.saveNote(themeID: theme.id, text: "ノート \(theme.name)", at: at)
        }
        try store.deleteTheme(id: first.id)
        #expect(store.themes.map(\.id) == [second.id])
        #expect(store.themeArticles.map(\.themeID) == [second.id])
        #expect(store.article(id: article.id)?.starredAt == at)
        let reopened = try ReaderStore(url: library.url, now: at)
        #expect(reopened.themes.map(\.id) == [second.id] && reopened.themes.first?.note == "ノート B")
    }

    @Test func aNoteIsStoredExactlyAsTypedAndKeptAfterReopen() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let text = "# 見出し\r\n  本文の行  \n\n- 箇条書き\n"
        let themeID = try {
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let theme = try store.createTheme(name: "Note", at: at)
            try store.saveNote(themeID: theme.id, text: text, at: at.addingTimeInterval(3))
            #expect(theme.note == text && theme.updatedAt == at.addingTimeInterval(3))
            let stamp = theme.updatedAt
            try store.saveNote(themeID: theme.id, text: text, at: at.addingTimeInterval(9))      // no change, no new stamp
            #expect(theme.updatedAt == stamp)
            return theme.id
        }()
        #expect(try ReaderStore(url: library.url, now: at).theme(id: themeID)?.note == text)
    }

    @Test func savingANoteForAMissingThemeIsAnErrorNotASilentDrop() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        #expect(throws: ThemeError.self) { try store.saveNote(themeID: UUID(), text: "書いたこと", at: at) }
        let theme = try store.createTheme(name: "Gone", at: at)
        try store.deleteTheme(id: theme.id)
        #expect(throws: ThemeError.self) { try store.saveNote(themeID: theme.id, text: "消えたテーマへ", at: at) }
    }

    @Test func aLongNoteSavesAndItsTimeIsRecorded() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let theme = try store.createTheme(name: "Long", at: at)
        let long = String(repeating: "長いノートの一行です。\n", count: 10_000)                 // about 100,000 characters
        let start = ContinuousClock.now
        try store.saveNote(themeID: theme.id, text: long, at: at)
        print("note-save 100k characters:", ContinuousClock.now - start)                       // recorded in the verification file, not a gate
        #expect(theme.note.count == long.count)
    }

    final class SaveGate { var failNext = false }

    private func gatedStore(_ library: TestLibrary, _ gate: SaveGate) throws -> ReaderStore {
        let schema = ReaderStore.schema
        let container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration("Reader", schema: schema, url: library.url, cloudKitDatabase: .none)])
        return try ReaderStore(container: container, seedDemo: true, now: at, saveHook: {
            if gate.failNext { gate.failNext = false; throw CocoaError(.fileWriteUnknown) }
        })
    }

    @Test func failedSaveLeavesNoPartialThemeStateAndCanBeRetried() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let gate = SaveGate()
        let store = try gatedStore(library, gate)
        let ids = store.articles.map(\.id)

        gate.failNext = true
        #expect(throws: (any Error).self) { try store.createTheme(name: "失敗", at: at) }
        #expect(store.themes.isEmpty)
        let theme = try store.createTheme(name: "成功", at: at)

        gate.failNext = true
        #expect(throws: (any Error).self) { try store.addArticle(ids[0], toTheme: theme.id, at: at) }
        #expect(store.themeArticles.isEmpty && store.themeArticleCount(themeID: theme.id) == 0)
        try store.addArticle(ids[0], toTheme: theme.id, at: at)
        try store.addArticle(ids[1], toTheme: theme.id, at: at)


        gate.failNext = true
        #expect(throws: (any Error).self) { try store.saveNote(themeID: theme.id, text: "失われるノート", at: at) }
        #expect(store.theme(id: theme.id)?.note == "")
        try store.saveNote(themeID: theme.id, text: "再試行のノート", at: at)
        #expect(store.theme(id: theme.id)?.note == "再試行のノート")
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.renameTheme(id: theme.id, to: "失われる名前", at: at) }
        #expect(store.theme(id: theme.id)?.name == "成功")
        let themeCount = store.themes.count, linkCount = store.themeArticles.count
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.createTheme(name: "失われる束", adding: [ids[0], ids[1]], at: at) }
        #expect(store.themes.count == themeCount && store.themeArticles.count == linkCount)
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.createTheme(name: "失われる", at: at) }
        #expect(store.themes.count == themeCount)
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.removeArticle(ids[1], fromTheme: theme.id, at: at) }
        #expect(store.themeArticleCount(themeID: theme.id) == 2)
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.deleteTheme(id: theme.id) }
        #expect(store.themes.count == 1 && store.themeArticles.count == 2)

        try store.saveNote(themeID: theme.id, text: "再試行したノート", at: at)
        let reopened = try ReaderStore(url: library.url, now: at)
        #expect(reopened.theme(id: theme.id)?.note == "再試行したノート" && reopened.themeArticles.count == 2)
    }

    @Test func createThemeFromAGroupAddsEveryArticleInOneSave() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let ids = Array(store.articles.prefix(3).map(\.id))
        for id in ids { try store.setStar(articleID: id, isStarred: true, at: at) }
        let theme = try store.createTheme(name: "  金利と家計  ", adding: [ids[0], ids[1], ids[1], ids[2]], at: at)
        #expect(theme.name == "金利と家計")
        #expect(store.themeArticleIDs(themeID: theme.id) == store.articleIDs.filter { ids.contains($0) })
        #expect(store.themeArticleCount(themeID: theme.id) == 3)
        let link = try #require(store.themeArticles.first { $0.articleID == ids[0] })
        #expect(link.title == store.article(id: ids[0])?.title)
    }

    @Test func createThemeFromAGroupRejectsBadInputAndChangesNothing() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let id = store.articles[0].id
        #expect(throws: ThemeError.self) { try store.createTheme(name: "  ", adding: [id], at: at) }
        #expect(throws: ThemeError.self) { try store.createTheme(name: "A", adding: [id, UUID()], at: at) }
        #expect(store.themes.isEmpty && store.themeArticles.isEmpty)
        let empty = try store.createTheme(name: "空", adding: [UUID](), at: at)
        #expect(store.themeArticleCount(themeID: empty.id) == 0)
    }

    @Test func everythingSurvivesAReopen() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let (themeID, articleID) = try autoreleasepool {
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let article = store.articles[0]; article.summary = "合成RSS要約"
            let theme = try store.createTheme(name: "A", at: at)
            try store.saveNote(themeID: theme.id, text: "いまのノート", at: at)
            try store.addArticle(article.id, toTheme: theme.id, at: at)
            return (theme.id, article.id)
        }
        let reopened = try ReaderStore(url: library.url, now: at)
        #expect(reopened.theme(id: themeID)?.note == "いまのノート")
        let link = try #require(reopened.themeArticles.first)
        #expect(link.articleID == articleID && link.summary == "合成RSS要約")
        #expect(reopened.themeArticleIDs(themeID: themeID) == [articleID])
    }

    final class RecoveryGate { var failSave = false, failReload = false }

    /// Once reloading works again, the very first theme change must recover the store and succeed.
    /// `save()` alone refuses while a reload is pending, so only a leading `reloadIfNeeded()` passes this.
    @Test func eachThemeChangeRecoversOnItsFirstCallAfterReloadSucceeds() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let gate = RecoveryGate()
        let schema = ReaderStore.schema
        let container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration("Reader", schema: schema, url: library.url, cloudKitDatabase: .none)])
        let store = try ReaderStore(container: container, seedDemo: true, now: at, saveHook: {
            if gate.failSave { throw CocoaError(.fileWriteUnknown) }
        }, reloadHook: {
            if gate.failReload { throw CocoaError(.fileReadUnknown) }
        })
        let ids = store.articles.map(\.id)
        let theme = try store.createTheme(name: "元の名前", at: at)
        let themeID = theme.id
        try store.addArticle(ids[0], toTheme: themeID, at: at)
        try store.addArticle(ids[1], toTheme: themeID, at: at)

        func induceFailedRecovery() {
            gate.failSave = true; gate.failReload = true
            #expect(throws: (any Error).self) { try store.createTheme(name: "誘発", at: at) }
            gate.failSave = false; gate.failReload = false
        }

        induceFailedRecovery()
        try store.renameTheme(id: themeID, to: "新しい名前", at: at)
        #expect(store.theme(id: themeID)?.name == "新しい名前")
        induceFailedRecovery()
        try store.saveNote(themeID: themeID, text: "回復後のノート", at: at)
        #expect(store.theme(id: themeID)?.note == "回復後のノート")
        induceFailedRecovery()
        try store.addArticle(ids[2], toTheme: themeID, at: at)
        #expect(store.themeArticleCount(themeID: themeID) == 3)
        induceFailedRecovery()
        try store.removeArticle(ids[0], fromTheme: themeID, at: at)
        #expect(store.themeArticleCount(themeID: themeID) == 2)
        induceFailedRecovery()
        try store.deleteTheme(id: themeID)
        #expect(store.theme(id: themeID) == nil && store.themeArticles.isEmpty)
        induceFailedRecovery()
        try store.createTheme(name: "回復後の新規", at: at)
        #expect(store.themes.map(\.name) == ["回復後の新規"])
        induceFailedRecovery()
        let grouped = try store.createTheme(name: "束", adding: [ids[3]], at: at)
        #expect(store.themeArticleCount(themeID: grouped.id) == 1)
    }

    @Test func recordKeepsTheTitleAndURLFromTheTimeOfAdding() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]
        article.title = "追加時のタイトル"; article.originalURL = "https://synthetic.example/a"
        let theme = try store.createTheme(name: "A", at: at)
        let link = try store.addArticle(article.id, toTheme: theme.id, at: at)
        #expect(link.title == "追加時のタイトル" && link.url == "https://synthetic.example/a")
        article.title = "再取得で変わったタイトル"; article.originalURL = "https://synthetic.example/b"
        try store.setStar(articleID: article.id, isStarred: true, at: at)
        let repeated = try store.addArticle(article.id, toTheme: theme.id, at: at.addingTimeInterval(5))
        #expect(repeated.title == "追加時のタイトル" && repeated.url == "https://synthetic.example/a")
        let reopened = try ReaderStore(url: library.url, now: at)
        let kept = try #require(reopened.themeArticles.first)
        #expect(kept.title == "追加時のタイトル" && kept.url == "https://synthetic.example/a")
    }

    @Test func anyChangeInsideAThemeBumpsItsUpdatedAt() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]
        let theme = try store.createTheme(name: "A", at: at)
        func updatedAt() -> Date? { store.theme(id: theme.id)?.updatedAt }
        func later(_ seconds: Double) -> Date { at.addingTimeInterval(seconds) }
        try store.addArticle(article.id, toTheme: theme.id, at: later(1)); #expect(updatedAt() == later(1))
        try store.saveNote(themeID: theme.id, text: "ノート", at: later(3)); #expect(updatedAt() == later(3))
        try store.saveNote(themeID: theme.id, text: "ノート", at: later(4)); #expect(updatedAt() == later(3))      // the same text is not a change
        try store.removeArticle(article.id, fromTheme: theme.id, at: later(6)); #expect(updatedAt() == later(6))
    }

    @Test func equalTimestampsKeepADeterministicOrder() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        try autoreleasepool {
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let ids = store.articles.map(\.id)
            for index in 0..<8 {
                let theme = try store.createTheme(name: "T\(index)", at: at)
                for id in ids.prefix(3) { try store.addArticle(id, toTheme: theme.id, at: at) }
            }
        }
        let reopened = try ReaderStore(url: library.url, now: at)
        let themeOrder = reopened.themes.map(\.id.uuidString)
        #expect(themeOrder == themeOrder.sorted())
        let linkOrder = reopened.themeArticles.map { "\($0.addedAt.timeIntervalSince1970)|\($0.key)" }
        #expect(linkOrder == linkOrder.sorted())
    }

    @Test func themeListKeepsTheSelectedArticleUntilItMoves() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let ids = store.articles.map(\.id)
        let theme = try store.createTheme(name: "A", at: at)
        try store.addArticle(ids[0], toTheme: theme.id, at: at)
        try store.addArticle(ids[2], toTheme: theme.id, at: at)
        #expect(store.themeArticleIDs(themeID: theme.id, keeping: nil) == [ids[0], ids[2]])
        try store.removeArticle(ids[0], fromTheme: theme.id, at: at)
        #expect(store.themeArticleIDs(themeID: theme.id, keeping: ids[0]) == [ids[0], ids[2]])
        #expect(store.themeArticleIDs(themeID: theme.id, keeping: nil) == [ids[2]])
        #expect(store.themeArticleIDs(themeID: theme.id) == [ids[2]])
    }

    @Test func isInAnyThemeFollowsMembership() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let id = store.articles[0].id
        #expect(!store.isInAnyTheme(articleID: id))
        let theme = try store.createTheme(name: "A", at: at)
        try store.addArticle(id, toTheme: theme.id, at: at)
        #expect(store.isInAnyTheme(articleID: id))
        try store.removeArticle(id, fromTheme: theme.id, at: at)
        #expect(!store.isInAnyTheme(articleID: id))
    }

    @Test func toggleAddsThenRemovesAndNamesTheTheme() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let id = store.articles[0].id
        let theme = try store.createTheme(name: "金利", at: at)
        #expect(try store.toggleTheme(theme.id, for: id, at: at) == .added(themeName: "金利"))
        #expect(store.isInAnyTheme(articleID: id))
        #expect(try store.toggleTheme(theme.id, for: id, at: at) == .removed(themeName: "金利"))
        #expect(!store.isInAnyTheme(articleID: id))
        #expect(throws: ThemeError.self) { try store.toggleTheme(UUID(), for: id, at: at) }
    }

    @Test func creatingWithAnArticleIsOneAtomicSave() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let gate = SaveGate()
        let store = try gatedStore(library, gate)
        let id = store.articles[0].id
        let expectedSummary = store.articles[0].summary.trimmingCharacters(in: .whitespacesAndNewlines)
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.createTheme(name: "失敗", adding: id, at: at) }
        #expect(store.themes.isEmpty && store.themeArticles.isEmpty)
        let theme = try store.createTheme(name: "  成功  ", adding: id, at: at)
        #expect(theme.name == "成功" && store.themeIDs(containing: id) == [theme.id])
        #expect(!expectedSummary.isEmpty && store.themeArticles.first?.summary == expectedSummary)
        #expect(throws: ThemeError.self) { try store.createTheme(name: " ", adding: id, at: at) }
        #expect(throws: ThemeError.self) { try store.createTheme(name: "存在しない", adding: UUID(), at: at) }
        #expect(store.themes.count == 1)
    }

    @Test func renamingFoldsTheNameToOneLineIsOneChangeAndRejectsBadInput() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let theme = try store.createTheme(name: "Old", at: at)
        try store.renameTheme(id: theme.id, to: " New\nname ", at: at.addingTimeInterval(5))
        #expect(theme.name == "New name" && theme.updatedAt == at.addingTimeInterval(5))
        try store.renameTheme(id: theme.id, to: "New name", at: at.addingTimeInterval(9))               // nothing changed
        #expect(theme.updatedAt == at.addingTimeInterval(5))
        #expect(throws: ThemeError.missingName) { try store.renameTheme(id: theme.id, to: " \n ", at: at) }
        #expect(throws: ThemeError.self) { try store.createTheme(name: "  ", at: at) }
        #expect(theme.name == "New name")                                                              // a rejected edit changes nothing
    }
}
