import SwiftUI
import ReaderCore

struct SummarySettingsView: View {
    @AppStorage(OnDeviceAISetting.key) private var enabled = true
    @AppStorage(SummarySettings.lengthKey) private var length = SummaryLength.three.rawValue
    @AppStorage(SummarySettings.formatKey) private var format = SummaryFormat.prose.rawValue
    @AppStorage(SummarySettings.instructionKey) private var instruction = ""
    @State private var availability: AssistantAvailability?

    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        _enabled = AppStorage(wrappedValue: true, OnDeviceAISetting.key, store: defaults)
        _length = AppStorage(wrappedValue: 3, SummarySettings.lengthKey, store: defaults)
        _format = AppStorage(wrappedValue: "prose", SummarySettings.formatKey, store: defaults)
        _instruction = AppStorage(wrappedValue: "", SummarySettings.instructionKey, store: defaults)
    }

    var body: some View {
        Form {
            Section {
                Toggle("AIで要約", isOn: $enabled)
                    .help("要約はこの Mac の中だけで作ります。オフのときは、RSS要約と出典を送ります。")
                LabeledContent("状態") { StatusDot(tone: statusTone, text: statusText) }
                    .help("モデルの資産が無い場合、アプリは自動で取得しません。")
            }
            Section {
                Picker("長さ", selection: $length) {
                    Text("1文").tag(1); Text("3文以内").tag(3); Text("5文以内").tag(5)
                }.pickerStyle(.segmented)
                Picker("形式", selection: $format) {
                    Text("文章").tag(SummaryFormat.prose.rawValue)
                    Text("箇条書き").tag(SummaryFormat.bullets.rawValue)
                }.pickerStyle(.segmented)
                TextField("追加の指示", text: Binding(
                    get: { instruction }, set: { instruction = String(SingleLineText.lineBreaksRemoved($0).prefix(200)) }),
                    prompt: Text("例: 専門用語は残す"))
                    .help("本人の言葉で、200文字まで。")
            }
            .disabled(!enabled)
        }
        .formStyle(.grouped).scrollDisabled(true).fixedSize(horizontal: false, vertical: true)
        .onAppear {
            let values = SummarySettings.load(from: defaults)
            length = values.length.rawValue; format = values.format.rawValue; instruction = values.extraInstruction
        }
        .task(id: enabled) { availability = enabled ? await FoundationModelsGenerator().generationAvailability() : nil }
    }
    private var statusTone: StatusDot.Tone {
        guard enabled else { return .off }
        return switch availability {
        case nil, .assetsMissing?: .waiting
        case .available?: .good
        case .unsupported?: .bad
        }
    }
    private var statusText: String {
        guard enabled else { return "オフ" }
        return switch availability {
        case nil: "確認中…"
        case .available: "使えます"
        case .assetsMissing: "モデルの準備中です"
        case .unsupported: "この環境では使えません"
        }
    }
}
