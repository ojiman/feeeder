import SwiftUI
import ReaderCore

/// Below the note: two one-step AI actions, and the card they make. Nothing reaches the note except by 「採用」. The buttons are
/// borderless on purpose: borderless SwiftUI buttons are AppKit buttons, so a test can press them.
struct NoteActionPanel: View {
    @Bindable var store: ReaderStore
    let themeID: UUID
    let model: NoteActionModel
    let handle: NoteTextHandle
    /// Read so that a moved cursor re-evaluates the panel (the text view reports the real selection).
    let selection: TextSelection?
    let onAdopted: (NSRange) -> Void
    let onError: (String) -> Void

    var body: some View {
        let theme = store.theme(id: themeID)
        let note = theme?.note ?? ""
        let range = currentSelection(in: note)
        let target = NoteSection.target(in: note, selection: range)
        VStack(alignment: .leading, spacing: 8) {
            card(note: note)
            HStack(spacing: 14) {
                Label("AI", systemImage: "sparkles").font(.caption).foregroundStyle(.secondary)
                Button("わかりやすく") { model.request(.clearer, note: note, selection: currentSelection(in: note), goal: theme?.goal ?? "") }
                    .help("選んだ文章（なければカーソルのある節）を、意味を変えずに読みやすく書き直す案を作ります")
                Button("3行の要点") { model.request(.essence, note: note, selection: currentSelection(in: note), goal: theme?.goal ?? "") }
                    .help("選んだ文章（なければカーソルのある節）の要点を3行で作ります")
                Spacer(minLength: 0)
                if target == nil { Text("書き直す文章がありません").font(.caption).foregroundStyle(.tertiary) }
            }
            .buttonStyle(.borderless).disabled(target == nil || isWorking)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .onAppear { handle.expectedText = { [store, themeID] in store.theme(id: themeID)?.note } }
        // A card, or a request in flight, is dropped as soon as the note's text or the selection is no longer what it was made for.
        .onChange(of: note) { _, text in model.noteDidChange(note: text, selection: currentSelection(in: text)) }
        .onChange(of: selection) { _, _ in model.noteDidChange(note: note, selection: currentSelection(in: note)) }
    }

    private var isWorking: Bool { if case .working = model.state { return true }; return false }

    private func currentSelection(in note: String) -> NSRange {
        let length = (note as NSString).length
        guard let range = handle.selectedRange else { return NSRange(location: length, length: 0) }
        return NSRange(location: min(range.location, length), length: min(range.length, max(0, length - min(range.location, length))))
    }

    @ViewBuilder private func card(note: String) -> some View {
        switch model.state {
        case .idle: EmptyView()
        case .working:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("案を作っています…").font(.callout).foregroundStyle(.secondary)
                Button("中止") { model.cancel() }.buttonStyle(.borderless)
            }
        case .ready(let card):
            VStack(alignment: .leading, spacing: 6) {
                Text(card.action == .clearer ? "AIによる書き直しの案" : "AIによる要点の案").font(.caption.weight(.semibold))
                Text(card.answer).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                if card.wasCut { Text("長い文章のため、最初の約1,300文字から作りました。").font(.caption).foregroundStyle(.secondary) }
                Text(card.action == .clearer ? "AIによる案です。誤りを含むことがあります。元の文章は ⌘Z で戻せます。" : "AIによる案です。誤りを含むことがあります。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    Button("採用") { adopt() }
                    Button("別の案") { model.request(card.action, note: note, selection: currentSelection(in: note), goal: store.theme(id: themeID)?.goal ?? "") }
                    Button("閉じる") { model.reset() }
                }.buttonStyle(.borderless)
            }
            .padding(10).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        case .unavailable(let reason):
            Text(Self.message(for: reason)).font(.caption).foregroundStyle(.secondary)
        case .failed:
            HStack(spacing: 10) {
                Text("案を作れませんでした。もう一度試してください。").font(.caption).foregroundStyle(.secondary)
                Button("閉じる") { model.reset() }.buttonStyle(.borderless)
            }
        }
    }

    static func message(for reason: NoteActionModel.Reason) -> String {
        switch reason {
        case .disabled: "端末内AIがオフです。Settingsで有効にできます。"
        case .noText: "書き直す文章がありません。"
        case .tooLong: "長すぎます。選択範囲を短くしてください。"
        case .unsupported: "この Mac では端末内AIを使えません。"
        case .assetsMissing: "言語モデルの資産がありません。システム設定で取得できます。アプリは自動では取得しません。"
        }
    }

    /// Adopts only a card that still matches the note and the selection exactly, as one undoable edit.
    private func adopt() {
        let note = store.theme(id: themeID)?.note ?? ""
        guard let card = model.currentCard(note: note, selection: currentSelection(in: note)) else { model.reset(); return }
        let saver: (String) throws -> Void = { [store, themeID] text in try store.saveNote(themeID: themeID, text: text, at: .now) }
        do {
            let ns = note as NSString
            var after = card.target.range
            switch card.action {
            case .clearer:
                let applied = try handle.replace(card.target.range, with: card.answer, actionName: "書き直しの採用", save: saver)
                if !applied { try saver(ns.replacingCharacters(in: card.target.range, with: card.answer)) }
                after = NSRange(location: card.target.range.location, length: (card.answer as NSString).length)
            case .essence:
                let offset = NoteInsertion.characterOffset(forUTF16Offset: card.target.insertionOffset, in: note)
                let result = NoteInsertion.insert(card.answer, into: note, atCharacterOffset: offset)
                let applied = try handle.replace(NSRange(location: 0, length: ns.length), with: result.note, actionName: "要点の採用", save: saver)
                if !applied { try saver(result.note) }
                after = NSRange(location: (String(result.note.prefix(result.cursorOffset)) as NSString).length, length: 0)
            }
            model.reset()
            onAdopted(NSRange(location: after.location + after.length, length: 0))
        } catch { onError(error.localizedDescription) }
    }
}
