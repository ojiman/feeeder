import AppKit
import SwiftUI
import Testing
import ReaderCore
@testable import UnagiReader

@MainActor struct DeletedNoteUndoBarTests {
    private func brightPixels(offer: DeletedNoteOffer) throws -> Int {
        let host = NSHostingView(rootView: Color(white: 0.1).frame(width: 400, height: 160)
            .modifier(DeletedNoteUndoBar(offer: offer, onRestore: {})))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 160), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host; window.appearance = NSAppearance(named: .darkAqua)
        defer { window.close() }
        host.layoutSubtreeIfNeeded(); pumpRunLoop(0.2)
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        var count = 0
        for x in 0..<rep.pixelsWide / 2 { for y in rep.pixelsHigh / 2..<rep.pixelsHigh {                 // the bottom left
            if let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), c.brightnessComponent > 0.35 { count += 1 }
        } }
        return count
    }

    @Test func theBarShowsAtTheBottomLeftOnlyWhileADeletionCanBeTakenBack() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReaderStore(url: directory.appendingPathComponent("Reader.store"))
        let note = try store.createNote(text: "# 消すノート", at: .now)
        let offer = DeletedNoteOffer()
        let without = try brightPixels(offer: offer)
        offer.offer(try store.deleteNote(id: note.id))
        let with = try brightPixels(offer: offer)
        #expect(with > without + 200)                                                                      // the text and the button show
        offer.dismiss()
        #expect(try brightPixels(offer: offer) == without)
    }
}
