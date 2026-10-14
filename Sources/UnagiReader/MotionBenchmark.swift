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
        for _ in 0..<repeats { act.next(); await pause(0.6) }
        for _ in 0..<repeats { act.previous(); await pause(0.6) }
        for _ in 0..<repeats { act.toggleNote(); await pause(0.8); act.toggleNote(); await pause(0.8) }
        act.toggleNote(); await pause(0.8)
        for _ in 0..<repeats { act.switchLayout(); await pause(0.8) }      // an even number: back to the note beside the article
        act.toggleNote(); await pause(0.8)                                 // the note closes, so the saved window state has the list
        for _ in 0..<repeats { act.openPage(); await pause(0.8); act.closePage(); await pause(0.8) }
        for _ in 0..<repeats { act.openFilter(); await pause(0.6); act.closeFilter(); await pause(0.6) }
        MotionMeter.shared.finish()
        ReaderPerformance.write()
        NSApp.terminate(nil)
    }
}
