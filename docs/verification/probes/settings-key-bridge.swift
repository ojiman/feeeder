// Temporary synthetic integration only. Not a product settings implementation.
import AppKit
import SwiftUI
import WebKit

@MainActor enum SettingsKeyProbe {
    static let sizes: [Double] = [14, 16, 18, 20]
    static var defaults: UserDefaults {
        let args = ProcessInfo.processInfo.arguments
        let suite = args.firstIndex(of: "--probe-suite").map { args[$0 + 1] } ?? ProcessInfo.processInfo.environment["FEEEDER_SETTINGS_PROBE_SUITE"]
        guard let suite, let result = UserDefaults(suiteName: suite) else { fatalError("Synthetic defaults suite required") }
        return result
    }
    static func command(_ event: NSEvent) -> Int? {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard flags.contains(.command), !flags.contains(.control), !flags.contains(.option) else { return nil }
        let key = event.characters ?? event.charactersIgnoringModifiers ?? ""
        if key == "+" || key == "=" { return 1 }
        if !flags.contains(.shift), key == "-" { return -1 }
        if !flags.contains(.shift), key == "0" { return 0 }
        return nil
    }
    static func permitted(_ responder: NSResponder?) -> Bool {
        if (responder as? NSTextInputClient)?.hasMarkedText() == true { return false }
        if let text = responder as? NSTextView, text.isEditable { return false }
        if responder is NSTextField { return false }
        var view = responder as? NSView
        while let current = view {
            if current is WKWebView { return false }
            view = current.superview
        }
        return true
    }
    static func next(_ current: Double, command: Int) -> Double {
        if command == 0 { return 16 }
        let index = sizes.firstIndex(of: current) ?? 1
        return sizes[min(3, max(0, index + command))]
    }
    private static var counts = ["install": 0, "load": 0, "fetch": 0, "markDisplayed": 0]
    private static var observers: [NSObjectProtocol] = []
    private static var records: [[String: Any]] = []
    private static var pending: [String: Any]?
    private static var readState: (() -> Double?)?
    private static var output: URL? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--probe-key-output") else { return nil }
        return URL(fileURLWithPath: args[i + 1])
    }
    static func start() {
        for name in ["load", "fetch", "markDisplayed"] {
            observers.append(NotificationCenter.default.addObserver(forName: Notification.Name("SettingsProbe.\(name)"), object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { counts[name, default: 0] += 1 }
            })
        }
    }
    static func installed() { counts["install", default: 0] += 1 }
    private static func append(_ record: [String: Any]) {
        guard let output else { return }
        records.append(record)
        do { try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys]).write(to: output, options: .atomic) }
        catch { NSLog("Synthetic key probe logging failed: %@", error.localizedDescription) }
    }
    static func key(_ event: NSEvent, reason: String, size: Double) {
        append(["phase": reason, "eventTimestamp": event.timestamp, "repeat": event.isARepeat, "sheet": NSApp.keyWindow?.attachedSheet != nil, "responder": NSApp.keyWindow?.firstResponder.map { String(describing: type(of: $0)) } ?? "none", "key": event.characters ?? "", "ignoringModifiers": event.charactersIgnoringModifiers ?? "", "keyCode": event.keyCode, "modifiers": event.modifierFlags.rawValue, "size": size])
    }
    static func begin(_ event: NSEvent, size: Double, view: ArticleTextView?, read: @escaping () -> Double?) {
        if let previous = pending { append(["phase": "superseded", "size": previous["size"] ?? NSNull(), "eventTimestamp": previous["eventTime"] ?? NSNull()]) }
        pending = ["eventTime": event.timestamp, "size": size, "counts": counts, "firstReadBefore": read() as Any? ?? NSNull(), "oldTop": view.map { topLine($0).location } as Any? ?? NSNull(), "selection": view?.selectedRanges.map { NSStringFromRange($0.rangeValue) } as Any? ?? NSNull()]
        readState = read
        key(event, reason: "accepted", size: size)
    }
    static func updating() { pending?["updateTime"] = ProcessInfo.processInfo.systemUptime }
    static func updated() { pending?["updatedTime"] = ProcessInfo.processInfo.systemUptime }
    private static func topLine(_ view: ArticleTextView) -> NSRange {
        guard let lm = view.layoutManager, let tc = view.textContainer else { return NSRange(location: NSNotFound, length: 0) }
        lm.ensureLayout(for: tc)
        let glyph = lm.glyphIndex(for: NSPoint(x: 0, y: max(0, view.visibleRect.minY - view.textContainerOrigin.y)), in: tc)
        var range = NSRange()
        _ = lm.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &range)
        return lm.characterRange(forGlyphRange: range, actualGlyphRange: nil)
    }
    static func drawn(size: CGFloat, view: ArticleTextView) {
        guard let value = pending, let target = value["size"] as? Double, target == Double(size),
              let event = value["eventTime"] as? Double, let started = value["updateTime"] as? Double,
              let finished = value["updatedTime"] as? Double else { return }
        let ended = ProcessInfo.processInfo.systemUptime
        pending = nil
        let before = value["counts"] as? [String: Int] ?? [:]
        let oldTop = value["oldTop"] as? Int ?? NSNotFound
        append(["phase": "drawn", "size": target, "eventToDrawMS": (ended - event) * 1000,
                "eventToUpdateMS": (started - event) * 1000, "updateMS": (finished - started) * 1000,
                "updatedToDrawMS": (ended - finished) * 1000, "utf16": (view.string as NSString).length, "viewportWidth": view.frame.width, "viewportHeight": view.enclosingScrollView?.contentSize.height ?? 0,
                "selectionPreserved": (value["selection"] as? [String]) == view.selectedRanges.map { NSStringFromRange($0.rangeValue) },
                "countsDelta": counts.mapValues { $0 }.map { key, n in ["name": key, "delta": n - (before[key] ?? 0)] },
                "firstReadBefore": value["firstReadBefore"] ?? NSNull(), "firstReadAfter": readState?() as Any? ?? NSNull(),
                "topCharacterPreserved": NSLocationInRange(oldTop, topLine(view))])
    }
    static func native(_ root: NSView?) -> ArticleTextView? {
        guard let root else { return nil }
        if let text = root as? ArticleTextView { return text }
        return root.subviews.lazy.compactMap { native($0) }.first
    }
}

struct SettingsProbeKeys: NSViewRepresentable {
    var enabled: () -> Bool
    var firstRead: () -> Double?
    func makeNSView(context: Context) -> SettingsProbeKeyView { SettingsProbeKeyView() }
    func updateNSView(_ view: SettingsProbeKeyView, context: Context) { view.enabled = enabled; view.firstRead = firstRead }
    static func dismantleNSView(_ view: SettingsProbeKeyView, coordinator: ()) { view.stop() }
}
@MainActor final class SettingsProbeKeyView: NSView {
    var enabled: () -> Bool = { false }
    var firstRead: () -> Double? = { nil }
    private var monitor: Any?
    override func viewDidMoveToWindow() {
        stop()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = self.window, NSApp.keyWindow === window, let command = SettingsKeyProbe.command(event) else { return event }
            let current = SettingsKeyProbe.defaults.double(forKey: "readingSize") == 0 ? 16 : SettingsKeyProbe.defaults.double(forKey: "readingSize")
            guard window.attachedSheet == nil, self.enabled(), SettingsKeyProbe.permitted(window.firstResponder) else {
                SettingsKeyProbe.key(event, reason: "ignored", size: current); return event
            }
            let next = SettingsKeyProbe.next(current, command: command)
            guard next != current else { SettingsKeyProbe.key(event, reason: "no-op", size: current); return nil }
            SettingsKeyProbe.begin(event, size: next, view: SettingsKeyProbe.native(window.contentView), read: self.firstRead)
            SettingsKeyProbe.defaults.set(next, forKey: "readingSize")
            return nil
        }
    }
    func stop() { if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil } }
}
