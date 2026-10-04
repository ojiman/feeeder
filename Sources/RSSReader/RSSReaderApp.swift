import SwiftUI
import ReaderCore

@main
struct RSSReaderApp: App {
    @State private var store: ReaderStore?
    @State private var startupError: String?
    @State private var lifecycleError: String?
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearance = "system"

    init() {
        do {
            let args = ProcessInfo.processInfo.arguments
            let directory: URL
            if let index = args.firstIndex(of: "--data-directory"), args.indices.contains(index + 1) {
                directory = URL(fileURLWithPath: args[index + 1], isDirectory: true)
            } else {
                directory = URL.applicationSupportDirectory.appending(path: "Feeeder", directoryHint: .isDirectory)
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            _store = State(initialValue: try ReaderStore(url: directory.appending(path: "Reader.store"), seedDemo: args.contains("--seed-demo")))
        } catch {
            _startupError = State(initialValue: error.localizedDescription)
        }
    }

    var body: some Scene {
        Window("RSS Reader", id: "reader") {
            Group {
                if let store { ReaderView(store: store, appearance: $appearance) }
                else {
                    ContentUnavailableView("ライブラリを開けませんでした", systemImage: "externaldrive.badge.exclamationmark",
                        description: Text(startupError ?? "不明なエラーです。"))
                        .frame(width: 600, height: 400)
                }
            }
            .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { purgeContent() }
            }
            .task {
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(3600)) } catch { break }
                    purgeContent()
                }
            }
            .alert("保存データを整理できませんでした", isPresented: Binding(get: { lifecycleError != nil }, set: { if !$0 { lifecycleError = nil } })) {
                Button("閉じる") { lifecycleError = nil }
            } message: { Text(lifecycleError ?? "") }

        }
        .defaultSize(width: 1240, height: 810)
        .commands { CommandGroup(replacing: .newItem) {} }
        Settings {
            if let store { ReaderSettingsView(store: store) }
        }
    }
    private func purgeContent() {
        do { try store?.purgeExpired(at: .now) } catch { lifecycleError = error.localizedDescription }
    }
}
