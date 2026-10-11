import AppKit
import SwiftUI

/// The accent colour of the app: a soft orange, used for small marks only (the unread dot, the + and refresh buttons,
/// the marks of lists in a note). Quieter than `NSColor.systemOrange` (about 0.96 saturation), which glared on the dark
/// panes (decision 0027). Light and dark each have their own value so the contrast holds on both.
enum AppPalette {
    static let accent = NSColor(name: "UnagiAccent") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.90, green: 0.64, blue: 0.40, alpha: 1)
            : NSColor(srgbRed: 0.76, green: 0.40, blue: 0.14, alpha: 1)
    }
    static var accentColor: Color { Color(nsColor: accent) }

    /// The one dark of every reading surface: the article list, the article and the note. (Before, the list, the article, the note's
    /// header and the toolbar each had their own gray, and thin lines between them.)
    /// Fixed values, not `textBackgroundColor`: inside a column of the split view the system resolves that colour with a vibrant
    /// appearance and gets a lighter, bluish gray, so the list did not match the article next to it.
    static let surface = NSColor(name: "UnagiSurface") { appearance in
        switch appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight]) {
        case .darkAqua?, .vibrantDark?: NSColor(srgbRed: 30 / 255, green: 30 / 255, blue: 30 / 255, alpha: 1)
        default: NSColor.white
        }
    }
    static var surfaceColor: Color { Color(nsColor: surface) }

    /// The selected row of the article list: a quiet neutral gray instead of the system's saturated accent colour.
    static var selectionColor: Color { Color(nsColor: selection) }
    static let selection = NSColor(name: "UnagiSelection") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1, alpha: 0.13) : NSColor(white: 0, alpha: 0.09)
    }
}
