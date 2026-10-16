import SwiftUI
import ReaderCore

@main
struct UnagiReaderApp: App {
    @State private var store: ReaderStore?
    @State private var refresh: FeedRefreshController?
    @State private var imageLoader: ReaderImageLoader?
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
                directory = URL.applicationSupportDirectory.appending(path: AppIdentity.dataFolderName, directoryHint: .isDirectory)
            }
            if ReadingBenchmark.requested { try ReadingBenchmark.validateFixture(at: directory, explicit: args.contains("--data-directory")) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let store = try ReaderStore(url: directory.appending(path: "Reader.store"), seedDemo: args.contains("--seed-demo"))
            // Once per library: remove the bodies an earlier version took from the original pages by itself (decision 0033). The marker is a
            // file in the library's folder; a failure leaves no marker, so it is tried again at the next start.
            _ = try? store.discardExtractedBodiesOnce(marker: directory.appending(path: ".extracted-bodies-discarded-v1"))
            _store = State(initialValue: store)
            let client = ReadingBenchmark.requested ? FeedClient(http: ReadingBenchmark.SyntheticHTTP()) : FeedClient()
            _refresh = State(initialValue: FeedRefreshController(store: store, client: client))
            // The copies of the note that the hand-off to Claude made are not deleted by anything now (decision 0049).
            do { try LegacyHandoffFolder.remove(in: directory) } catch { _lifecycleError = State(initialValue: error.localizedDescription) }
            let cache = args.contains("--data-directory") ? directory.appending(path: "Cache/Images") : URL.cachesDirectory.appending(path: "\(AppIdentity.dataFolderName)/Images")
            _imageLoader = State(initialValue: ReaderImageLoader(directory: cache))
        } catch {
            _startupError = State(initialValue: error.localizedDescription)
        }
    }

    var body: some Scene {
        Window("Unagi Reader", id: "reader") {
            Group {
                if let store, let refresh, let imageLoader { ReaderView(store: store, refresh: refresh, imageLoader: imageLoader) }
                else {
                    ContentUnavailableView("ライブラリを開けませんでした", systemImage: "externaldrive.badge.exclamationmark",
                        description: Text(startupError ?? "不明なエラーです。"))
                        .frame(width: 600, height: 400)
                }
            }
            .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { purgeContent(); Task { await refresh?.refresh() } }
            }
            .task {
                await refresh?.refresh()
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(1800)) } catch { break }
                    purgeContent()
                    await refresh?.refresh()
                }
            }
            .task {
                guard ReaderPerformance.output != nil else { return }
                while !Task.isCancelled {
                    ReaderPerformance.heartbeat()
                    do { try await Task.sleep(for: .milliseconds(20)) } catch { break }
                }
                ReaderPerformance.write()
            }
            .alert("保存データを整理できませんでした", isPresented: Binding(get: { lifecycleError != nil }, set: { if !$0 { lifecycleError = nil } })) {
                Button("再試行") { lifecycleError = nil; purgeContent() }
                Button("閉じる") { lifecycleError = nil }
            } message: { Text(lifecycleError ?? "") }

        }
        .defaultSize(width: 1240, height: 810)
        // No title bar and no system toolbar: each column draws its own band (decision 0057).
        .windowStyle(.hiddenTitleBar)
        .commands { CommandGroup(replacing: .newItem) {}; OPMLCommands(); ReaderMenuCommands(); TranslationCommands() }
        Settings {
            if let store { ReaderSettingsView(store: store, appearance: $appearance) }
        }
    }
    private func purgeContent() {
        do { try store?.purgeExpired(at: .now) } catch { lifecycleError = error.localizedDescription }
    }
}
