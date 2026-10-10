import Foundation

/// The title of a note: its first line that is not empty, without the leading `#` marks and the spaces after them. A note has no
/// separate name (decision 0019). An empty note, or one whose lines are only marks and spaces, is 「新規ノート」.
public enum NoteTitle {
    public static let untitled = "新規ノート"

    public static func make(from text: String) -> String {
        for line in text.components(separatedBy: .newlines) {
            let title = String(line.drop(while: { $0 == "#" || $0.isWhitespace }))
                .trimmingCharacters(in: .whitespaces)
            if !title.isEmpty { return title }
        }
        return untitled
    }
}
