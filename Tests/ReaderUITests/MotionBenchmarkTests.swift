import AppKit
import Testing
@testable import UnagiReader

@MainActor struct MotionBenchmarkTests {
    @Test func recordsMeasuredWidthsIncludingAChangedNoteWidth() {
        let reader = NSSplitViewController()
        let inspector = NSSplitViewController()
        for _ in 0..<2 { inspector.addSplitViewItem(NSSplitViewItem(viewController: NSViewController())) }
        for _ in 0..<2 { reader.addSplitViewItem(NSSplitViewItem(viewController: NSViewController())) }
        reader.addSplitViewItem(NSSplitViewItem(viewController: inspector))
        let sidebar = reader.splitViewItems[0].viewController.view
        let list = reader.splitViewItems[1].viewController.view
        let article = inspector.splitViewItems[0].viewController.view
        let note = inspector.splitViewItems[1].viewController.view
        sidebar.setFrameSize(NSSize(width: 211, height: 600))
        list.setFrameSize(NSSize(width: 383, height: 600))
        article.setFrameSize(NSSize(width: 569, height: 600))
        note.setFrameSize(NSSize(width: 250, height: 600))

        #expect(MotionBenchmark.columnWidths(in: reader.view) == ["sidebar": 211, "list": 383, "article": 569, "note": 250])
        note.setFrameSize(NSSize(width: 640, height: 600))
        #expect(MotionBenchmark.columnWidths(in: reader.view)?["note"] == 640)

        for item in [reader.splitViewItems[0], reader.splitViewItems[1], inspector.splitViewItems[1]] {
            item.canCollapse = true
            item.isCollapsed = true
        }
        #expect(MotionBenchmark.columnWidths(in: reader.view) == ["sidebar": 0, "list": 0, "article": 569, "note": 0])
    }

    @Test func aMissingReaderDoesNotInventWidths() {
        #expect(MotionBenchmark.columnWidths(in: NSView()) == nil)
    }
}
