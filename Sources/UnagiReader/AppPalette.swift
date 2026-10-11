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

    /// The selected row of the article list: a quiet neutral gray instead of the system's saturated accent colour.
    static let selection = NSColor(name: "UnagiSelection") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1, alpha: 0.13) : NSColor(white: 0, alpha: 0.09)
    }
}
