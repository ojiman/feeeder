import SwiftUI

/// The band's actions in the menu bar (decision 0057: nothing is only in a band; Apple's guideline for toolbar items). The library window
/// publishes them; with no such window the items are off.
struct ReaderActions {
    let noteOpen: Bool
    let toggleNote: () -> Void
    let starred: Bool
    let canStar: Bool
    let toggleStar: () -> Void
    let canSendToNote: Bool
    let sendToNote: () -> Void
    let canOpenBrowser: Bool
    let openBrowser: () -> Void
}

private struct ReaderActionsKey: FocusedValueKey { typealias Value = ReaderActions }

extension FocusedValues {
    var readerActions: ReaderActions? {
        get { self[ReaderActionsKey.self] }
        set { self[ReaderActionsKey.self] = newValue }
    }
}

struct ReaderMenuCommands: Commands {
    @FocusedValue(\.readerActions) private var actions

    var body: some Commands {
        CommandGroup(before: .toolbar) {
            Button(actions?.noteOpen == true ? "ノートを閉じる" : "ノートを開く") { actions?.toggleNote() }
                .keyboardShortcut("i", modifiers: [.option, .command])
                .disabled(actions == nil)
        }
        CommandMenu("記事") {
            Button(actions?.starred == true ? "Starを外す" : "Starを付ける") { actions?.toggleStar() }
                .disabled(actions?.canStar != true)
            // 「記事をノートに送る」 (specification 3.3); its key `c` is a reading key, not shown here, as with the others in this menu.
            Button("記事をノートに送る") { actions?.sendToNote() }
                .disabled(actions?.canSendToNote != true)
            Button("元ページをブラウザで開く") { actions?.openBrowser() }
                .disabled(actions?.canOpenBrowser != true)
        }
    }
}

/// Help ▸ 「ショートカット一覧」: opens Settings on the shortcut list (specification 3.7).
struct ShortcutHelpCommands: Commands {
    @Environment(\.openSettings) private var openSettings

    var body: some Commands {
        CommandGroup(after: .help) {
            Button("ショートカット一覧") {
                UserDefaults.standard.set(ReaderSettingsView.Pane.shortcuts.rawValue, forKey: ReaderSettingsView.paneKey)
                openSettings()
            }
        }
    }
}
