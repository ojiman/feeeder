import SwiftUI
import ReaderCore

/// Keeps the width the person gives the note panel by dragging its edge.
///
/// The width lives here, not in `ReaderView`. It changes on every frame of a drag, and a state change in `ReaderView` redraws the
/// whole reader each time (the list is recomputed on each pass). With the width really applied to the panel, that made the app
/// spin at full CPU while the edge was dragged.
struct NotePanelWidthMemory: ViewModifier {
    /// The widest the window allows now (`NotePanelWidth.maximum`): a width at this limit is the window's, not the person's.
    var limit: Double = NotePanelWidth.range.upperBound + 1
    /// The first width the layout gave this panel: only a change from it can be the person's drag.
    @State private var firstWidth: Double?
    @State private var width: Double?

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: Double.self, of: { Double($0.size.width) }) { newWidth in
                if firstWidth == nil { firstWidth = newWidth }
                width = newWidth
            }
            .task(id: width) {
                // Keep the width after the person lets go: wait for the drag to settle, then save it once.
                guard let width else { return }
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled, NotePanelWidth.shouldSave(new: width, saved: UserDefaults.standard.object(forKey: NotePanelWidth.key) as? Double, firstSeen: firstWidth, limit: limit) else { return }
                NotePanelWidth.save(width)
            }
    }
}
