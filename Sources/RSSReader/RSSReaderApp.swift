import SwiftUI
import ReaderCore

@main
struct RSSReaderApp: App {
    @State private var store: ReaderStore?
    @State private var refresh: FeedRefreshController?
    @State private var aiReview: AIPackageReview?
    @State private var handoff: ClaudeHandoffController?
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
                directory = URL.applicationSupportDirectory.appending(path: "Feeeder", directoryHint: .isDirectory)
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let store = try ReaderStore(url: directory.appending(path: "Reader.store"), seedDemo: args.contains("--seed-demo"))
            _store = State(initialValue: store)
            _refresh = State(initialValue: FeedRefreshController(store: store))
            let review = AIPackageReview(store: store)
            let handoff = ClaudeHandoffController(directory: directory.appending(path: "Handoffs", directoryHint: .isDirectory), review: review, launcher: ClaudeWorkspaceLauncher())
            store.onContentPolicyChanged = { [weak store, weak handoff] in
                if let store { handoff?.reconcile(with: store, at: .now) }
            }
            // Questions and answers move into the notes (decision 0013). A failure does not stop the app: nothing was removed.
            handoff.reconcile(with: store, at: .now)
            _aiReview = State(initialValue: review)
            _handoff = State(initialValue: handoff)
            let cache = args.contains("--data-directory") ? directory.appending(path: "Cache/Images") : URL.cachesDirectory.appending(path: "Feeeder/Images")
            _imageLoader = State(initialValue: ReaderImageLoader(directory: cache))
            _lifecycleError = State(initialValue: handoff.maintenanceError)
        } catch {
            _startupError = State(initialValue: error.localizedDescription)
        }
    }

    var body: some Scene {
        Window("Feeeder", id: "reader") {
            Group {
                if let store, let refresh, let aiReview, let handoff, let imageLoader { ReaderView(store: store, refresh: refresh, aiReview: aiReview, handoff: handoff, imageLoader: imageLoader) }
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
            .task(id: handoff?.nextExpiry) {
                guard let expiry = handoff?.nextExpiry else { return }
                do {
                    try await Task.sleep(for: .seconds(max(0, expiry.timeIntervalSinceNow)))
                    try Task.checkCancellation()
                    if let store { handoff?.reconcile(with: store, at: .now) }
                } catch { /* A new deadline or closing the app cancels the previous timer. */ }
            }
            .onChange(of: handoff?.maintenanceError) { _, error in if let error { lifecycleError = error } }
            .alert("保存データを整理できませんでした", isPresented: Binding(get: { lifecycleError != nil }, set: { if !$0 { lifecycleError = nil } })) {
                Button("再試行") { lifecycleError = nil; purgeContent() }
                Button("閉じる") { lifecycleError = nil }
            } message: { Text(lifecycleError ?? "") }

        }
        .defaultSize(width: 1240, height: 810)
        .commands { CommandGroup(replacing: .newItem) {} }
        Settings {
            if let store { ReaderSettingsView(store: store, appearance: $appearance) }
        }
    }
    private func purgeContent() {
        do { try store?.purgeExpired(at: .now) } catch { lifecycleError = error.localizedDescription }
        if let store { handoff?.reconcile(with: store, at: .now); if let error = handoff?.maintenanceError { lifecycleError = error } }
    }
}
