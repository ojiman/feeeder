import SwiftUI
import ReaderCore

/// The popover behind "問いを立てる": one button per fixed lens, showing the question it would start with.
struct LensChoiceView: View {
    let themeName: String
    let onChoose: (QuestionLens) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("どの角度から問いますか").font(.headline)
            ForEach(QuestionLens.allCases.filter { $0 != .custom }, id: \.self) { lens in
                Button { onChoose(lens) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lens.title).font(.callout.weight(.semibold))
                        Text(lens.draft(themeName: themeName)).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(2).multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(lens.title)から問いを立てる")
            }
            Divider()
            Button { onChoose(.custom) } label: {
                Label("自由に書く…", systemImage: "square.and.pencil").frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel("自由に書いた問いを立てる")
        }
        .padding(14).frame(width: 320)
    }
}
