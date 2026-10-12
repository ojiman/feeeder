import SwiftUI

/// A row of the sidebar: icon, title, and at the right end the count. When the row can take a new subscription (a folder), the count
/// is replaced by a small + in the accent colour while the pointer is over the row.
struct SidebarRow: View {
    let title: String
    let symbol: String
    let count: Int
    var addHelp: String? = nil
    var onAdd: () -> Void = {}
    /// Takes dropped subscriptions (a folder row). Returns whether any of them moved.
    var onDropFeeds: (([UUID]) -> Bool)? = nil
    /// Shows the row as the target of a drag without a drag (snapshots and tests).
    var forceTargeted = false
    /// Shows the + without the pointer (snapshots and tests).
    var forceHover = false
    /// Set while the name is being edited in place: what the field starts with, and what to do with the result (nil: cancelled).
    var inlineEdit: (initial: String, finish: (String?) -> Void)? = nil
    @State private var hovering = false
    @State private var targeted = false

    private var showsAdd: Bool { addHelp != nil && (hovering || forceHover) }

    var body: some View {
        HStack {
            // Quiet icons (the system would colour them with its blue accent in the active window) and text a little softer than pure white.
            Label {
                if let inlineEdit { InlineNameField(initial: inlineEdit.initial, onFinish: inlineEdit.finish) }
                else { Text(title).foregroundStyle(.primary.opacity(0.85)) }
            } icon: { Image(systemName: symbol).foregroundStyle(.secondary) }.lineLimit(1)
            Spacer()
            ZStack(alignment: .trailing) {
                Text(count.formatted()).font(.caption.monospacedDigit()).foregroundStyle(.secondary).opacity(showsAdd ? 0 : 1)
                if let addHelp {
                    // Not `.opacity(0)`: that removes the button from the accessibility tree. A clear icon stays reachable.
                    Button(action: onAdd) { Image(systemName: "plus").imageScale(.medium).fontWeight(.semibold).frame(width: 18, height: 18) }
                        .buttonStyle(.plain)
                        .foregroundStyle(showsAdd ? AnyShapeStyle(AppPalette.accentColor) : AnyShapeStyle(Color.clear))
                        .help(addHelp).accessibilityLabel(addHelp)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .background((onDropFeeds != nil && (targeted || forceTargeted)) ? AppPalette.selectionColor : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .dropDestination(for: FeedDrag.self) { items, _ in onDropFeeds?(items.map(\.id)) ?? false } isTargeted: { targeted = $0 }
    }
}
