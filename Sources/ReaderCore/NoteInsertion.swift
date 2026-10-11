import Foundation

/// How a summary is sent to the note. Pure text rules: the person's own text is never changed, only separated
/// from the new paragraph by blank lines.
public enum NoteInsertion {
    /// The summary, then a source line `出典: <title> <url>` (without a link when the article has none; no line at all when
    /// there is neither a title nor a link). AI output keeps its mark even without source metadata.
    public static func summaryBlock(summary: String, title: String, url: String?, aiMade: Bool = false) -> String {
        let body = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = title.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        let link = url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let parts = [name, link].filter { !$0.isEmpty }
        guard !parts.isEmpty else {
            return [body, aiMade ? "（AI要約）" : ""].filter { !$0.isEmpty }.joined(separator: "\n")
        }
        let source = name.isEmpty ? "出典: \(link)" : (link.isEmpty ? "出典: \(name)" : "出典: \(name) <\(link)>")
        return [body, source + (aiMade ? "（AI要約）" : "")].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    public static func newNoteText(title: String, block: String) -> String {
        let folded = title.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        let heading = folded.drop { $0 == "#" || $0.isWhitespace }
        return "# \(heading.isEmpty ? "無題の記事" : String(heading))\n\n" + block + "\n"
    }

    public static func appended(block: String, to note: String) -> String {
        let eol = note.contains("\r\n") ? "\r\n" : "\n"
        let normalized = block.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\n", with: eol)
        let lead = note.isEmpty ? "" : String(repeating: eol, count: max(0, 2 - trailingBreaks(note)))
        return note + lead + normalized + eol
    }

    private static func trailingBreaks(_ text: String) -> Int { text.reversed().prefix { $0.isNewline }.count }
}
