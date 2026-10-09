// Throwaway probe, not product code. Copy into Tests/ReaderUITests in a clean snapshot.
import AppKit
import SwiftUI
import Testing
import FoundationModels
import NaturalLanguage
import ReaderCore
@testable import RSSReader

@Suite(.serialized) @MainActor struct SettingsFeasibilityProbe {
    @Observable final class State {
        var category = 0
        var noteSize = 16.0
        var text = "合成ノート🙂。自分の答えといまの理解を書きます。\nSynthetic answer with evidence."
    }
    struct Preview: View {
        let state: State
        let defaults: UserDefaults
        @AppStorage var appearance: String
        @AppStorage var enabled: Bool
        init(state: State, defaults: UserDefaults) {
            self.state = state; self.defaults = defaults
            _appearance = AppStorage(wrappedValue: "system", "appearance", store: defaults)
            _enabled = AppStorage(wrappedValue: true, "onDeviceSuggestions", store: defaults)
        }
        var body: some View {
            @Bindable var state = state
            TabView(selection: $state.category) {
                Form {
                    Picker("外観", selection: $appearance) {
                        Text("システム").tag("system"); Text("ライト").tag("light"); Text("ダーク").tag("dark")
                    }.pickerStyle(.segmented)
                }.formStyle(.grouped).tabItem { Label("外観", systemImage: "circle.lefthalf.filled") }.tag(0)
                Form {
                    Picker("ノートの文字サイズ", selection: $state.noteSize) {
                        ForEach([14.0, 16, 18, 20], id: \.self) { Text("\(Int($0)) pt").tag($0) }
                    }
                    TextEditor(text: $state.text).font(.system(size: state.noteSize))
                        .frame(height: 220).accessibilityLabel("合成ノート")
                }.formStyle(.grouped).tabItem { Label("読書・編集", systemImage: "textformat.size") }.tag(1)
                Form {
                    Toggle("端末内の提案を使う", isOn: $enabled)
                    Text("このMac内で処理します。自分の答えには自動で書き込みません。")
                }.formStyle(.grouped).tabItem { Label("端末内AI", systemImage: "sparkles") }.tag(2)
                Form {
                    Text("保持期間: 7 / 30 / 90 / 365日")
                    Text("テーマの記録は自動削除しません。")
                }.formStyle(.grouped).tabItem { Label("保存", systemImage: "externaldrive") }.tag(3)
                Form {
                    Text("j / k　次 / 前の記事\ns　Star\nt　テーマ\nb / v　原文を開く\nEsc　戻る")
                }.formStyle(.grouped).tabItem { Label("ショートカット", systemImage: "keyboard") }.tag(4)
            }.padding(12).frame(width: 640, height: 480)
            .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        }
    }
    func editor(_ root: NSView) -> NSTextView? {
        if let v = root as? NSTextView, v.isEditable { return v }
        return root.subviews.lazy.compactMap(editor).first
    }
    func settle(_ host: NSView) async throws {
        for _ in 0..<15 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(20)) }
    }
    @Test func fiveCategoriesAndEditorUpdate() async throws {
        let suite = "feeeder.settings.probe.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = State()
        let host = NSHostingView(rootView: Preview(state: state, defaults: defaults))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 480), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        defer { window.close() }
        for category in [0, 1, 2, 3, 4] {
            state.category = category; try await settle(host)
            if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                host.cacheDisplay(in: host.bounds, to: bitmap)
                try bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "/private/tmp/feeeder-settings-probe-\(category).png"))
            }
        }
        state.category = 1; try await settle(host)
        let before = try #require(editor(host))
        window.makeFirstResponder(before)
        before.setSelectedRange(NSRange(location: 3, length: 2))
        let initialText = before.string
        for size in [20.0, 14, 18, 16] {
            state.noteSize = size; try await settle(host)
            let after = try #require(editor(host))
            #expect(after === before)
            #expect(after.string == initialText && state.text == initialText)
            #expect(after.selectedRange() == NSRange(location: 3, length: 2))
            #expect(after.font?.pointSize == CGFloat(size))
        }
        before.setMarkedText("にほんご", selectedRange: NSRange(location: 4, length: 0), replacementRange: before.selectedRange())
        #expect(before.hasMarkedText())
        try await settle(host)
        let markedBaseline = before.hasMarkedText()
        let markedString = before.string, markedRange = before.markedRange()
        state.noteSize = 20; try await settle(host)
        let after = try #require(editor(host))
        print("PROBE marked-text baseline after no-font update=\(markedBaseline), before=\(markedRange), after=\(after.markedRange()), sameText=\(after.string == markedString)")
        print("PROBE marked-text preserved=\(after.hasMarkedText() && after.markedRange() == markedRange && after.string == markedString)")
        // API-generated marked text is a diagnostic; it is not a real IME acceptance test.
        after.unmarkText()
        defaults.set("dark", forKey: "appearance"); defaults.set(false, forKey: "onDeviceSuggestions")
        try await settle(host)
        let recreated = Preview(state: State(), defaults: try #require(UserDefaults(suiteName: suite)))
        #expect(recreated.appearance == "dark" && recreated.enabled == false)
        print("PROBE preferences round-trip: dark, AI off; synthetic suite only")
    }
    @Test func typographyPreservesAttributesAndMeasuresAnchorLimit() throws {
        let view = ArticleTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let scroll = NSScrollView(frame: view.frame); scroll.documentView = view
        let paragraphs = (0..<40).map { "段落\($0)。" + String(repeating: "日本語とEnglishの合成文章を読みます。", count: 35) }
        let linkRange = (paragraphs[7] as NSString).range(of: "English")
        let blocks = paragraphs.enumerated().map { i, text in
            BodyParagraph(text: text, links: i == 7 ? [BodyLink(location: linkRange.location, length: linkRange.length, url: "https://synthetic.example/")] : [], quoteDepth: i == 7 ? 1 : 0)
        }
        view.install(title: "合成記事", publisher: "SYNTHETIC", date: "", coverage: "RSS要約", paragraphs: paragraphs, unavailable: nil, bodyParagraphs: blocks)
        let original = view.string
        let body = (original as NSString).range(of: paragraphs.joined(separator: "\n"))
        #expect(body.location != NSNotFound)
        let linked = (original as NSString).range(of: paragraphs[7]).location + linkRange.location
        let headerFont = view.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        var combinations = 0
        for viewport in [360.0, 600, 1000] {
            for size in [14.0, 16, 18, 20] {
                for spacing in [4.0, 8, 12] {
                    for maximum in [560.0, 670, 800] {
                        view.restore(anchor: "paragraph-7", offset: 23.5)
                        let anchor = view.readingPosition()
                        view.textStorage?.addAttribute(.font, value: NSFont.systemFont(ofSize: size), range: body)
                        view.textStorage?.enumerateAttribute(.paragraphStyle, in: body) { value, range, _ in
                            let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
                            style.lineSpacing = spacing; view.textStorage?.addAttribute(.paragraphStyle, value: style, range: range)
                        }
                        // Force existing layout/anchor cache refresh, then set the proposed maximum width.
                        view.setFrameSize(NSSize(width: viewport + 1, height: view.frame.height))
                        view.setFrameSize(NSSize(width: viewport, height: view.frame.height))
                        view.textContainer?.containerSize.width = max(1, min(maximum, viewport - 84))
                        view.restore(anchor: anchor.anchor, offset: anchor.offset)
                        #expect(view.string == original)
                        #expect(view.textStorage?.attribute(.link, at: linked, effectiveRange: nil) as? URL == URL(string: "https://synthetic.example/"))
                        #expect((view.textStorage?.attribute(.paragraphStyle, at: linked, effectiveRange: nil) as? NSParagraphStyle)?.headIndent == 20)
                        #expect(view.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont == headerFont)
                        combinations += 1
                    }
                }
            }
        }
        print("PROBE typography \(combinations) combinations: text/link/quote/header preserved; not a production settings integration")
        view.setFrameSize(NSSize(width: 360, height: view.frame.height))
        view.restore(anchor: "paragraph-7", offset: 600)
        let position = view.readingPosition()
        func topCharacter() -> Int {
            let manager = view.layoutManager!, container = view.textContainer!
            let rect = NSRect(x: 0, y: scroll.contentView.bounds.minY - view.textContainerOrigin.y, width: container.containerSize.width, height: 1)
            let glyphs = manager.glyphRange(forBoundingRect: rect, in: container)
            return manager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil).location
        }
        let beforeCharacter = topCharacter()
        view.setFrameSize(NSSize(width: 1000, height: view.frame.height))
        let resized = view.readingPosition()
        print("PROBE top visible UTF16 index before=\(beforeCharacter), after=\(topCharacter())")
        print("PROBE deep offset before=\(position.anchor)/\(position.offset), after=\(resized.anchor)/\(resized.offset)")
    }
    @Test func onDeviceAvailabilityOnly() {
        print("PROBE FoundationModels availability: \(SystemLanguageModel.default.availability)")
        if let embedding = NLContextualEmbedding(language: .japanese) {
            print("PROBE Japanese embedding assets present: \(embedding.hasAvailableAssets)")
        } else { print("PROBE Japanese embedding unavailable") }
        // No model inference, asset requests, external handoff or user library access.
    }
}
