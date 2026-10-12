import Foundation
import SwiftData
import Testing
@testable import ReaderCore

/// A deleted note can be brought back for a little while (decision 0042).
@MainActor struct NoteUndoTests {
    private let then = Date(timeIntervalSince1970: 1_000), later = Date(timeIntervalSince1970: 2_000)

    private func noteWithTwoArticles(_ store: ReaderStore) throws -> Note {
        let note = try store.createNote(text: "# 金利\n自分の考え。", at: then)
        for article in store.articles.prefix(2) { try store.addArticle(article.id, toNote: note.id, at: then) }
        try store.saveNote(noteID: note.id, text: "# 金利\n自分の考え。\n続き。", at: later)
        return note
    }

    @Test func aDeletedNoteComesBackExactlyAsItWas() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true)
        let note = try noteWithTwoArticles(store)
        let id = note.id
        let articleIDs = Set(store.noteArticles.filter { $0.noteID == id }.map(\.articleID))
        #expect(articleIDs.count == 2)
        let deleted = try #require(try store.deleteNote(id: id))
        #expect(store.note(id: id) == nil && store.noteArticles.allSatisfy { $0.noteID != id })
        #expect(try store.restoreNote(deleted))
        let back = try #require(store.note(id: id))
        #expect(back.text == "# 金利\n自分の考え。\n続き。" && back.createdAt == then && back.updatedAt == later)       // the same note, not a copy
        #expect(Set(store.noteArticles.filter { $0.noteID == id }.map(\.articleID)) == articleIDs)                    // and the articles recorded in it
        #expect(try ReaderStore(url: library.url).note(id: id)?.text == "# 金利\n自分の考え。\n続き。")                  // saved, not only shown
    }
    @Test func restoringTwiceOrAfterANewNoteTookTheSpotChangesNothing() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        let note = try store.createNote(text: "# 一つ目", at: then)
        let deleted = try #require(try store.deleteNote(id: note.id))
        #expect(try store.restoreNote(deleted))
        #expect(try !store.restoreNote(deleted))                                                       // it exists already: no second copy
        #expect(store.notes.count == 1)
    }
    @Test func deletingANoteThatIsNotThereGivesNothingToRestore() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        #expect(try store.deleteNote(id: UUID()) == nil)
    }
    @Test func aFailedRestoreLeavesTheNoteDeletedAndCanBeTriedAgain() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let schema = ReaderStore.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration("Reader", schema: schema, url: library.url, cloudKitDatabase: .none)])
        final class Switch: @unchecked Sendable { nonisolated(unsafe) var failing = false }
        let failSwitch = Switch()
        let store = try ReaderStore(container: container, now: then, saveHook: { if failSwitch.failing { throw CocoaError(.fileWriteUnknown) } })
        let note = try store.createNote(text: "# 本文", at: then)
        let deleted = try #require(try store.deleteNote(id: note.id))
        failSwitch.failing = true
        #expect(throws: (any Error).self) { try store.restoreNote(deleted) }
        #expect(store.note(id: note.id) == nil)
        failSwitch.failing = false
        #expect(try store.restoreNote(deleted))
        #expect(store.note(id: note.id)?.text == "# 本文")
    }

    // MARK: The offer shown after a deletion

    @Test func theOfferHoldsOnlyTheLastDeletionAndRestoringOpensTheNote() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        let first = try store.createNote(text: "# 一つ目", at: then), second = try store.createNote(text: "# 二つ目", at: then)
        let offer = DeletedNoteOffer()
        offer.offer(try store.deleteNote(id: first.id))
        offer.offer(try store.deleteNote(id: second.id))                                              // a newer deletion replaces the older offer
        #expect(offer.deleted?.id == second.id)
        #expect(try offer.restore(in: store) == second.id)
        #expect(offer.deleted == nil)
        #expect(store.note(id: second.id) != nil && store.note(id: first.id) == nil)
    }
    @Test func dismissingOrNothingDeletedLeavesNothingToRestore() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        let offer = DeletedNoteOffer()
        offer.offer(nil)
        #expect(offer.deleted == nil)
        #expect(try offer.restore(in: store) == nil)
        let note = try store.createNote(text: "# 消す", at: then)
        offer.offer(try store.deleteNote(id: note.id))
        offer.dismiss()
        #expect(offer.deleted == nil)
        #expect(try offer.restore(in: store) == nil)
        #expect(store.note(id: note.id) == nil)
    }
    @Test func aRestoreThatFailsKeepsTheOfferSoThePersonCanTryAgain() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let schema = ReaderStore.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration("Reader", schema: schema, url: library.url, cloudKitDatabase: .none)])
        final class Switch: @unchecked Sendable { nonisolated(unsafe) var failing = false }
        let failSwitch = Switch()
        let store = try ReaderStore(container: container, now: then, saveHook: { if failSwitch.failing { throw CocoaError(.fileWriteUnknown) } })
        let note = try store.createNote(text: "# 本文", at: then)
        let offer = DeletedNoteOffer()
        offer.offer(try store.deleteNote(id: note.id))
        failSwitch.failing = true
        #expect(throws: (any Error).self) { try offer.restore(in: store) }
        #expect(offer.deleted != nil)
        failSwitch.failing = false
        #expect(try offer.restore(in: store) == note.id)
    }
}
