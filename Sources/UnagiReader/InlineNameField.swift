import SwiftUI
import ReaderCore

/// Which sidebar row has its name open for editing (decision 0043). One at a time.
enum SidebarRenaming: Equatable {
    case feed(UUID)
}

/// The name of a sidebar row, edited in place. Return finishes, Esc cancels, and moving away finishes.
/// `onFinish` gets the typed text, or nil for Esc; `NameEdit.result` decides whether there is anything to save.
struct InlineNameField: View {
    let initial: String
    let onFinish: (String?) -> Void
    @State private var text = ""
    @State private var finished = false
    /// Moving away finishes the edit only after the field has had the focus once (the list may take it back while the row is built).
    @State private var hadFocus = false
    @FocusState private var focused: Bool

    var body: some View {
        TextField(String(localized: "Name", bundle: ReaderLocalization.bundle), text: $text.singleLine())
            .textFieldStyle(.plain).focused($focused)
            .accessibilityLabel(String(localized: "Name", bundle: ReaderLocalization.bundle))
            .onAppear { text = initial }
            // The context menu that started the edit may still be closing, and AppKit then gives the keyboard back to the sidebar.
            // One request on appearance could lose to that, leaving the field without the keyboard (#265): ask again until it has it.
            .task {
                for _ in 0..<20 where !focused {
                    focused = true
                    try? await Task.sleep(for: .milliseconds(50))
                }
            }
            .onSubmit { finish(text) }
            .onKeyPress(.escape) { finish(nil); return .handled }
            .onChange(of: focused) { _, isFocused in
                if isFocused { hadFocus = true } else if hadFocus { finish(text) }
            }
    }

    private func finish(_ value: String?) {
        guard !finished else { return }
        finished = true
        onFinish(value)
    }
}

/// Return on the selected row of the sidebar starts renaming it. The window receives the key the sidebar
/// did not use (as it does for j and k), and `begin` checks that the sidebar is where the keyboard is. It is a modifier of its own,
/// applied from outside the window's long chain (the CI compiler gives up on a longer chain).
struct RenameOnReturn: ViewModifier {
    let begin: () -> Bool
    func body(content: Content) -> some View {
        content.onKeyPress(.return) { begin() ? .handled : .ignored }
    }
}
