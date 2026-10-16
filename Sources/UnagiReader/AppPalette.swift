import AppKit
import SwiftUI
import Observation
import ReaderCore

/// Whether Sepia is shown (specification 3.7). Views that read the palette's SwiftUI colours depend on it, so they are drawn again when
/// it changes; AppKit views read it in their update and redraw. Set from the stored theme before the first window is drawn.
@MainActor @Observable final class ThemeState {
    static let shared = ThemeState()
    var sepia = ReaderTheme(stored: UserDefaults.standard.string(forKey: ReaderTheme.key)) == .sepia {
        didSet { AppPalette.sepiaActive = sepia }
    }
    private init() { AppPalette.sepiaActive = sepia }
}

/// The accent colour of the app: a soft orange, used for small marks only (the unread dot, the + and refresh buttons,
/// the marks of lists in a note). Quieter than `NSColor.systemOrange` (about 0.96 saturation), which glared on the dark
/// panes (decision 0027). Light and dark each have their own value so the contrast holds on both.
enum AppPalette {
    /// Read by the colours' providers when AppKit draws; it mirrors `ThemeState.sepia`.
    nonisolated(unsafe) static var sepiaActive = false

    private static func ns(_ c: SepiaPalette.RGB) -> NSColor { NSColor(srgbRed: c.red / 255, green: c.green / 255, blue: c.blue / 255, alpha: 1) }
    /// Sepia's paper (the reading surfaces) and the sidebar's slightly darker paper.
    static let paper = ns(SepiaPalette.paper)
    static let sidebarPaper = ns(SepiaPalette.sidebar)
    @MainActor static var sidebarPaperColor: Color { Color(nsColor: sidebarPaper) }

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
        default: sepiaActive ? paper : NSColor.white
        }
    }
    /// In Sepia a fixed colour (Sepia is always light), so a view that reads it is drawn again when the theme changes.
    @MainActor static var surfaceColor: Color { ThemeState.shared.sepia ? Color(nsColor: paper) : Color(nsColor: surface) }

    /// The selected row of the article list: a quiet neutral gray instead of the system's saturated accent colour.
    static var selectionColor: Color { Color(nsColor: selection) }
    static let selection = NSColor(name: "UnagiSelection") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1, alpha: 0.13) : NSColor(white: 0, alpha: 0.09)
    }
}

extension ReaderTheme {
    /// The colour scheme for SwiftUI; nil follows macOS.
    var colorScheme: ColorScheme? { isDark.map { $0 ? .dark : .light } }
}

/// Sepia's sidebar: the system's sidebar background gives way to the darker paper. The other looks keep the system's sidebar
/// (decisions 0027, 0030); the modifiers stay in place, so the list keeps its identity when the theme changes.
struct SidebarPaper: ViewModifier {
    func body(content: Content) -> some View {
        let sepia = ThemeState.shared.sepia
        content
            .scrollContentBackground(sepia ? .hidden : .automatic)
            .background(sepia ? AppPalette.sidebarPaperColor : Color.clear)
    }
}
