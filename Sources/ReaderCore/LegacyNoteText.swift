import Foundation

/// The text that replaces a theme's understanding, questions, answers and evidence when the note arrives (decision 0014).
/// Pure value logic: the store uses it in one place, `migrateLegacyThemeContent`.
public enum LegacyNoteText {
    public struct Evidence: Sendable, Equatable {
        public var title: String
        public var url: String?
        public init(title: String, url: String?) { self.title = title; self.url = url }
    }
    public struct Question: Sendable, Equatable {
        public var text: String
        public var answer: String
        public var evidence: [Evidence]
        public init(text: String, answer: String, evidence: [Evidence]) { self.text = text; self.answer = answer; self.evidence = evidence }
    }

    /// The note after migration: the existing note first, then the understanding, then each question as a `#` heading with its answer
    /// and evidence list. Blocks are separated by one blank line and the text ends with one line break. Only blank lines at the ends of a block, and the spaces around a heading line, are trimmed.
    public static func compose(existingNote: String, understanding: String, questions: [Question]) -> String {
        var blocks: [String] = []
        for text in [existingNote, understanding] {
            let block = trimmingBlankLines(text)
            if !block.isEmpty { blocks.append(block) }
        }
        for question in questions {
            var lines = trimmingBlankLines(question.text).components(separatedBy: "\n")
            let heading = lines.removeFirst().trimmingCharacters(in: .whitespacesAndNewlines)
            blocks.append(heading.isEmpty ? "#" : "# " + heading)
            let rest = trimmingBlankLines(lines.joined(separator: "\n"))
            if !rest.isEmpty { blocks.append(rest) }
            let answer = trimmingBlankLines(question.answer)
            if !answer.isEmpty { blocks.append(answer) }
            if !question.evidence.isEmpty {
                blocks.append("根拠の記事:\n" + question.evidence.map(listLine).joined(separator: "\n"))
            }
        }
        return blocks.isEmpty ? "" : blocks.joined(separator: "\n\n") + "\n"
    }

    /// Every non-blank piece of the source text appears in `note`. The migration checks this before it removes anything.
    public static func containsEverything(_ note: String, understanding: String, questions: [Question]) -> Bool {
        var pieces = [trimmingBlankLines(understanding)]
        for question in questions {
            pieces += trimmingBlankLines(question.text).components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            pieces.append(trimmingBlankLines(question.answer))
            for item in question.evidence { pieces.append(oneLine(item.title)); if let url = item.url { pieces.append(url) } }
        }
        return pieces.allSatisfy { $0.isEmpty || contains(note, $0) }
    }

    /// Exact text search. `String.contains` compares by Character, so a CR at the end of a piece (which the note joins with the next
    /// line break into one CRLF) or a combining mark would not match. A literal search compares the characters themselves.
    static func contains(_ note: String, _ piece: String) -> Bool {
        note.range(of: piece, options: .literal) != nil
    }

    private static func listLine(_ item: Evidence) -> String {
        let title = oneLine(item.title)
        let name = title.isEmpty ? (item.url ?? "（無題）") : title
        guard let url = item.url, !title.isEmpty else { return "- " + name }
        return "- \(name) <\(url)>"
    }
    private static func oneLine(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }
    /// Removes blank lines at both ends only. Characters inside the text, and the line endings, are kept.
    private static func trimmingBlankLines(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        while let first = lines.first, first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { lines.removeFirst() }
        while let last = lines.last, last.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { lines.removeLast() }
        return lines.joined(separator: "\n")
    }
}
