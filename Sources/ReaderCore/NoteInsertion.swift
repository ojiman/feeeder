import Foundation

/// How an adopted summary goes into the note. Pure text rules: the person's own text is never changed, only separated
/// from the new paragraph by blank lines.
public enum NoteInsertion {
    /// The summary, then a source line `出典: <title> <url>` (without a link when the article has none; no line at all when
    /// there is neither a title nor a link).
    public static func summaryBlock(summary: String, title: String, url: String?) -> String {
        let body = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = title.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        let link = url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let parts = [name, link].filter { !$0.isEmpty }
        guard !parts.isEmpty else { return body }
        let source = name.isEmpty ? "出典: \(link)" : (link.isEmpty ? "出典: \(name)" : "出典: \(name) <\(link)>")
        return body + "\n" + source
    }

    /// `offset` counts characters in `note` (the end of the selection, or the cursor) and is clamped. The block becomes its own
    /// paragraph: a blank line before it unless it starts the note, and a blank line after it when text follows. The note's own
    /// line-break style (CRLF or LF) is used for the lines that are added. Returns the new text and the cursor offset right after
    /// the block.
    public static func insert(_ block: String, into note: String, atCharacterOffset offset: Int) -> (note: String, cursorOffset: Int) {
        let eol = note.contains("\r\n") ? "\r\n" : "\n"
        let block = block.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\n", with: eol)
        let split = note.index(note.startIndex, offsetBy: min(max(0, offset), note.count))
        let before = String(note[..<split]), after = String(note[split...])
        let lead = before.isEmpty ? "" : String(repeating: eol, count: max(0, 2 - trailingBreaks(before)))
        let trail = after.isEmpty ? eol : String(repeating: eol, count: max(0, 2 - leadingBreaks(after)))
        let head = before + lead + block
        return (head + trail + after, head.count)
    }

    /// The whole adopt step as text: the block for this summary inserted after the end of the person's selection (or at the cursor;
    /// at the end of the note when there is no selection). `selectionEndUTF16` is what the text system reports.
    public static func adopted(summary: String, title: String, url: String?, into note: String, selectionEndUTF16: Int?) -> (note: String, cursorOffset: Int) {
        let offset = selectionEndUTF16.map { characterOffset(forUTF16Offset: $0, in: note) } ?? note.count
        return insert(summaryBlock(summary: summary, title: title, url: url), into: note, atCharacterOffset: offset)
    }

    /// A UTF-16 offset (what the text system reports) as a character offset, clamped to the note.
    public static func characterOffset(forUTF16Offset offset: Int, in note: String) -> Int {
        let clamped = min(max(0, offset), note.utf16.count)
        return note.distance(from: note.startIndex, to: String.Index(utf16Offset: clamped, in: note))
    }

    private static func trailingBreaks(_ text: String) -> Int { text.reversed().prefix { $0.isNewline }.count }
    private static func leadingBreaks(_ text: String) -> Int { text.prefix { $0.isNewline }.count }
}
