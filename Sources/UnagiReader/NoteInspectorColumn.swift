import SwiftUI
import Observation
import ReaderCore

/// The width of the window, kept apart from `ReaderView`'s state: it changes on every frame of a window resize, and only the note
/// panel's column reads it.
@MainActor @Observable final class WindowSpace {
    var width: Double = 1_280
    /// The list's width while it is shown beside the note (not while it folds or comes back: only widths from its minimum up count).
    var listWidth: Double = NotePanelWidth.listDefaultWidth
    /// The note panel's width now.
    var noteWidth: Double = NotePanelWidth.defaultWidth
}

/// The note panel's column: as wide as the person made it, but never so wide that the article loses its 360 pt, or the list the width it has
/// when it is shown (at least 280 pt; its room is kept also while it is folded). A window that is too narrow for the saved width squeezes
/// the panel; the saved width stays (specification 3.5).
struct NoteInspectorColumn<Panel: View>: View {
    let space: WindowSpace
    let startingWidth: Double
    @ViewBuilder let panel: (Double) -> Panel

    var body: some View {
        let limit = NotePanelWidth.maximum(windowWidth: space.width, listWidth: space.listWidth)
        panel(limit).inspectorColumnWidth(min: NotePanelWidth.range.lowerBound, ideal: min(startingWidth, limit), max: limit)
    }
}
