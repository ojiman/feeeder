import Foundation

/// The two switches of the Claude review screen: the person's goal and the person's note. Both are their own writing.
/// The toolbar entry offers the goal and leaves the note off (decision 0013). The note panel's button asks for a review of the
/// note, so it switches both on. A switch for something empty is off and disabled.
public enum HandoffDefaults {
    public struct Switches: Equatable, Sendable {
        public let goalOn: Bool, noteOn: Bool, goalEnabled: Bool, noteEnabled: Bool
    }
    public static func switches(goal: String, note: String, fromNotePanel: Bool) -> Switches {
        let hasGoal = !goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasNote = !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Switches(goalOn: hasGoal, noteOn: hasNote && fromNotePanel, goalEnabled: hasGoal, noteEnabled: hasNote)
    }
}
