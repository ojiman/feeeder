import SwiftUI
import UniformTypeIdentifiers
import ReaderCore

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

/// What the library window adds for the OPML import: the action the File menu runs, and the alert with the report.
/// It is a modifier of its own because the window's body is already long, and the CI compiler gives up on a longer chain.
struct OPMLImportPresentation: ViewModifier {
    let flow: OPMLImportFlow

    func body(content: Content) -> some View {
        content
            .focusedSceneValue(\.importOPML, { Task { await flow.start() } })
            .alert(flow.report?.title ?? "", isPresented: Binding(get: { flow.report != nil }, set: { if !$0 { flow.dismissReport() } })) {
                Button("OK") { flow.dismissReport() }
            } message: {
                if let message = flow.report?.message, !message.isEmpty { Text(message) }
            }
    }
}
