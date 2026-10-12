import SwiftUI
import ReaderCore

/// Which sidebar row has its name open for editing (decision 0043). One at a time.
enum SidebarRenaming: Equatable {
    case feed(UUID)
}

/// The name of a sidebar row, edited in place. Return finishes, Esc cancels, and moving away finishes (as in the Finder).
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
        TextField("名前", text: $text.singleLine())
            .textFieldStyle(.plain).focused($focused)
            .accessibilityLabel("名前")
            .onAppear { text = initial; focused = true }
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

/// Return on the selected row of the sidebar starts renaming it (as in the Finder). The window receives the key the sidebar
/// did not use (as it does for j and k), and `begin` checks that the sidebar is where the keyboard is. It is a modifier of its own,
/// applied from outside the window's long chain (the CI compiler gives up on a longer chain).
struct RenameOnReturn: ViewModifier {
    let begin: () -> Bool
    func body(content: Content) -> some View {
        content.onKeyPress(.return) { begin() ? .handled : .ignored }
    }
}
