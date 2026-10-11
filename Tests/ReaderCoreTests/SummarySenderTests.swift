import Foundation
import Testing
@testable import ReaderCore

@MainActor struct SummarySenderTests {
    let at = Date(timeIntervalSince1970: 1_800_000_000)
    private func settle(_ sender: SummarySender) async throws {
        for _ in 0..<300 { if sender.state != .working { return }; try await Task.sleep(for: .milliseconds(10)) }
        Issue.record("send did not finish")
    }
    private func parked(_ generator: FakeGenerator) async throws {
        for _ in 0..<300 { if await generator.generationParked { return }; try await Task.sleep(for: .milliseconds(5)) }
        Issue.record("generator did not start")
    }
    @Test func sendMarksAIAndUndoWorksOnce() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let generator = FakeGenerator(); await generator.scriptGeneration(["要約"])
        let sender = SummarySender(store: store, assistant: generator, now: { at })
        let article = store.articles[0].id
        #expect(sender.start(articleID: article, noteID: nil))
        #expect(!sender.start(articleID: store.articles[1].id, noteID: nil))
        try await settle(sender)
        guard case .done(let outcome) = sender.state else { Issue.record("expected done: \(sender.state)"); return }
        #expect(outcome.aiMade && !outcome.noteTitle.isEmpty)
        #expect(store.note(id: outcome.send.noteID)?.text.contains("（AI要約）") == true)
        #expect(store.noteArticleCount(noteID: outcome.send.noteID) == 1)
        sender.undo()
        #expect(store.note(id: outcome.send.noteID) == nil)
        sender.undo()
        #expect(store.note(id: outcome.send.noteID) == nil)
    }
    @Test func cancelAndTurningAIOffDropLateAnswers() async throws {
        for cancel in [true, false] {
            let library = try TestLibrary(); defer { library.cleanup() }
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let generator = FakeGenerator(); await generator.scriptGeneration(["late"], hold: true)
            let enabled = EnabledSwitch()
            let sender = SummarySender(store: store, assistant: generator, isEnabled: { enabled.on }, now: { at })
            let count = store.notes.count
            #expect(sender.start(articleID: store.articles[0].id, noteID: nil))
            try await parked(generator)
            if cancel { sender.cancel() } else { enabled.on = false }
            await generator.releaseGeneration()
            try await settle(sender)
            #expect(store.notes.count == count && sender.state != .working)
        }
    }
    @Test func unavailableFailedBlankAndTimedOutAIUseAnUnmarkedFallback() async throws {
        for mode in 0..<5 {
            let library = try TestLibrary(); defer { library.cleanup() }
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let generator = FakeGenerator()
            await generator.scriptGeneration(mode == 2 ? [" \n"] : ["late"], failure: mode == 3 ? CocoaError(.coderInvalidValue) : nil,
                hold: mode == 4, availability: mode == 0 ? .unsupported : mode == 1 ? .assetsMissing : .available)
            let sender = SummarySender(store: store, assistant: generator, deadline: 0.03, now: { at })
            #expect(sender.start(articleID: store.articles[0].id, noteID: nil))
            try await settle(sender)
            if mode == 4 { await generator.releaseGeneration() }
            guard case .done(let outcome) = sender.state else { Issue.record("expected fallback: \(sender.state)"); continue }
            #expect(!outcome.aiMade && outcome.message.contains("AI"))
            #expect(store.note(id: outcome.send.noteID)?.text.contains("（AI要約）") == false)
        }
    }
    @Test func disabledOrExpiredTextNeverCallsTheModel() async throws {
        for expired in [false, true] {
            let library = try TestLibrary(); defer { library.cleanup() }
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let generator = FakeGenerator()
            let time = expired ? at.addingTimeInterval(400 * 86400) : at
            let sender = SummarySender(store: store, assistant: generator, isEnabled: { expired }, now: { time })
            #expect(sender.start(articleID: store.articles[0].id, noteID: nil))
            try await settle(sender)
            #expect(await generator.generateCalls.isEmpty)
            #expect(await generator.generationAvailabilityCalls == 0)
            guard case .done(let outcome) = sender.state else { Issue.record("expected fallback"); continue }
            #expect(!outcome.aiMade)
            if expired { #expect(outcome.message.contains("タイトルとURL")) }
        }
    }
    @Test func deletedTargetAndSaveFailureAreNeverSuccess() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let note = try store.createNote(text: "my note", at: at)
        let generator = FakeGenerator(); await generator.scriptGeneration(["AI"], hold: true)
        let sender = SummarySender(store: store, assistant: generator, now: { at })
        #expect(sender.start(articleID: store.articles[0].id, noteID: note.id))
        try await parked(generator)
        try store.deleteNote(id: note.id)
        await generator.releaseGeneration(); try await settle(sender)
        guard case .failed(let message) = sender.state else { Issue.record("expected failed"); return }
        #expect(message.contains("ノートが見つかりません"))
        #expect(store.note(id: note.id) == nil)
    }
    @Test func undoRefusesAnEditedNoteAndExpiresAfterEightSeconds() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let note = try store.createNote(text: "mine", at: at)
        var time = at
        let sender = SummarySender(store: store, assistant: nil, isEnabled: { false }, now: { time })
        #expect(sender.start(articleID: store.articles[0].id, noteID: note.id))
        try await settle(sender)
        try store.saveNote(noteID: note.id, text: "edited", at: at)
        sender.undo()
        #expect(store.note(id: note.id)?.text == "edited")
        #expect(sender.start(articleID: store.articles[0].id, noteID: note.id))
        try await settle(sender)
        let text = store.note(id: note.id)?.text
        time = at.addingTimeInterval(9)
        sender.undo()
        #expect(store.note(id: note.id)?.text == text)
    }
}
