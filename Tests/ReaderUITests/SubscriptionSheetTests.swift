import AppKit
import SwiftUI
import Testing
@testable import UnagiReader

// Checks PRD-14 (specification 7).
@Suite(EnglishLanguage()) @MainActor struct SubscriptionSheetTests {
    @Test func theXMLInputIsOnlyOfferedWithTheOptionKey() {
        #expect(!SubscriptionSheet.offersXMLInput(modifiers: []))
        #expect(!SubscriptionSheet.offersXMLInput(modifiers: [.command, .shift]))
        #expect(SubscriptionSheet.offersXMLInput(modifiers: [.option]))
    }
    @Test func theHeadingNamesTheFolderTheSubscriptionGoesTo() {
        #expect(SubscriptionSheet.heading(folder: "") == "Add Subscription")
        #expect(SubscriptionSheet.heading(folder: "Tech") == "Add Subscription to “Tech”")
    }
    @Test func aTargetIsIdentifiedByItsFolder() {
        #expect(SubscriptionTarget(folder: "Tech").id == "Tech" && SubscriptionTarget(folder: "").id == "")
    }
}

/// The count at the right end of a sidebar row becomes a + while the pointer is over a row that can take a new subscription.
@Suite(EnglishLanguage()) @MainActor struct SidebarRowTests {
    private func accentColumns(count: Int, add: Bool, hovering: Bool) throws -> [Int] {
        let host = NSHostingView(rootView: SidebarRow(title: "Tech", symbol: "folder", count: count, addHelp: add ? "このフォルダに購読を追加" : nil, onAdd: {}, forceHover: hovering)
            .frame(width: 215, height: 30).background(Color(white: 0.15)))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 215, height: 30), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host; window.appearance = NSAppearance(named: .darkAqua)
        defer { window.close() }
        host.layoutSubtreeIfNeeded(); pumpRunLoop(0.2)
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        var columns = Set<Int>()
        for x in 0..<rep.pixelsWide { for y in 0..<rep.pixelsHigh {
            guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
            if c.redComponent > 0.6 && c.redComponent - c.blueComponent > 0.25 { columns.insert(x * 215 / rep.pixelsWide) }
        } }
        return columns.sorted()
    }
    @Test func thePlusShowsOnlyWhileHoveringARowThatCanTakeASubscription() throws {
        #expect(try accentColumns(count: 13, add: true, hovering: false).isEmpty)
        #expect(try accentColumns(count: 13, add: false, hovering: true).isEmpty)               // rows without an add action never show it
        let shown = try accentColumns(count: 13, add: true, hovering: true)
        let first = try #require(shown.first)
        #expect(first > 215 * 3 / 4)                                                            // at the right end, where the count is (it takes the count's place)
    }
}

/// Dragging a subscription onto a folder row.
@Suite(EnglishLanguage()) @MainActor struct FeedDragTests {
    @Test func aDraggedSubscriptionIsJustItsIdentifierAndSurvivesEncoding() throws {
        let id = UUID()
        let data = try JSONEncoder().encode(FeedDrag(id: id))
        #expect(try JSONDecoder().decode(FeedDrag.self, from: data).id == id)
    }
    private func background(targeted: Bool, canDrop: Bool) throws -> NSColor {
        let host = NSHostingView(rootView: SidebarRow(title: "Tech", symbol: "folder", count: 3, onDropFeeds: canDrop ? { _ in true } : nil, forceTargeted: targeted)
            .frame(width: 215, height: 30).background(Color(white: 0.15)))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 215, height: 30), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host; window.appearance = NSAppearance(named: .darkAqua)
        defer { window.close() }
        host.layoutSubtreeIfNeeded(); pumpRunLoop(0.2)
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        return try #require(rep.colorAt(x: rep.pixelsWide * 6 / 10, y: rep.pixelsHigh / 2)?.usingColorSpace(.sRGB))        // an empty part of the row
    }
    @Test func aFolderRowShowsItIsTheTargetOnlyWhileADragIsOverIt() throws {
        let idle = try background(targeted: false, canDrop: true), over = try background(targeted: true, canDrop: true)
        let notATarget = try background(targeted: true, canDrop: false)
        #expect(over.brightnessComponent > idle.brightnessComponent + 0.04)                               // lighter while a drag is over it
        #expect(abs(notATarget.brightnessComponent - idle.brightnessComponent) < 0.01)                    // a row that takes no drop never lights up
    }
}
