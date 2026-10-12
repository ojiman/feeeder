import SwiftUI
import UniformTypeIdentifiers

/// The File menu's 「OPMLを取り込む…」. The window that shows the library publishes the action; with no such window the item is off.
/// It has no key shortcut: it is a rare action.
struct OPMLCommands: Commands {
    @FocusedValue(\.importOPML) private var importOPML

    var body: some Commands {
        CommandGroup(replacing: .importExport) {
            Button("OPMLを取り込む…") { importOPML?() }.disabled(importOPML == nil)
        }
    }
}

private struct ImportOPMLKey: FocusedValueKey { typealias Value = () -> Void }

extension FocusedValues {
    var importOPML: (() -> Void)? {
        get { self[ImportOPMLKey.self] }
        set { self[ImportOPMLKey.self] = newValue }
    }
}

enum OPMLFilePanel {
    /// Asks for one OPML file (nil when the person cancels).
    @MainActor static func chooseFile() async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "opml"), .xml].compactMap { $0 }
        panel.message = "取り込むOPMLファイルを選んでください。"
        panel.prompt = "取り込む"
        guard let window = NSApp.keyWindow else { return panel.runModal() == .OK ? panel.url : nil }
        return await withCheckedContinuation { continuation in
            panel.beginSheetModal(for: window) { response in continuation.resume(returning: response == .OK ? panel.url : nil) }
        }
    }
}
