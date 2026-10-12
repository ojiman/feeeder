import AppKit
import ReaderCore

enum ReaderCommand: String {
    case next = "j", previous = "k", toggleStar = "s", closeOriginal = "Escape"
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
    /// An editable text view (the note) or a text field takes the keys. The reader's text view is read-only and does not.
    static func isTextInput(_ responder: NSResponder?) -> Bool {
        if let view = responder as? NSTextView { return view.isEditable }
        return responder is NSTextField
    }
    static func hasMarkedText(_ responder: NSResponder?) -> Bool {
        (responder as? NSTextInputClient)?.hasMarkedText() == true
    }
    static func permits(sheet: Bool, originalPage: Bool) -> Bool {
        let responder = NSApp.keyWindow?.firstResponder
        return ReaderShortcutPolicy.permits(textInput: isTextInput(responder), markedText: hasMarkedText(responder),
            sheet: sheet || NSApp.keyWindow?.attachedSheet != nil, originalPage: originalPage)
    }
}

// Scroll memory is intentionally not observable: native scroll events must not redraw the entire reader.
@MainActor final class ReaderScrollMemory {
    var state = ReaderSelectionState()
}
