import AppKit
import ReaderCore

/// The look of the note editor: system fonts and semantic colours, applied as display attributes only (the text is never changed).
/// A heading is bold and larger, its `#` marks are drawn in the secondary colour; a list item has its marker in the app's orange and a
/// hanging indent, so wrapped lines align with the text after the marker (decision 0019, S5).
@MainActor enum NoteEditorStyle {
    static var baseFont: NSFont { .preferredFont(forTextStyle: .body) }
    static let markerColor = NSColor.systemOrange
    static let marksColor = NSColor.secondaryLabelColor

    static func baseAttributes() -> [NSAttributedString.Key: Any] {
        [.font: baseFont, .foregroundColor: NSColor.labelColor, .paragraphStyle: NSParagraphStyle.default]
    }

    /// The heading font: level 1 about 1.5x, 2 about 1.3x, 3 about 1.15x, 4 to 6 the body size, all bold.
    static func headingFont(level: Int) -> NSFont {
        let scale: CGFloat = switch level { case 1: 1.5; case 2: 1.3; case 3: 1.15; default: 1 }
        return .systemFont(ofSize: baseFont.pointSize * scale, weight: .bold)
    }

    /// Restyles the paragraphs that touch `range`: first everything back to the base look, then the runs found in them.
    static func apply(to storage: NSTextStorage, around range: NSRange) {
        let whole = storage.length
        guard whole > 0 else { return }
        let clamped = NSIntersectionRange(NSRange(location: 0, length: whole), range)
        let location = min(clamped.location, whole - 1)
        let source = storage.string as NSString
        let paragraphs = source.paragraphRange(for: NSRange(location: location, length: max(clamped.length, 0)))
        storage.beginEditing()
        storage.setAttributes(baseAttributes(), range: paragraphs)
        var widths: [String: CGFloat] = [:]
        let runs = NoteLineStyle.runs(in: source.substring(with: paragraphs), baseOffset: paragraphs.location)
        for run in runs {
            switch run.kind {
            case .heading(let level):
                storage.addAttribute(.font, value: headingFont(level: level), range: run.line)
                storage.addAttribute(.foregroundColor, value: marksColor, range: run.marker)
            case .listItem:
                storage.addAttribute(.foregroundColor, value: markerColor, range: run.marker)
                let prefix = NSRange(location: run.line.location, length: min(run.line.length, run.marker.location + run.marker.length + 1 - run.line.location))
                let text = source.substring(with: prefix)
                let width = widths[text] ?? (text as NSString).size(withAttributes: [.font: baseFont]).width
                widths[text] = width
                let style = NSMutableParagraphStyle()
                style.headIndent = width
                storage.addAttribute(.paragraphStyle, value: style, range: run.line)
            }
        }
        storage.endEditing()
    }
}
