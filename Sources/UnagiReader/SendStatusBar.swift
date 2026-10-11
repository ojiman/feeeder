import SwiftUI
import ReaderCore

struct SendStatusBar: View {
    @Bindable var sender: SummarySender
    var onOpen: ((UUID) -> Void)? = nil
    var body: some View {
        if sender.state != .idle {
            HStack(spacing: 10) {
                switch sender.state {
                case .working:
                    ProgressView().controlSize(.small)
                    Text("要約を作っています…")
                    Button("中止") { sender.cancel() }
                case .done(let result):
                    Text(result.message).lineLimit(2)
                    if let onOpen { Button("開く") { onOpen(result.send.noteID) } }
                    TimelineView(.periodic(from: .now, by: 0.25)) { context in
                        if context.date < result.undoUntil { Button("取り消す") { sender.undo() } }
                    }
                case .failed(let message): Text("送れませんでした: \(message)").lineLimit(2)
                case .message(let message): Text(message).lineLimit(2)
                case .idle: EmptyView()
                }
                if !sender.isWorking {
                    Button("閉じる", systemImage: "xmark") { sender.dismiss() }.labelStyle(.iconOnly)
                }
            }
            .buttonStyle(.borderless).padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)).padding()
            .accessibilityElement(children: .contain).accessibilityLabel("要約の送信結果")
        }
    }
}
