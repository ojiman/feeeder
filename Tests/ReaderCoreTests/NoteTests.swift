import Foundation
import SwiftData
import Testing
@testable import ReaderCore

@MainActor struct NoteTests {
    let at = Date(timeIntervalSince1970: 1_791_152_000)
    let day: TimeInterval = 86_400

    /// Decision 0019: the stored entities are `Note` and `NoteArticle`; the theme and question entities are gone.
    @Test func theSchemaHasOnlyTheNoteEntities() {
        let names = Set(ReaderStore.schema.entities.map(\.name))
        #expect(names.isSuperset(of: ["Note", "NoteArticle"]))
        #expect(names.isDisjoint(with: ["Theme", "ThemeArticle", "ThemeQuestion"]))
        #expect(Note(at: at).text == "" && Note(at: at).title == NoteTitle.untitled)
    }

    @Test func aNewNoteIsEmptyAndItsTitleFollowsItsFirstLine() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let empty = try store.createNote(at: at)
        #expect(empty.text.isEmpty && empty.title == NoteTitle.untitled)
        let titled = try store.createNote(text: "#   LLMの実用設計  \n本文", at: at.addingTimeInterval(1))
        #expect(titled.title == "LLMの実用設計" && titled.text == "#   LLMの実用設計  \n本文")   // the text is kept exactly as given
        #expect(Set(store.notes.map(\.id)) == [empty.id, titled.id] && store.note(id: titled.id)?.id == titled.id)
    }

    @Test func aNoteAndItsTitleSurviveAReopen() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let id = try autoreleasepool {
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let note = try store.createNote(text: "# 金利\n", at: at)
            try store.saveNote(noteID: note.id, text: "# 金利と家計\nいまのノート", at: at.addingTimeInterval(20))
            #expect(store.note(id: note.id)?.title == "金利と家計")
            return note.id
        }
        let reopened = try ReaderStore(url: library.url, now: at)
        let note = try #require(reopened.note(id: id))
        #expect(note.title == "金利と家計" && note.text == "# 金利と家計\nいまのノート")
        #expect(note.createdAt == at && note.updatedAt == at.addingTimeInterval(20))
    }

    @Test func theSidebarListsTheNoteEditedLastFirstAndEqualTimesKeepAFixedOrder() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let first = try store.createNote(text: "# 一\n", at: at)
        let second = try store.createNote(text: "# 二\n", at: at.addingTimeInterval(1))
        let third = try store.createNote(text: "# 三\n", at: at.addingTimeInterval(2))
        #expect(store.notesNewestEditFirst.map(\.id) == [third.id, second.id, first.id])
        try store.saveNote(noteID: first.id, text: "# 一\n編集した", at: at.addingTimeInterval(10))          // editing moves a note to the top
        #expect(store.notesNewestEditFirst.map(\.id) == [first.id, third.id, second.id])
        let tiedA = try store.createNote(at: at.addingTimeInterval(20)), tiedB = try store.createNote(at: at.addingTimeInterval(20))
        let order = store.notesNewestEditFirst.prefix(2).map { $0.id.uuidString }
        #expect(order == [tiedA.id.uuidString, tiedB.id.uuidString].sorted())
    }

    @Test func unknownNoteIsANoOp() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let missing = UUID()
        #expect(throws: NoteError.missingNote) { try store.saveNote(noteID: missing, text: "存在しない", at: at) }   // never a silent drop
        try store.deleteNote(id: missing)
        #expect(store.notes.isEmpty)
    }

    @Test func addingSnapshotsSummaryAndRepeatKeepsTheRecord() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = "合成RSS要約"
        let note = try store.createNote(text: "# A\n", at: at)
        let first = try store.addArticle(article.id, toNote: note.id, at: at)
        article.summary = "更新後の要約"
        let repeated = try store.addArticle(article.id, toNote: note.id, at: at.addingTimeInterval(30))
        #expect(first.key == repeated.key && store.noteArticles.count == 1)
        #expect(repeated.summary == "合成RSS要約" && repeated.addedAt == at)
        #expect(store.noteArticleIDs(noteID: note.id) == [article.id])
        #expect(store.noteArticleCount(noteID: note.id) == 1)
    }

    @Test func missingOrExpiredSummaryStoresAnEmptySummary() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = ""
        let note = try store.createNote(text: "# A\n", at: at)
        let empty = try store.addArticle(article.id, toNote: note.id, at: at)
        #expect(empty.summary.isEmpty)
        let other = store.articles[1]
        let expired = try store.addArticle(other.id, toNote: note.id, at: at.addingTimeInterval(31 * day))
        #expect(expired.summary.isEmpty && store.article(id: other.id)?.title == other.title)
    }

    @Test func recordSurvivesExpiryUnsubscribeAndReopen() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = "合成RSS要約"
        article.originalURL = "https://synthetic.example/article"
        let (id, title, url) = (article.id, article.title, article.originalURL)
        let note = try store.createNote(text: "# A\n", at: at)
        try store.addArticle(id, toNote: note.id, at: at)
        let later = at.addingTimeInterval(31 * day)
        try store.purgeExpired(at: later)
        for feed in store.feeds { try store.unsubscribe(feed) }
        #expect(store.article(id: id)?.summary.isEmpty == true)
        let reopened = try ReaderStore(url: library.url, now: later)
        let link = try #require(reopened.noteArticles.first)
        #expect(link.summary == "合成RSS要約" && link.articleID == id)
        #expect(link.title == title && link.url == url)
        #expect(reopened.article(id: id)?.title == title && reopened.article(id: id)?.originalURL == url)
    }

    @Test func starAndNoteAreIndependent() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let a = store.articles[0], b = store.articles[1]
        try store.setStar(articleID: a.id, isStarred: true, at: at)
        let note = try store.createNote(text: "# A\n", at: at)
        try store.addArticle(a.id, toNote: note.id, at: at)
        try store.addArticle(b.id, toNote: note.id, at: at)
        #expect(a.starredAt == at && b.starredAt == nil)
        #expect(a.firstReadAt == nil && b.firstReadAt == nil && !a.isRead && !b.isRead)
        try store.setStar(articleID: a.id, isStarred: false, at: at)
        #expect(Set(store.noteArticleIDs(noteID: note.id)) == [a.id, b.id])
        #expect(store.isInAnyNote(articleID: a.id))
    }

    @Test func oneArticleCanBelongToSeveralNotes() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]
        let first = try store.createNote(text: "# A\n", at: at)
        let second = try store.createNote(text: "# B\n", at: at.addingTimeInterval(1))
        try store.addArticle(article.id, toNote: second.id, at: at)
        try store.addArticle(article.id, toNote: first.id, at: at)
        #expect(store.noteArticles.filter { $0.articleID == article.id }.count == 2)
        try store.removeArticle(article.id, fromNote: first.id, at: at)
        #expect(store.noteArticles.filter { $0.articleID == article.id }.map(\.noteID) == [second.id])
        try store.removeArticle(article.id, fromNote: first.id, at: at)
        #expect(store.noteArticleCount(noteID: first.id) == 0 && store.noteArticleCount(noteID: second.id) == 1)
    }

    @Test func unknownIDsThrowWithoutChangingData() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let note = try store.createNote(text: "# A\n", at: at)
        #expect(throws: NoteError.self) { try store.addArticle(UUID(), toNote: note.id, at: at) }
        #expect(throws: NoteError.self) { try store.addArticle(store.articles[0].id, toNote: UUID(), at: at) }
        #expect(store.noteArticles.isEmpty)
    }

    @Test func deletingANoteRemovesOnlyItsOwnRecords() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]
        try store.setStar(articleID: article.id, isStarred: true, at: at)
        let first = try store.createNote(text: "# A\n", at: at)
        let second = try store.createNote(text: "# B\n", at: at.addingTimeInterval(1))
        for note in [first, second] {
            try store.addArticle(article.id, toNote: note.id, at: at)
            try store.saveNote(noteID: note.id, text: "ノート \(note.title)", at: at)
        }
        try store.deleteNote(id: first.id)
        #expect(store.notes.map(\.id) == [second.id])
        #expect(store.noteArticles.map(\.noteID) == [second.id])
        #expect(store.article(id: article.id)?.starredAt == at)
        let reopened = try ReaderStore(url: library.url, now: at)
        #expect(reopened.notes.map(\.id) == [second.id] && reopened.notes.first?.text == "ノート B")
    }

    @Test func aNoteIsStoredExactlyAsTypedAndKeptAfterReopen() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let text = "# 見出し\r\n  本文の行  \n\n- 箇条書き\n"
        let noteID = try {
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let note = try store.createNote(text: "# Note\n", at: at)
            try store.saveNote(noteID: note.id, text: text, at: at.addingTimeInterval(3))
            #expect(note.text == text && note.updatedAt == at.addingTimeInterval(3))
            let stamp = note.updatedAt
            try store.saveNote(noteID: note.id, text: text, at: at.addingTimeInterval(9))      // no change, no new stamp
            #expect(note.updatedAt == stamp)
            return note.id
        }()
        #expect(try ReaderStore(url: library.url, now: at).note(id: noteID)?.text == text)
    }

    @Test func savingANoteForAMissingNoteIsAnErrorNotASilentDrop() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        #expect(throws: NoteError.self) { try store.saveNote(noteID: UUID(), text: "書いたこと", at: at) }
        let note = try store.createNote(text: "# Gone\n", at: at)
        try store.deleteNote(id: note.id)
        #expect(throws: NoteError.self) { try store.saveNote(noteID: note.id, text: "消えたノートへ", at: at) }
    }

    @Test func aLongNoteSavesAndItsTimeIsRecorded() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let note = try store.createNote(text: "# Long\n", at: at)
        let long = String(repeating: "長いノートの一行です。\n", count: 10_000)                 // about 100,000 characters
        let start = ContinuousClock.now
        try store.saveNote(noteID: note.id, text: long, at: at)
        print("note-save 100k characters:", ContinuousClock.now - start)                       // recorded in the verification file, not a gate
        #expect(note.text.count == long.count)
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

    @Test func failedSaveLeavesNoPartialNoteStateAndCanBeRetried() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let gate = SaveGate()
        let store = try gatedStore(library, gate)
        let ids = store.articles.map(\.id)

        gate.failNext = true
        #expect(throws: (any Error).self) { try store.createNote(text: "# 失敗\n", at: at) }
        #expect(store.notes.isEmpty)
        let note = try store.createNote(text: "# 成功\n", at: at)

        gate.failNext = true
        #expect(throws: (any Error).self) { try store.addArticle(ids[0], toNote: note.id, at: at) }
        #expect(store.noteArticles.isEmpty && store.noteArticleCount(noteID: note.id) == 0)
        try store.addArticle(ids[0], toNote: note.id, at: at)
        try store.addArticle(ids[1], toNote: note.id, at: at)


        gate.failNext = true
        #expect(throws: (any Error).self) { try store.saveNote(noteID: note.id, text: "失われるノート", at: at) }
        #expect(store.note(id: note.id)?.text == "# 成功\n")                                          // the failed save changed nothing
        try store.saveNote(noteID: note.id, text: "再試行のノート", at: at)
        #expect(store.note(id: note.id)?.text == "再試行のノート")
        let noteCount = store.notes.count
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.createNote(text: "# 失われる\n", at: at) }
        #expect(store.notes.count == noteCount)
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.removeArticle(ids[1], fromNote: note.id, at: at) }
        #expect(store.noteArticleCount(noteID: note.id) == 2)
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.deleteNote(id: note.id) }
        #expect(store.notes.count == 1 && store.noteArticles.count == 2)

        try store.saveNote(noteID: note.id, text: "再試行したノート", at: at)
        let reopened = try ReaderStore(url: library.url, now: at)
        #expect(reopened.note(id: note.id)?.text == "再試行したノート" && reopened.noteArticles.count == 2)
    }

    @Test func everythingSurvivesAReopen() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let (noteID, articleID) = try autoreleasepool {
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let article = store.articles[0]; article.summary = "合成RSS要約"
            let note = try store.createNote(text: "# A\n", at: at)
            try store.saveNote(noteID: note.id, text: "いまのノート", at: at)
            try store.addArticle(article.id, toNote: note.id, at: at)
            return (note.id, article.id)
        }
        let reopened = try ReaderStore(url: library.url, now: at)
        #expect(reopened.note(id: noteID)?.text == "いまのノート")
        let link = try #require(reopened.noteArticles.first)
        #expect(link.articleID == articleID && link.summary == "合成RSS要約")
        #expect(reopened.noteArticleIDs(noteID: noteID) == [articleID])
    }

    final class RecoveryGate { var failSave = false, failReload = false }

    /// Once reloading works again, the very first note change must recover the store and succeed.
    /// `save()` alone refuses while a reload is pending, so only a leading `reloadIfNeeded()` passes this.
    @Test func eachNoteChangeRecoversOnItsFirstCallAfterReloadSucceeds() throws {
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
        let note = try store.createNote(text: "# 元の名前\n", at: at)
        let noteID = note.id
        try store.addArticle(ids[0], toNote: noteID, at: at)
        try store.addArticle(ids[1], toNote: noteID, at: at)

        func induceFailedRecovery() {
            gate.failSave = true; gate.failReload = true
            #expect(throws: (any Error).self) { try store.createNote(text: "# 誘発\n", at: at) }
            gate.failSave = false; gate.failReload = false
        }

        induceFailedRecovery()
        induceFailedRecovery()
        try store.saveNote(noteID: noteID, text: "回復後のノート", at: at)
        #expect(store.note(id: noteID)?.text == "回復後のノート")
        induceFailedRecovery()
        try store.addArticle(ids[2], toNote: noteID, at: at)
        #expect(store.noteArticleCount(noteID: noteID) == 3)
        induceFailedRecovery()
        try store.removeArticle(ids[0], fromNote: noteID, at: at)
        #expect(store.noteArticleCount(noteID: noteID) == 2)
        induceFailedRecovery()
        try store.deleteNote(id: noteID)
        #expect(store.note(id: noteID) == nil && store.noteArticles.isEmpty)
        induceFailedRecovery()
        try store.createNote(text: "# 回復後の新規\n", at: at)
        #expect(store.notes.map(\.title) == ["回復後の新規"])

    }

    @Test func recordKeepsTheTitleAndURLFromTheTimeOfAdding() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]
        article.title = "追加時のタイトル"; article.originalURL = "https://synthetic.example/a"
        let note = try store.createNote(text: "# A\n", at: at)
        let link = try store.addArticle(article.id, toNote: note.id, at: at)
        #expect(link.title == "追加時のタイトル" && link.url == "https://synthetic.example/a")
        article.title = "再取得で変わったタイトル"; article.originalURL = "https://synthetic.example/b"
        try store.setStar(articleID: article.id, isStarred: true, at: at)
        let repeated = try store.addArticle(article.id, toNote: note.id, at: at.addingTimeInterval(5))
        #expect(repeated.title == "追加時のタイトル" && repeated.url == "https://synthetic.example/a")
        let reopened = try ReaderStore(url: library.url, now: at)
        let kept = try #require(reopened.noteArticles.first)
        #expect(kept.title == "追加時のタイトル" && kept.url == "https://synthetic.example/a")
    }

    @Test func anyChangeInsideANoteBumpsItsUpdatedAt() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]
        let note = try store.createNote(text: "# A\n", at: at)
        func updatedAt() -> Date? { store.note(id: note.id)?.updatedAt }
        func later(_ seconds: Double) -> Date { at.addingTimeInterval(seconds) }
        try store.addArticle(article.id, toNote: note.id, at: later(1)); #expect(updatedAt() == later(1))
        try store.saveNote(noteID: note.id, text: "ノート", at: later(3)); #expect(updatedAt() == later(3))
        try store.saveNote(noteID: note.id, text: "ノート", at: later(4)); #expect(updatedAt() == later(3))      // the same text is not a change
        try store.removeArticle(article.id, fromNote: note.id, at: later(6)); #expect(updatedAt() == later(6))
    }

    @Test func equalTimestampsKeepADeterministicOrder() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        try autoreleasepool {
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let ids = store.articles.map(\.id)
            for index in 0..<8 {
                let note = try store.createNote(text: "# T\(index)\n", at: at)
                for id in ids.prefix(3) { try store.addArticle(id, toNote: note.id, at: at) }
            }
        }
        let reopened = try ReaderStore(url: library.url, now: at)
        let noteOrder = reopened.notes.map(\.id.uuidString)
        #expect(noteOrder == noteOrder.sorted())
        let linkOrder = reopened.noteArticles.map { "\($0.addedAt.timeIntervalSince1970)|\($0.key)" }
        #expect(linkOrder == linkOrder.sorted())
    }

    @Test func noteListKeepsTheSelectedArticleUntilItMoves() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let ids = store.articles.map(\.id)
        let note = try store.createNote(text: "# A\n", at: at)
        try store.addArticle(ids[0], toNote: note.id, at: at)
        try store.addArticle(ids[2], toNote: note.id, at: at)
        #expect(store.noteArticleIDs(noteID: note.id, keeping: nil) == [ids[0], ids[2]])
        try store.removeArticle(ids[0], fromNote: note.id, at: at)
        #expect(store.noteArticleIDs(noteID: note.id, keeping: ids[0]) == [ids[0], ids[2]])
        #expect(store.noteArticleIDs(noteID: note.id, keeping: nil) == [ids[2]])
        #expect(store.noteArticleIDs(noteID: note.id) == [ids[2]])
    }

    @Test func isInAnyNoteFollowsMembership() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let id = store.articles[0].id
        #expect(!store.isInAnyNote(articleID: id))
        let note = try store.createNote(text: "# A\n", at: at)
        try store.addArticle(id, toNote: note.id, at: at)
        #expect(store.isInAnyNote(articleID: id))
        try store.removeArticle(id, fromNote: note.id, at: at)
        #expect(!store.isInAnyNote(articleID: id))
    }

    @Test func sendAndUndoKeepTheTextAndLinkTogether() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = try #require(store.articles.first)
        let result = try store.sendArticle(article.id, to: nil, block: "summary", newNoteTitle: "Title", at: at)
        #expect(store.note(id: result.noteID)?.text == "# Title\n\nsummary\n")
        #expect(store.noteArticleCount(noteID: result.noteID) == 1)
        #expect(try store.undoSend(result, at: at))
        #expect(store.note(id: result.noteID) == nil && store.noteArticles.isEmpty)
        let note = try store.createNote(text: "mine", at: at)
        let first = try store.sendArticle(article.id, to: note.id, block: "one", newNoteTitle: "", at: at)
        let second = try store.sendArticle(article.id, to: note.id, block: "two", newNoteTitle: "", at: at)
        #expect(store.noteArticleCount(noteID: note.id) == 1)
        #expect(try store.undoSend(second, at: at))
        #expect(store.note(id: note.id)?.text == "mine\n\none\n" && store.noteArticleCount(noteID: note.id) == 1)
        try store.saveNote(noteID: note.id, text: "changed", at: at)
        #expect(try !store.undoSend(first, at: at))
        #expect(store.note(id: note.id)?.text == "changed")
        #expect(throws: NoteError.self) { try store.sendArticle(UUID(), to: note.id, block: "x", newNoteTitle: "", at: at) }
        #expect(throws: NoteError.self) { try store.sendArticle(article.id, to: UUID(), block: "x", newNoteTitle: "", at: at) }
    }
    @Test func aFailedSendOrUndoDoesNotPartiallySave() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let schema = ReaderStore.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration("Reader", schema: schema, url: library.url, cloudKitDatabase: .none)])
        var fail = false, reloadFail = false
        let store = try ReaderStore(container: container, seedDemo: true, now: at, saveHook: {
            if fail { throw CocoaError(.fileWriteUnknown) }
        }, reloadHook: { if reloadFail { throw CocoaError(.fileReadUnknown) } })
        let article = try #require(store.articles.first)
        let initialNotes = store.notes.count, initialLinks = store.noteArticles.count
        fail = true
        #expect(throws: (any Error).self) { try store.sendArticle(article.id, to: nil, block: "new", newNoteTitle: "T", at: at) }
        #expect(store.notes.count == initialNotes && store.noteArticles.count == initialLinks)
        fail = false
        let note = try store.createNote(text: "mine", at: at)
        fail = true
        #expect(throws: (any Error).self) { try store.sendArticle(article.id, to: note.id, block: "new", newNoteTitle: "", at: at) }
        #expect(store.note(id: note.id)?.text == "mine" && store.noteArticleCount(noteID: note.id) == 0)
        fail = false
        let result = try store.sendArticle(article.id, to: note.id, block: "new", newNoteTitle: "", at: at)
        fail = true
        #expect(throws: (any Error).self) { try store.undoSend(result, at: at) }
        #expect(store.note(id: note.id)?.text == "mine\n\nnew\n" && store.noteArticleCount(noteID: note.id) == 1)
        fail = false; reloadFail = true
        #expect(throws: (any Error).self) { try store.sendArticle(article.id, to: note.id, block: "again", newNoteTitle: "", at: at) }
        #expect(throws: (any Error).self) { try store.undoSend(result, at: at) }
        reloadFail = false
        try store.reloadIfNeeded()
        #expect(store.note(id: note.id)?.text == "mine\n\nnew\n\nagain\n")
    }
}

extension NoteTests {
    @Test func undoNeverDeletesAnotherSourceFromANewNote() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let result = try store.sendArticle(store.articles[0].id, to: nil, block: "summary", newNoteTitle: "T", at: at)
        try store.addArticle(store.articles[1].id, toNote: result.noteID, at: at.addingTimeInterval(1))
        #expect(try !store.undoSend(result, at: at))
        #expect(store.noteArticleCount(noteID: result.noteID) == 2 && store.note(id: result.noteID) != nil)
    }
}
