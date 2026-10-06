import AppKit
import ReaderCore

enum ReaderCommand: String {
    case next = "j", previous = "k", toggleStar = "s", scrap = "n", closeOriginal = "Escape"
}

@MainActor enum ReaderKeyboardCommands {
    static func command(for event: NSEvent) -> ReaderCommand? {
        guard event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty else { return nil }
        return event.keyCode == 53 ? .closeOriginal : ReaderCommand(rawValue: event.charactersIgnoringModifiers?.lowercased() ?? "")
    }
    static func acceptsDisplay(articleID: UUID, selectedID: UUID?, contentID: UUID?, originalVisible: Bool) -> Bool {
        !originalVisible && selectedID == articleID && contentID == articleID
    }
    static func listHasFocus(declared: Bool, responder: NSResponder?) -> Bool {
        declared || responder is NSTableView
    }
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
