import Foundation

/// The text a note action works on, as UTF-16 ranges (what the text view uses).
public struct NoteTarget: Equatable, Sendable {
    public enum Kind: Sendable { case selection, section }
    public let kind: Kind
    /// The text to rewrite. For a section it does not include the heading line.
    public let range: NSRange
    public let text: String
    /// Where a new paragraph goes when the action adds text instead of replacing it: the end of the section, or, for a selection, the
    /// end of the line the selection ends in (so a paragraph is never split).
    public let insertionOffset: Int
}

public enum NoteSection {
    /// The selection if there is one; otherwise the section under the cursor: from the nearest line that starts with `#` at or above
    /// the cursor (the text before the first heading is a section too) to the line before the next such line. The heading line is
    /// kept out of the range, and so are blank lines at both ends and the last line break. nil when there is no text but white space.
    public static func target(in note: String, selection: NSRange) -> NoteTarget? {
        let ns = note as NSString
        let location = min(max(0, selection.location), ns.length)
        let length = min(max(0, selection.length), ns.length - location)
        if length > 0 {
            // White space at both ends of a selection (a triple click takes the line break) is not part of the text to work on.
            var start = location, end = location + length
            let space = CharacterSet.whitespacesAndNewlines
            while start < end, let scalar = Unicode.Scalar(ns.character(at: start)), space.contains(scalar) { start += 1 }
            while end > start, let scalar = Unicode.Scalar(ns.character(at: end - 1)), space.contains(scalar) { end -= 1 }
            guard end > start else { return nil }
            let range = NSRange(location: start, length: end - start)
            var lineStart = 0, lineEnd = 0, contentsEnd = 0
            ns.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: end - 1, length: 0))
            return NoteTarget(kind: .selection, range: range, text: ns.substring(with: range), insertionOffset: max(end, contentsEnd))
        }
        struct Line { let start: Int; let contentsEnd: Int; let end: Int; let isHeading: Bool; let isBlank: Bool }
        var lines: [Line] = []
        var position = 0
        while position < ns.length {
            var start = 0, end = 0, contentsEnd = 0
            ns.getLineStart(&start, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: position, length: 0))
            let content = ns.substring(with: NSRange(location: start, length: contentsEnd - start))
            lines.append(Line(start: start, contentsEnd: contentsEnd, end: end, isHeading: content.hasPrefix("#"),
                              isBlank: content.trimmingCharacters(in: .whitespaces).isEmpty))
            position = end
        }
        guard !lines.isEmpty else { return nil }
        let current = lines.firstIndex { location < $0.end } ?? lines.count - 1
        let heading = lines[...current].lastIndex { $0.isHeading }
        let next = lines.indices.first { $0 > current && lines[$0].isHeading } ?? lines.count
        let body = lines[((heading ?? -1) + 1)..<next]
        guard let first = body.first(where: { !$0.isBlank }), let last = body.last(where: { !$0.isBlank }) else { return nil }
        let range = NSRange(location: first.start, length: last.contentsEnd - first.start)
        return NoteTarget(kind: .section, range: range, text: ns.substring(with: range), insertionOffset: range.location + range.length)
    }
}
