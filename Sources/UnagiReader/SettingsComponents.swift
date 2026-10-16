import SwiftUI
import ReaderCore

/// Three tiles that show what each appearance looks like, instead of describing it in words.
struct AppearancePicker: View {
    @Binding var selection: String

    private static let choices: [(tag: String, title: String, hint: String)] = [
        ("system", "システム", "Macの外観設定に従います"),
        ("light", "ライト", "常に明るい外観にします"),
        ("dark", "ダーク", "常に暗い外観にします"),
    ]

    var body: some View {
        HStack(spacing: 18) {
            ForEach(Self.choices, id: \.tag) { choice in
                Button { selection = choice.tag } label: {
                    VStack(spacing: 8) {
                        AppearanceThumbnail(tag: choice.tag)
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .strokeBorder(selection == choice.tag ? AppPalette.accentColor : Color.primary.opacity(0.14),
                                              lineWidth: selection == choice.tag ? 2.5 : 1))
                        Text(choice.title).font(.callout)
                            .foregroundStyle(selection == choice.tag ? Color.primary : Color.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help(choice.hint)
                .accessibilityLabel(choice.title)
                .accessibilityAddTraits(selection == choice.tag ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

/// 「文字サイズ」: the article's text size in five steps (specification 3.7). The size is shown in points beside the slider.
struct ArticleTextSizeSlider: View {
    @Binding var size: Double

    var body: some View {
        let step = Binding(get: { ArticleTextSize.step(size) }, set: { size = ArticleTextSize.step($0) })
        LabeledContent("文字サイズ") {
            HStack(spacing: 10) {
                Slider(value: step, in: ArticleTextSize.steps.first!...ArticleTextSize.steps.last!, step: 2) {
                    Text("文字サイズ")
                } minimumValueLabel: {
                    Text("あ").font(.system(size: 11))
                } maximumValueLabel: {
                    Text("あ").font(.system(size: 17))
                }
                .labelsHidden()
                Text("\(Int(step.wrappedValue)) pt").monospacedDigit().foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
            }
        }
        .help("記事の本文の大きさです。見出しも同じ割合で変わります。一覧とノートは変わりません。")
    }
}

/// A small picture of the reader in light or dark. The colours are fixed: a tile must look the same whatever the app uses now.
private struct AppearanceThumbnail: View {
    let tag: String
    private let light = (back: Color(white: 0.97), bar: Color(white: 0.80), line: Color(white: 0.88))
    private let dark = (back: Color(white: 0.12), bar: Color(white: 0.34), line: Color(white: 0.22))

    var body: some View {
        ZStack {
            switch tag {
            case "light": page(light)
            case "dark": page(dark)
            default:
                ZStack {
                    page(light)
                    page(dark).mask(HalfShape(leading: false))
                }
            }
        }
        .frame(width: 92, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func page(_ c: (back: Color, bar: Color, line: Color)) -> some View {
        ZStack(alignment: .topLeading) {
            c.back
            HStack(spacing: 0) {
                c.line.frame(width: 22)
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(0..<4, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2).fill(c.bar).frame(width: index == 0 ? 40 : 56, height: 4)
                    }
                }.padding(.leading, 8).padding(.top, 10)
            }
        }
        .frame(width: 92, height: 60)
    }
}

/// The left or the right half of a view, for the tile that shows "follow the system".
private struct HalfShape: Shape {
    let leading: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(leading ? CGRect(x: rect.minX, y: rect.minY, width: rect.width / 2, height: rect.height)
                             : CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height))
        return path
    }
}

/// A coloured dot and one short word, instead of a sentence.
struct StatusDot: View {
    enum Tone { case good, waiting, off, bad }
    let tone: Tone
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
    private var color: Color {
        switch tone {
        case .good: .green
        case .waiting: .orange
        case .off: Color(nsColor: .tertiaryLabelColor)
        case .bad: .red
        }
    }
}
