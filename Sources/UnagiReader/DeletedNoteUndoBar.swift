import SwiftUI
import ReaderCore

/// 「ノートを削除しました　取り消す」 at the bottom left for ten seconds after a note was deleted (decision 0042).
/// A modifier of its own, applied from outside the window's long body chain (the CI compiler gives up on a longer chain).
struct DeletedNoteUndoBar: ViewModifier {
    let offer: DeletedNoteOffer
    let onRestore: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomLeading) {
                if offer.deleted != nil {
                    HStack(spacing: 12) {
                        Text("ノートを削除しました")
                        Button("取り消す", action: onRestore)
                    }
                    .font(.callout).padding(10).background(.regularMaterial, in: .rect(cornerRadius: 8)).padding(12)
                }
            }
            .task(id: offer.deleted?.id) {
                guard offer.deleted != nil else { return }
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                offer.dismiss()
            }
    }
}
