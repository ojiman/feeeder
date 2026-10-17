import SwiftUI
import ReaderCore

struct ReaderSettingsView: View {
    @Bindable var store: ReaderStore
    @Binding var appearance: String
    @State private var days = 30
    @State private var pendingDays: Int?
    @State private var deletingAll = false
    @State private var preview: DeletionPreview?
    @State private var error: String?

    enum Pane: String { case appearance, language, shortcuts, storage }
    /// The pane shown last; Help ▸ 「ショートカット一覧」 sets it before it opens the window.
    static let paneKey = "settingsPane"
    @AppStorage(ReaderSettingsView.paneKey) private var pane = Pane.appearance.rawValue
    @AppStorage(ArticleTextSize.key) private var textSize = ArticleTextSize.standard

    var body: some View {
        TabView(selection: Binding(get: { Pane(rawValue: pane) ?? .appearance }, set: { pane = $0.rawValue })) {
            Tab(String(localized: "Appearance", bundle: ReaderLocalization.bundle), systemImage: "circle.lefthalf.filled", value: Pane.appearance) { appearancePane }
            Tab(String(localized: "Language", bundle: ReaderLocalization.bundle), systemImage: "globe", value: Pane.language) { TranslationLanguageSettings() }
            Tab(String(localized: "Shortcuts", bundle: ReaderLocalization.bundle), systemImage: "keyboard", value: Pane.shortcuts) { ShortcutList() }
            Tab(String(localized: "Storage", bundle: ReaderLocalization.bundle), systemImage: "externaldrive", value: Pane.storage) { storage }
        }
        .tint(AppPalette.accentColor)
        .frame(width: 540)
        .preferredColorScheme(ReaderTheme(stored: appearance).colorScheme)
        .onAppear { days = store.retentionDays }
        .onChange(of: days) { _, value in
            guard value != store.retentionDays else { return }
            if value < store.retentionDays {
                perform { preview = try store.previewDeletion(days: value, allContent: false, at: .now); pendingDays = value }
            } else { perform { try store.applyRetention(days: value, at: .now) } }
        }
        .confirmationDialog(deletingAll ? String(localized: "Delete article bodies and RSS summaries?", bundle: ReaderLocalization.bundle) : String(localized: "Change retention to \(pendingDays ?? days) days?", bundle: ReaderLocalization.bundle),
                            isPresented: Binding(get: { preview != nil }, set: { if !$0 { cancel() } })) {
            Button(deletingAll ? String(localized: "Delete Bodies and RSS Summaries", bundle: ReaderLocalization.bundle) : String(localized: "Change Retention", bundle: ReaderLocalization.bundle), role: .destructive) {
                perform {
                    if deletingAll {
                        let current = try store.previewDeletion(days: nil, allContent: true, at: .now)
                        try store.deleteContent(articleIDs: current.articleIDs, at: .now)
                    } else if let pendingDays { try store.applyRetention(days: pendingDays, at: .now) }
                }
                cancel()
            }
            Button(String(localized: "Cancel", bundle: ReaderLocalization.bundle), role: .cancel) { cancel() }
        } message: {
            if let preview {
                Text(String(localized: "Article bodies: \(preview.bodyCount). RSS summaries: \(preview.summaryCount). About \(byteCount(preview.estimatedBytes)) will be deleted. The note is kept. Extending retention will not restore deleted bodies.", bundle: ReaderLocalization.bundle))
            }
        }
        .alert(String(localized: "Could Not Apply Change", bundle: ReaderLocalization.bundle), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button(String(localized: "Close", bundle: ReaderLocalization.bundle)) { error = nil }
        } message: { Text(error ?? "") }
    }
    private var appearancePane: some View {
        Form {
            Section { AppearancePicker(selection: $appearance) }
            Section { ArticleTextSizeSlider(size: $textSize) }
        }
        .formStyle(.grouped).scrollDisabled(true).fixedSize(horizontal: false, vertical: true)
    }
    private var storage: some View {
        Form {
            Section {
                Picker(String(localized: "Retention", bundle: ReaderLocalization.bundle), selection: $days) {
                    ForEach(RetentionPolicy.choices, id: \.self) { Text($0 == 365 ? String(localized: "1 Year", bundle: ReaderLocalization.bundle) : String(localized: "\($0) days", bundle: ReaderLocalization.bundle)).tag($0) }
                }
                .pickerStyle(.segmented)
                .help(String(localized: "Count from first receipt for unread articles, or first reading for read articles. Fetching again does not extend retention.", bundle: ReaderLocalization.bundle))
            }
            Section {
                LabeledContent(String(localized: "Article Bodies and RSS Summaries", bundle: ReaderLocalization.bundle)) {
                    Button(String(localized: "Delete…", bundle: ReaderLocalization.bundle), role: .destructive) {
                        perform { preview = try store.previewDeletion(days: nil, allContent: true, at: .now); deletingAll = true }
                    }
                }
                .help(String(localized: "The note is never deleted automatically.", bundle: ReaderLocalization.bundle))
            }
        }
        .formStyle(.grouped).scrollDisabled(true).fixedSize(horizontal: false, vertical: true)
    }
    private func byteCount(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file; formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: Int64(bytes))
    }
    private func cancel() { preview = nil; pendingDays = nil; deletingAll = false; days = store.retentionDays }
    private func perform(_ operation: () throws -> Void) {
        do { try operation() } catch { self.error = error.localizedDescription; days = store.retentionDays }
    }
}

struct TranslationLanguageSettings: View {
    @AppStorage(TranslationTarget.key) private var target = ""
    @State private var languages: [String] = []
    @State private var appLanguage = AppLanguage.selection()

    var body: some View {
        Form {
            Section {
                Picker(String(localized: "App Language", bundle: ReaderLocalization.bundle), selection: Binding(get: { appLanguage }, set: { value in
                    AppLanguage.set(value); appLanguage = value
                })) {
                    Text(String(localized: "Match System", bundle: ReaderLocalization.bundle)).tag("")
                    ForEach(ReaderLocalization.languages, id: \.self) { language in
                        Text(TranslationLanguages.name(language)).tag(language)
                    }
                }
                Text(String(localized: "Applies at next launch.", bundle: ReaderLocalization.bundle))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Picker(String(localized: "Article Translation", bundle: ReaderLocalization.bundle), selection: $target) {
                Text(String(localized: "Match System", bundle: ReaderLocalization.bundle)).tag("")
                ForEach(languages.sorted { TranslationLanguages.name($0).localizedStandardCompare(TranslationLanguages.name($1)) == .orderedAscending }, id: \.self) {
                    Text(TranslationLanguages.name($0)).tag($0)
                }
                if !target.isEmpty && !languages.contains(target) { Text(TranslationLanguages.name(target)).tag(target) }
            }
        }
        .formStyle(.grouped).scrollDisabled(true).fixedSize(horizontal: false, vertical: true)
        .task { languages = await TranslationLanguages.available() }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in appLanguage = AppLanguage.selection() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in appLanguage = AppLanguage.selection() }
    }
}
