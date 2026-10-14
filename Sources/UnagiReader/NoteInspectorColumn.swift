import SwiftUI
import Observation
import ReaderCore

/// The width of the window, kept apart from `ReaderView`'s state: it changes on every frame of a window resize, and only the note
/// panel's column reads it.
@MainActor @Observable final class WindowSpace {
    var width: Double = 1_280
}

/// The note panel's column: as wide as the person made it, but never so wide that the article loses its 360 pt (or the list its 280 pt in
/// the three-column layout). A window that is too narrow for the saved width squeezes the panel; the saved width stays (specification 3.5).
struct NoteInspectorColumn<Panel: View>: View {
    let space: WindowSpace
    let listShown: Bool
    let startingWidth: Double
    @ViewBuilder let panel: (Double) -> Panel

    var body: some View {
        let limit = NotePanelWidth.maximum(windowWidth: space.width, listShown: listShown)
        panel(limit).inspectorColumnWidth(min: NotePanelWidth.range.lowerBound, ideal: min(startingWidth, limit), max: limit)
    }
}
