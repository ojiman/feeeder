import SwiftUI

/// A row of the sidebar: icon, title, and at the right end the count. When the row can take a new subscription (a folder), the count
/// is replaced by a small + in the accent colour while the pointer is over the row.
struct SidebarRow: View {
    let title: String
    let symbol: String
    let count: Int
    var addHelp: String? = nil
    var onAdd: () -> Void = {}
    /// Shows the + without the pointer (snapshots and tests).
    var forceHover = false
    @State private var hovering = false

    private var showsAdd: Bool { addHelp != nil && (hovering || forceHover) }

    var body: some View {
        HStack {
            // Quiet icons (the system would colour them with its blue accent in the active window) and text a little softer than pure white.
            Label { Text(title).foregroundStyle(.primary.opacity(0.85)) } icon: { Image(systemName: symbol).foregroundStyle(.secondary) }.lineLimit(1)
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
    }
}
