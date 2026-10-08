import AppKit
import Testing
@testable import RSSReader

@MainActor struct SidebarTitlebarTests {
    @Test func controlsFollowSidebarWidthAndDetachWithSidebar() throws {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 600), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        window.toolbar = NSToolbar(identifier: "synthetic-sidebar")
        let anchor = SidebarTitlebarControls.Anchor()
        anchor.frame = NSRect(x: 0, y: 0, width: 215, height: 600)
        window.contentView?.addSubview(anchor)
        anchor.layoutSubtreeIfNeeded()
        let accessory = try #require(window.titlebarAccessoryViewControllers.first)
        #expect(accessory.layoutAttribute == .left)
        #expect(abs(accessory.view.convert(accessory.view.bounds, to: nil).maxX - 215) < 1)
        anchor.setFrameSize(NSSize(width: 280, height: 600))
        anchor.layoutSubtreeIfNeeded()
        #expect(abs(accessory.view.convert(accessory.view.bounds, to: nil).maxX - 280) < 1)
        anchor.sidebarVisible = false
        #expect(window.titlebarAccessoryViewControllers.isEmpty)
        anchor.sidebarVisible = true
        anchor.layoutSubtreeIfNeeded()
        #expect(window.titlebarAccessoryViewControllers.count == 1)
        #expect(abs(accessory.view.convert(accessory.view.bounds, to: nil).maxX - 280) < 1)
        anchor.removeFromSuperview()
        #expect(window.titlebarAccessoryViewControllers.isEmpty)
    }
}
