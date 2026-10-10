import SwiftUI
import ReaderCore

/// The theme's goal, at the top of the article list and of the note panel. An empty goal is a quiet invitation to write one.
struct ThemeGoalStrip: View {
    let goal: String
    let onEdit: () -> Void
    var body: some View {
        Button(action: onEdit) {
            Group {
                if goal.isEmpty { Text("ゴールを書く…").foregroundStyle(.tertiary) }
                else { Text(goal).foregroundStyle(.secondary).lineLimit(2) }
            }
            .font(.caption).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }
        .buttonStyle(.plain).padding(.horizontal, 12).padding(.bottom, 8).background(.bar)
        .accessibilityLabel(goal.isEmpty ? "学習ゴールを書く" : "学習ゴール: \(goal)").accessibilityHint("名前とゴールを編集")
    }
}
