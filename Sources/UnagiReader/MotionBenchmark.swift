import AppKit

/// `--motion-benchmark` with `--performance-output <file>` (issue #212): plays each motion a fixed number of times through the same
/// functions the keys call, writes the file and quits. For synthetic libraries only; it changes the window's state as a person would.
@MainActor enum MotionBenchmark {
    static var requested: Bool { ProcessInfo.processInfo.arguments.contains("--motion-benchmark") && ReaderPerformance.output != nil }
    static let repeats = 10

    struct Actions {
        let selectFirst: () -> Void
        let next: () -> Void
        let previous: () -> Void
        let toggleNote: () -> Void
        let switchLayout: () -> Void
        let openPage: () -> Void
        let closePage: () -> Void
        let openFilter: () -> Void
        let closeFilter: () -> Void
    }

    static func run(_ act: Actions) async {
        func pause(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }
        await pause(3)                                                     // the window settles and the library is read
        act.selectFirst(); await pause(1)
        recordWidths("reading")
        for _ in 0..<repeats { act.next(); await pause(0.6) }
        for _ in 0..<repeats { act.previous(); await pause(0.6) }
        for _ in 0..<repeats { act.toggleNote(); await pause(0.8); act.toggleNote(); await pause(0.8) }
        act.toggleNote(); await pause(0.8)
        recordWidths("noteOpen")
        for index in 0..<repeats {                                       // an even number: back to the note beside the article
            act.switchLayout(); await pause(0.8)
            if index == 0 { recordWidths("noteWithList") }
        }
        act.toggleNote(); await pause(0.8)                                 // the note closes, so the saved window state has the list
        for _ in 0..<repeats { act.openPage(); await pause(0.8); act.closePage(); await pause(0.8) }
        for _ in 0..<repeats { act.openFilter(); await pause(0.6); act.closeFilter(); await pause(0.6) }
        MotionMeter.shared.finish()
        ReaderPerformance.write()
        NSApp.terminate(nil)
    }

    private static func recordWidths(_ layout: String) {
        guard let view = (NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible })?.contentView,
              let widths = columnWidths(in: view) else {
            NSLog("Unagi Reader motion benchmark could not read column widths for %@", layout)
            return
        }
        ReaderPerformance.columnWidths[layout] = widths
    }

    /// Read settled AppKit panes, not ideal or saved widths. Collapsed panes can keep their old bounds.
    static func columnWidths(in view: NSView) -> [String: Double]? {
        func split(in view: NSView, count: Int) -> NSSplitViewController? {
            if let split = view as? NSSplitView, let controller = split.delegate as? NSSplitViewController,
               controller.splitViewItems.count == count { return controller }
            return view.subviews.lazy.compactMap { split(in: $0, count: count) }.first
        }
        func listContent(in view: NSView) -> ListColumnCollapse.Probe? {
            if let probe = view as? ListColumnCollapse.Probe { return probe }
            return view.subviews.lazy.compactMap { listContent(in: $0) }.first
        }
        func width(_ item: NSSplitViewItem) -> Double { item.isCollapsed ? 0 : item.viewController.view.bounds.width }
        guard let reader = split(in: view, count: 3) else { return nil }
        let panes = reader.splitViewItems
        guard let list = listContent(in: panes[1].viewController.view) else { return nil }
        let inspector = split(in: panes[2].viewController.view, count: 2)?.splitViewItems
        // The outer list view can reach under the sidebar; the existing probe fills just the list.
        return ["sidebar": width(panes[0]), "list": panes[1].isCollapsed ? 0 : list.bounds.width,
                "article": inspector.map { width($0[0]) } ?? width(panes[2]),
                "note": inspector.map { width($0[1]) } ?? 0]
    }
}
