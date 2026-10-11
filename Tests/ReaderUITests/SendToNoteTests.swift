import AppKit
import SwiftUI
import ReaderCore
import Testing
@testable import UnagiReader

@Suite(.serialized) @MainActor struct SendToNoteTests {
    private func buttons(_ view: NSView) -> [NSButton] {
        if let button = view as? NSButton { return [button] }
        return view.subviews.flatMap(buttons)
    }
    private func window<V: View>(_ view: V) -> (NSWindow, NSHostingView<V>) {
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 480), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        window.makeKeyAndOrderFront(nil); pumpRunLoop(0.2)
        return (window, host)
    }
    @Test func menuHasOnlyNewAndEightRecentNotesAndClickSends() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReaderStore(url: directory.appendingPathComponent("Reader.store"), seedDemo: true)
        for i in 0..<10 { _ = try store.createNote(text: "# Note \(i)", at: .now.addingTimeInterval(Double(i))) }
        var sent: UUID??
        let (w, host) = window(SendToNoteView(store: store, onSend: { sent = .some($0) }, onClose: {}))
        defer { w.close() }
        let rows = buttons(host)
        #expect(rows.count == 9)
        rows[0].performClick(nil)
        #expect(sent == .some(nil))
        rows[8].performClick(nil)
        #expect(sent == .some(store.notesNewestEditFirst[7].id))
        rows[1].performClick(nil)
        #expect(sent == .some(store.notesNewestEditFirst[0].id))
    }
    @Test func resultBarCanUndoTheActualSend() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReaderStore(url: directory.appendingPathComponent("Reader.store"), seedDemo: true)
        let sender = SummarySender(store: store, assistant: nil, isEnabled: { false })
        sender.start(articleID: store.articles[0].id, noteID: nil)
        for _ in 0..<100 { if !sender.isWorking { break }; try await Task.sleep(for: .milliseconds(5)) }
        guard case .done(let outcome) = sender.state else { Issue.record("send failed"); return }
        var opened: UUID?
        let (w, host) = window(SendStatusBar(sender: sender, onOpen: { opened = $0 }))
        defer { w.close() }
        let controls = buttons(host)
        try #require(controls.count == 3)
        controls[0].performClick(nil)
        #expect(opened == outcome.send.noteID)
        let undo = controls[1]
        undo.performClick(nil)
        #expect(store.note(id: outcome.send.noteID) == nil)
    }
    @Test func keysUseNAndNeverT() throws {
        let helper = OriginalKeyboardTests()
        #expect(ReaderKeyboardCommands.command(for: try helper.event("n")) == .sendToNote)
        #expect(ReaderKeyboardCommands.command(for: try helper.event("t")) == nil)
        #expect(!ReaderShortcutPolicy.permits(textInput: true, markedText: false, sheet: false, originalPage: false))
        #expect(!ReaderShortcutPolicy.permits(textInput: false, markedText: true, sheet: false, originalPage: false))
        #expect(!ReaderShortcutPolicy.permits(textInput: false, markedText: false, sheet: true, originalPage: false))
    }
    @Test func summarySettingsExposeTheControls() {
        let name = "summary-settings-ui-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(false, forKey: OnDeviceAISetting.key)
        defaults.set(true, forKey: SummarySettings.lengthKey)
        let (w, host) = window(SummarySettingsView(defaults: defaults))
        #expect(defaults.integer(forKey: SummarySettings.lengthKey) == 3)
        defer { w.close() }
        func fields(_ v: NSView) -> [NSTextField] { (v as? NSTextField).map { [$0] } ?? v.subviews.flatMap(fields) }
        #expect(fields(host).contains { $0.isEditable })
    }
}

extension SendToNoteTests {
    @Test func theRowMenuRemovesOnlyTheLink() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReaderStore(url: directory.appendingPathComponent("Reader.store"), seedDemo: true)
        let articleID = store.articles[0].id
        let note = try store.createNote(text: "my writing", at: .now)
        try store.addArticle(articleID, toNote: note.id, at: .now)
        let parent = NativeArticleList(ids: [articleID], article: { store.article(id: $0) }, feedTitle: { _ in "" }, selection: .constant(articleID),
            initialTop: nil, focus: false, shortcutsEnabled: true, onTop: { _ in }, onKey: { _ in },
            onRemoveFromNote: { id in try! store.removeArticle(id, fromNote: note.id, at: .now) })
        let coordinator = NativeArticleList.Coordinator(parent); coordinator.ids = [articleID]
        let item = try #require(coordinator.menu(for: 0)?.items.first)
        coordinator.removeFromNote(item)
        #expect(store.noteArticleCount(noteID: note.id) == 0)
        #expect(store.note(id: note.id)?.text == "my writing" && store.article(id: articleID) != nil)
        #expect(coordinator.menu(for: -1) == nil)
    }
    @Test func returnSendsNewAndEscapeClosesTheMenu() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReaderStore(url: directory.appendingPathComponent("Reader.store"))
        var sent = false, closed = false
        let (w, _) = window(SendToNoteView(store: store, onSend: { id in sent = id == nil }, onClose: { closed = true }))
        defer { w.close() }
        w.sendEvent(try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: w.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36)))
        pumpRunLoop(0.1)
        #expect(sent)
        w.sendEvent(try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: w.windowNumber, context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53)))
        pumpRunLoop(0.1)
        #expect(closed)
    }
}


extension SendToNoteTests {
    @Test func rowLabelsDoNotInterceptTheRowsContextMenu() {
        let cell = NativeArticleList.Cell(frame: NSRect(x: 0, y: 0, width: 320, height: 96))
        cell.layoutSubtreeIfNeeded()
        #expect(cell.hitTest(NSPoint(x: 30, y: 50)) === cell)
    }
}
