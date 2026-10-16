import Foundation

/// The text that 「記事をノートに送る」 puts into the note (specification 3.3, decision 0059): the article's source as one Markdown
/// link, or the selected text as a quotation followed by that link. Only the text: the line breaks around it depend on where it goes in
/// the note, and the caller decides that.
public enum NoteClip {
    /// The text to insert, or nil when the article has neither a title nor a URL (the command then does nothing). A selection that is
    /// empty or only spaces counts as no selection. A shown translation is the caller's business: it passes no selection then.
    public static func text(title: String?, url: String?, selection: String?) -> String? {
        guard let source = sourceLine(title: title, url: url) else { return nil }
        let lines = selectionLines(selection)
        guard !lines.isEmpty else { return source }
        return (lines.map { $0.isEmpty ? ">" : "> " + $0 } + ["> — " + source]).joined(separator: "\n")
    }

    /// The text with the line breaks that make it a paragraph of its own at `point` (UTF-16) of `note` (specification 3.3): an empty
    /// line before it and after it when there is text there, none at the start of the note, never two empty lines. `offset` is where the
    /// text itself starts in `piece`.
    public static func paragraph(_ text: String, in note: String, at point: Int) -> (piece: String, offset: Int) {
        let units = Array(note.utf16)
        let p = min(max(point, 0), units.count)
        func isBreak(_ index: Int) -> Bool { [0x0A, 0x0D, 0x2028, 0x2029].contains(units[index]) }
        /// The start of the line break that ends just before `end`, so `\r\n` counts as one.
        func breakStart(endingAt end: Int) -> Int { end >= 2 && units[end - 1] == 0x0A && units[end - 2] == 0x0D ? end - 2 : end - 1 }
        /// The end of the line break that starts at `start`.
        func breakEnd(startingAt start: Int) -> Int { units[start] == 0x0D && start + 1 < units.count && units[start + 1] == 0x0A ? start + 2 : start + 1 }

        let before: String
        if p == 0 { before = "" }
        else if !isBreak(p - 1) { before = "\n\n" }                         // in the middle or at the end of a line
        else {
            let previous = breakStart(endingAt: p)                           // at the start of a line: is the line above empty?
            before = previous == 0 || isBreak(previous - 1) ? "" : "\n"
        }
        let after: String
        if p == units.count { after = "\n" }
        else if !isBreak(p) { after = "\n\n" }
        else {
            let next = breakEnd(startingAt: p)                               // a line break follows: is the line below empty?
            after = next == units.count || isBreak(next) ? "" : "\n"
        }
        return (before + text + after, (before as NSString).length)
    }

    /// `[Title](URL)`; the URL alone without a title, the title alone without a URL.
    static func sourceLine(title: String?, url: String?) -> String? {
        let title = title.map(oneLine).flatMap { $0.isEmpty ? nil : escaped($0) }
        let url = url?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        switch (title, url) {
        case let (title?, url?): return "[\(title)](\(destination(url)))"
        case let (title?, nil): return title
        case let (nil, url?): return url
        case (nil, nil): return nil
        }
    }

    /// The selection's lines with every kind of line break as one, without the empty lines at either end.
    static func selectionLines(_ selection: String?) -> [String] {
        guard let selection else { return [] }
        var lines = lines(of: selection)
        while let first = lines.first, first.allSatisfy(\.isWhitespace) { lines.removeFirst() }
        while let last = lines.last, last.allSatisfy(\.isWhitespace) { lines.removeLast() }
        return lines
    }

    private static func lines(of text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .split(omittingEmptySubsequences: false, whereSeparator: { "\n\r\u{2028}\u{2029}".contains($0) })
            .map(String.init)
    }

    /// A title on several lines becomes one line: each line without its outer spaces, joined by one space.
    private static func oneLine(_ title: String) -> String {
        lines(of: title).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// `[` and `]` would end the link text early.
    private static func escaped(_ title: String) -> String {
        title.replacingOccurrences(of: "[", with: "\\[").replacingOccurrences(of: "]", with: "\\]")
    }

    /// A URL with a space or an unbalanced parenthesis would end the link early; Markdown takes it whole inside `<` and `>`.
    private static func destination(_ url: String) -> String {
        var depth = 0
        for character in url {
            if character.isWhitespace { return "<\(url)>" }
            if character == "(" { depth += 1 }
            if character == ")" { depth -= 1; if depth < 0 { return "<\(url)>" } }
        }
        return depth == 0 ? url : "<\(url)>"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
