import AppKit
import ReaderCore

@MainActor enum ReaderKeyboardCommands {
    static func permits(sheet: Bool, originalPage: Bool) -> Bool {
        let responder = NSApp.keyWindow?.firstResponder
        let input = responder as? NSTextInputClient
        return ReaderShortcutPolicy.permits(textInput: responder is NSTextView || responder is NSTextField,
            markedText: input?.hasMarkedText() == true, sheet: sheet || NSApp.keyWindow?.attachedSheet != nil, originalPage: originalPage)
    }
}

// Scroll memory is intentionally not observable: native scroll events must not redraw the entire reader.
@MainActor final class ReaderScrollMemory {
    var state = ReaderSelectionState()
}
