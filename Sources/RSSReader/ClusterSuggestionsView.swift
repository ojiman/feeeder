import SwiftUI
import ReaderCore

/// The strip above "未整理のStar": how many groups the assistant found. Nothing happens until the person opens it.
struct ClusterSuggestionBar: View {
    @Bindable var store: ReaderStore
    @Bindable var model: ThemeSuggestionModel
    let onCreated: (String) -> Void
    @State private var presented = false

    var body: some View {
        Button { presented = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(.orange)
                Text("まとまりの提案 \(model.clusters.groups.count)件")
                Spacer()
                if model.isFindingClusters { ProgressView().controlSize(.small) }
                Image(systemName: "chevron.down").font(.caption).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle()).padding(.horizontal, 12).padding(.vertical, 8).background(.bar)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $presented, arrowEdge: .bottom) {
            ClusterSuggestionsView(store: store, model: model, onCreated: { message in presented = false; onCreated(message) })
        }
        .accessibilityLabel("まとまりの提案 \(model.clusters.groups.count)件")
    }
}

struct ClusterSuggestionsView: View {
    @Bindable var store: ReaderStore
    @Bindable var model: ThemeSuggestionModel
    let onCreated: (String) -> Void
    /// The group being named is kept by its contents, not its position, so a recompute can never retarget it.
    @State private var naming: [UUID]?
    @State private var name = ""
    @State private var error: String?
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("まとまりの提案").font(.headline)
            Text("端末内で、近い内容の記事をまとめました。使うかどうかは自分で決めます。").font(.caption).foregroundStyle(.secondary)
            if model.clusters.usedCount < model.clusters.totalCount {
                Text("新しい\(model.clusters.usedCount)件から提案しています（未整理は\(model.clusters.totalCount)件）。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(model.clusters.groups, id: \.self) { group in card(group) }
                }
            }.frame(maxHeight: 360)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .padding(14).frame(width: 340)
        .onChange(of: model.clusters.groups) { _, groups in
            if let group = naming, !groups.contains(group) { naming = nil; name = "" }
        }
    }

    private func card(_ group: [UUID]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(group.prefix(4), id: \.self) { id in
                Text(store.article(id: id)?.title ?? "（記事が見つかりません）").lineLimit(1).font(.callout)
            }
            if group.count > 4 { Text("ほか\(group.count - 4)件").font(.caption).foregroundStyle(.secondary) }
            if naming == group {
                HStack {
                    TextField("テーマの名前", text: $name).focused($nameFocused)
                        .onSubmit { create(group) }.accessibilityLabel("テーマの名前")
                    Button("作成") { create(group) }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("やめる") { naming = nil; name = "" }
                }
            } else {
                Button("\(group.count)件でテーマにする…") { naming = group; name = ""; nameFocused = true }
            }
        }
        .padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private func create(_ group: [UUID]) {
        do {
            let theme = try store.createTheme(name: name, adding: group, at: .now)
            error = nil; naming = nil; name = ""
            onCreated("「\(theme.name)」に\(group.count)件を入れました")
        } catch { self.error = error.localizedDescription }
    }
}
