import AppKit
import os
import ReaderCore

// Opt-in local diagnostics for synthetic acceptance runs. No article IDs, text or URLs are logged.
@MainActor enum ReaderPerformance {
    private static let signposter = OSSignposter(subsystem: AppIdentity.bundleIdentifier, category: "ReaderUI")
    private static var pending: (UUID, Double, OSSignpostIntervalState)?
    private static var samples: [Double] = []
    private static var gaps: [Double] = []
    private static var lastHeartbeat: Double?
    static var columnWidths: [String: [String: Double]] = [:]
    static var output: URL? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--performance-output"), args.indices.contains(index + 1) else { return nil }
        return URL(fileURLWithPath: args[index + 1])
    }
    static func selectionStarted(_ id: UUID) {
        if let old = pending { signposter.endInterval("Selection", old.2) }
        let event = NSApp.currentEvent
        let start = event?.type == .keyDown ? event!.timestamp : ProcessInfo.processInfo.systemUptime
        pending = (id, start, signposter.beginInterval("Selection"))
    }
    static func displayBegan(_ id: UUID) {
        signposter.emitEvent("DisplayBegin")
        guard let value = pending, value.0 == id else { return }
        signposter.endInterval("Selection", value.2); pending = nil
        guard output != nil else { return }
        samples.append(max(0, (ProcessInfo.processInfo.systemUptime - value.1) * 1000))
        write()
    }
    /// A motion starts (issue #212): `MotionMeter` records its frames when the output is on.
    static func motionBegan(_ name: String, duration: Double) { MotionMeter.shared.began(name, duration: duration) }
    static func heartbeat() {
        let now = ProcessInfo.processInfo.systemUptime
        if let prior = lastHeartbeat, now - prior > 0.12 { gaps.append((now - prior - 0.02) * 1000) }
        lastHeartbeat = now
    }
    static func write() {
        guard let output else { return }
        var values: [String: Any] = ["selectionMilliseconds": samples, "schedulingGapsOver100ms": gaps, "motions": MotionMeter.shared.records,
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "displayRefreshRate": CGDisplayCopyDisplayMode(CGMainDisplayID())?.refreshRate ?? 0]
        if !columnWidths.isEmpty { values["columnWidthsPoints"] = columnWidths }
        do {
            try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: values, options: .sortedKeys).write(to: output, options: .atomic)
        } catch { NSLog("Unagi Reader performance output failed") }
    }
}
