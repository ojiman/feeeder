import AppKit
import QuartzCore

/// Opt-in measurement of the motions (issue #212): while a named motion runs, every display frame is recorded with the window's display
/// link. The link's callbacks run on the main thread, so a frame the main thread was too busy to serve shows as a long interval; frames
/// lost inside the system's render server are not seen. Off unless `--performance-output` is given. No article data is recorded.
@MainActor final class MotionMeter: NSObject {
    static let shared = MotionMeter()

    private struct Running {
        let name: String
        let start: CFTimeInterval
        let end: CFTimeInterval
        /// The input event's time, on the same clock as the frames (the system's uptime), when a key or click started the motion.
        let input: TimeInterval?
        var stamps: [CFTimeInterval] = []
    }
    private var running: Running?
    private var link: CADisplayLink?
    private(set) var records: [[String: Any]] = []

    /// A motion of about `duration` seconds starts now. A motion still being measured is closed first.
    func began(_ name: String, duration: Double) {
        guard ReaderPerformance.output != nil,
              let view = (NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible })?.contentView else { return }
        finish()
        let now = CACurrentMediaTime()
        let event = NSApp.currentEvent
        let input = event.map { [.keyDown, .leftMouseDown, .leftMouseUp].contains($0.type) } == true ? event?.timestamp : nil
        running = Running(name: name, start: now, end: now + duration + 0.15, input: input)
        let link = view.displayLink(target: self, selector: #selector(frame(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func frame(_ link: CADisplayLink) {
        guard running != nil else { return }
        running?.stamps.append(link.timestamp)
        if link.timestamp >= running!.end { finish() }
    }

    func finish() {
        link?.invalidate(); link = nil
        guard let done = running else { return }
        running = nil
        let refresh = Double(NSScreen.main?.maximumFramesPerSecond ?? 60)
        let expected = 1000 / max(refresh, 1)
        let intervals = zip(done.stamps.dropFirst(), done.stamps).map { ($0 - $1) * 1000 }
        var record: [String: Any] = [
            "name": done.name,
            "frames": done.stamps.count,
            "expectedFrameMilliseconds": expected,
            "longestFrameMilliseconds": intervals.max() ?? 0,
            "hitches": intervals.filter { $0 > expected * 1.5 }.count,
            "startToFirstFrameMilliseconds": done.stamps.first.map { ($0 - done.start) * 1000 } ?? -1,
        ]
        if let input = done.input, let first = done.stamps.first { record["inputToFirstFrameMilliseconds"] = (first - input) * 1000 }
        records.append(record)
        ReaderPerformance.write()
    }
}
