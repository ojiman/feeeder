import SwiftUI

/// The header of a sidebar section with a small + at its right end that appears when the pointer is over the header (like the
/// sidebars of Mail and Notes). The button is always in the accessibility tree, so VoiceOver and the keyboard can use it.
struct SidebarSectionHeader: View {
    let title: String
    let help: String
    let action: () -> Void
    /// Takes dropped subscriptions (the sources header: unfiled). Returns whether any of them moved.
    var onDropFeeds: (([UUID]) -> Bool)? = nil
    /// Shows the + without the pointer (snapshots and tests).
    var forceVisible = false
    @State private var hovering = false
    @State private var targeted = false

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            // The + ends where the counts of the rows end, and is drawn in the accent colour of the + at the top left.
            Button(action: action) { Image(systemName: "plus").imageScale(.medium).fontWeight(.semibold).frame(width: 18, height: 18) }
                .buttonStyle(.plain)
                // Not `.opacity(0)`: that removes the button from the accessibility tree. A clear icon stays reachable.
                .foregroundStyle((hovering || forceVisible) ? AnyShapeStyle(AppPalette.accentColor) : AnyShapeStyle(Color.clear))
                .help(help).accessibilityLabel(help)
                .padding(.trailing, 9)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .background((onDropFeeds != nil && targeted) ? AppPalette.selectionColor : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .dropDestination(for: FeedDrag.self) { items, _ in onDropFeeds?(items.map(\.id)) ?? false } isTargeted: { targeted = $0 }
        // The sidebar exposes a section header as one heading, so the + is also offered as an action of the heading (VoiceOver actions).
        .accessibilityAction(named: Text(help), action)
    }
}
