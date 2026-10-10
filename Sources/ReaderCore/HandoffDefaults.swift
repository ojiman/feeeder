import Foundation

/// The switch of the Claude review screen: the person's note, their own writing. The toolbar entry leaves it off; the note panel's
/// button asks for a review of the note, so it switches it on. A switch for an empty note is off and disabled.
public enum HandoffDefaults {
    public struct Switches: Equatable, Sendable {
        public let noteOn: Bool, noteEnabled: Bool
    }
    public static func switches(note: String, fromNotePanel: Bool) -> Switches {
        let hasNote = !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Switches(noteOn: hasNote && fromNotePanel, noteEnabled: hasNote)
    }
}
