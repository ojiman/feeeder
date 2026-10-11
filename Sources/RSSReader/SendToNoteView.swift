import SwiftUI
import ReaderCore

struct SendToNoteView: View {
    @Bindable var store: ReaderStore
    let onSend: (UUID?) -> Void
    let onClose: () -> Void
    @State private var highlighted = 0
    @FocusState private var focused: Bool
    private var recent: [Note] { Array(store.notesNewestEditFirst.prefix(8)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ノートに要約を送る").font(.headline).padding(.bottom, 6)
            row("新しいノート", index: 0, id: nil)
            ForEach(Array(recent.enumerated()), id: \.element.id) { index, note in
                row(note.title, index: index + 1, id: note.id)
            }
            Text("↑↓で選び、Returnで送る。Escで閉じる。")
                .font(.caption2).foregroundStyle(.secondary).padding(.top, 6)
        }
        .padding(14).frame(width: 300)
        .focusable().focused($focused).focusEffectDisabled()
        .onAppear { focused = true }
        .onKeyPress(.upArrow) { highlighted = max(0, highlighted - 1); return .handled }
        .onKeyPress(.downArrow) { highlighted = min(recent.count, highlighted + 1); return .handled }
        .onKeyPress(.return) {
            guard highlighted <= recent.count else { return .handled }
            onSend(highlighted == 0 ? nil : recent[highlighted - 1].id); return .handled
        }
        .onKeyPress(.escape) { onClose(); return .handled }
    }
    private func row(_ title: String, index: Int, id: UUID?) -> some View {
        Button { onSend(id) } label: {
            HStack {
                Text(title).lineLimit(1)
                Spacer(minLength: 0)
            }.padding(6)
                .background(highlighted == index ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 5))
        }.buttonStyle(.borderless).accessibilityLabel(title)
    }
}
