import SwiftUI

/// The header of a sidebar section with a small + at its right end that appears when the pointer is over the header (like the
/// sidebars of Mail and Notes). The button is always in the accessibility tree, so VoiceOver and the keyboard can use it.
struct SidebarSectionHeader: View {
    let title: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button(action: action) { Image(systemName: "plus").imageScale(.small).frame(width: 18, height: 18) }
                .buttonStyle(.plain)
                // Not `.opacity(0)`: that removes the button from the accessibility tree. A clear icon stays reachable.
                .foregroundStyle(hovering ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.clear))
                .help(help).accessibilityLabel(help)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        // The sidebar exposes a section header as one heading, so the + is also offered as an action of the heading (VoiceOver actions).
        .accessibilityAction(named: Text(help), action)
    }
}
