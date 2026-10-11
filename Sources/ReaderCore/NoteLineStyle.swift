import Foundation

/// Which lines of a note are headings or list items, for the editor's light styling (decision 0019, S5). It only reads the text:
/// it never changes it. Ranges are UTF-16 (what AppKit uses); a line ends at LF, CR, CR LF, U+0085, U+2028 or U+2029, and the range
/// of a line does not include its line break.
public enum NoteLineStyle {
    public enum Kind: Equatable, Sendable {
        /// `#` to `######` followed by a space, or alone on the line; at the first column.
        case heading(level: Int)
        /// `- `, `* `, `+ `, `1. ` or `1) ` after up to 8 spaces; each 2 spaces are one step of indent (at most 4).
        case listItem(indentSteps: Int, ordered: Bool)
    }
    public struct Run: Equatable, Sendable {
        public let line: NSRange
        public let kind: Kind
        /// The `#` marks of a heading, or the bullet or the number and its dot of a list item (without the space after it).
        public let marker: NSRange
    }

    /// `baseOffset` is added to every range, for a scan of a part of a longer text.
    public static func runs(in text: String, baseOffset: Int = 0) -> [Run] {
        let units = Array(text.utf16)
        var runs: [Run] = []
        var start = 0
        while start <= units.count {
            var end = start
            while end < units.count, !isBreak(units[end]) { end += 1 }
            if let (kind, marker) = classify(units, start, end) {
                runs.append(Run(line: NSRange(location: baseOffset + start, length: end - start), kind: kind,
                                marker: NSRange(location: baseOffset + marker.location, length: marker.length)))
            }
            guard end < units.count else { break }
            start = units[end] == 0x0D && end + 1 < units.count && units[end + 1] == 0x0A ? end + 2 : end + 1
        }
        return runs
    }

    private static func isBreak(_ unit: UInt16) -> Bool {
        unit == 0x0A || unit == 0x0D || unit == 0x85 || unit == 0x2028 || unit == 0x2029
    }

    private static func classify(_ units: [UInt16], _ start: Int, _ end: Int) -> (Kind, NSRange)? {
        guard start < end else { return nil }
        if units[start] == 0x23 {                                               // #
            var marks = 0
            while start + marks < end, units[start + marks] == 0x23, marks <= 6 { marks += 1 }
            guard marks <= 6, start + marks == end || units[start + marks] == 0x20 else { return nil }
            return (.heading(level: marks), NSRange(location: start, length: marks))
        }
        var indent = 0
        while start + indent < end, units[start + indent] == 0x20 { indent += 1 }
        guard indent <= 8, start + indent < end else { return nil }
        let position = start + indent
        let steps = min(4, indent / 2)
        let first = units[position]
        if first == 0x2D || first == 0x2A || first == 0x2B {                   // - * +
            guard position + 1 < end, units[position + 1] == 0x20 else { return nil }
            return (.listItem(indentSteps: steps, ordered: false), NSRange(location: position, length: 1))
        }
        var digits = 0
        while position + digits < end, units[position + digits] >= 0x30, units[position + digits] <= 0x39, digits <= 9 { digits += 1 }
        guard (1...9).contains(digits), position + digits + 1 < end,
              units[position + digits] == 0x2E || units[position + digits] == 0x29,        // . )
              units[position + digits + 1] == 0x20 else { return nil }
        return (.listItem(indentSteps: steps, ordered: true), NSRange(location: position, length: digits + 1))
    }
}
