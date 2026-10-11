import Foundation

/// The title of a note: its first line that is not empty, without the leading `#` marks and the spaces after them. A note has no
/// separate name (decision 0019). An empty note, or one whose lines are only marks and spaces, is 「新規ノート」.
public enum NoteTitle {
    public static let untitled = "新規ノート"

    /// Scans line by line and stops at the first line with a title, so a long note costs only its first lines (every sidebar row
    /// asks for its title after every keystroke).
    public static func make(from text: String) -> String {
        var start = text.startIndex
        while start < text.endIndex {
            let range = text.lineRange(for: start..<start)
            let title = String(text[range].drop(while: { $0 == "#" || $0.isWhitespace })).trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty { return title }
            start = range.upperBound
        }
        return untitled
    }

    /// The text of a note after renaming it: only the title line changes (its `#` marks and its line ending stay), so the person's own
    /// writing is not touched. A note without a title line gets the name as a heading in front. Nil when the name is empty.
    public static func renamed(_ text: String, to name: String) -> String? {
        let name = SingleLineText.name(name)
        guard !name.isEmpty else { return nil }
        var start = text.startIndex
        while start < text.endIndex {
            let range = text.lineRange(for: start..<start)
            var core = Substring(text[range]), terminator = ""
            while let last = core.last, last.isNewline { terminator = String(last) + terminator; core.removeLast() }
            var prefix = String(core.prefix(while: { $0 == "#" || $0.isWhitespace }))
            let title = core.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                if prefix.contains("#"), !prefix.hasSuffix(" ") { prefix += " " }
                return String(text[..<range.lowerBound]) + prefix + name + terminator + String(text[range.upperBound...])
            }
            start = range.upperBound
        }
        return text.isEmpty ? "# " + name : "# " + name + "\n" + text
    }
}
