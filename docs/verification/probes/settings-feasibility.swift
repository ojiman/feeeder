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
        init(state: State, defaults: UserDefaults) {
            self.state = state; self.defaults = defaults
            _appearance = AppStorage(wrappedValue: "system", "appearance", store: defaults)
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
                    Text("本文の文字組みと、ノートの文字サイズを設定します。")
                }.formStyle(.grouped).tabItem { Label("読書・編集", systemImage: "textformat.size") }.tag(1)
                Form {
                    Text("端末内AIの無効化は機能実装との接続が必要です。")
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
    func window(_ content: NSView, width: CGFloat = 640) -> NSWindow {
        let result = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 480), styleMask: [.titled], backing: .buffered, defer: false)
        result.isReleasedWhenClosed = false; result.contentView = content
        return result
    }
    struct Note: View {
        let state: State
        var body: some View {
            @Bindable var state = state
            TextEditor(text: $state.text).font(.system(size: state.noteSize))
                .frame(width: 640, height: 480).accessibilityLabel("合成ノート")
        }
    }
    @Test func fiveCategoryContentsRender() async throws {
        let suite = "feeeder.settings.probe.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = State()
        let host = NSHostingView(rootView: Preview(state: state, defaults: defaults))
        let w = window(host); defer { w.close() }
        let output = try #require(ProcessInfo.processInfo.environment["FEEEDER_SETTINGS_PROBE_OUTPUT"])
        try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
        for category in 0..<5 {
            state.category = category; try await settle(host)
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let data = try #require(bitmap.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: output).appendingPathComponent("category-\(category).png"))
        }
        print("PROBE five category contents rendered; navigation and Settings scene not exercised")
    }
    @Test func editorUpdateAndMarkedTextControls() async throws {
        let state = State()
        let host = NSHostingView(rootView: Note(state: state))
        let w = window(host); defer { w.close() }
        try await settle(host)
        let text = try #require(editor(host))
        #expect(w.makeFirstResponder(text))
        text.setSelectedRange(NSRange(location: 3, length: 2))
        let initial = text.string
        for size in [20.0, 14, 18, 16] {
            state.noteSize = size; try await settle(host)
            #expect(editor(host) === text && text.string == initial && state.text == initial)
            #expect(text.selectedRange() == NSRange(location: 3, length: 2))
            #expect(text.font?.pointSize == CGFloat(size))
        }
        // A native control separates font mutation from SwiftUI/Binding reconciliation.
        let native = NSTextView(frame: NSRect(x: 0, y: 0, width: 640, height: 480))
        native.string = initial
        native.setMarkedText("にほんご", selectedRange: NSRange(location: 4, length: 0), replacementRange: NSRange(location: 3, length: 2))
        let nativeMarked = native.markedRange(), nativeString = native.string
        native.font = .systemFont(ofSize: 20)
        print("PROBE native font-only marked preserved=\(native.markedRange() == nativeMarked && native.string == nativeString)")
        #expect(native.hasMarkedText() && native.markedRange() == nativeMarked && native.string == nativeString)
        for notifyBinding in [false, true] {
            state.text = initial; state.noteSize = 16; try await settle(host)
            text.setMarkedText("にほんご", selectedRange: NSRange(location: 4, length: 0), replacementRange: NSRange(location: 3, length: 2))
            if notifyBinding { text.didChangeText() }
            try await settle(host)
            let matches = state.text == text.string, marked = text.markedRange(), composed = text.string
            state.noteSize = 20; try await settle(host)
            print("PROBE SwiftUI notifyBinding=\(notifyBinding), bindingMatchesBefore=\(matches), markedBefore=\(marked), markedAfter=\(text.markedRange()), textPreserved=\(text.string == composed)")
            if notifyBinding {
                #expect(matches && text.markedRange() == marked && text.string == composed)
            }
            text.unmarkText()
        }
        let settingsHost = NSHostingView(rootView: Text("合成Settings・別ウィンドウ"))
        let settingsWindow = window(settingsHost); defer { settingsWindow.close() }
        state.text = initial; state.noteSize = 16; try await settle(host)
        text.setMarkedText("にほんご", selectedRange: NSRange(location: 4, length: 0), replacementRange: NSRange(location: 3, length: 2))
        text.didChangeText(); try await settle(host)
        let beforeText = text.string
        let resigned = w.makeFirstResponder(nil)
        #expect(settingsWindow.makeFirstResponder(settingsHost))
        state.noteSize = 20; try await settle(host)
        print("PROBE separate-window responder resignation=\(resigned), markedAfter=\(text.hasMarkedText()), textPreserved=\(text.string == beforeText)")
        #expect(resigned && text.string == beforeText)
        // This does not simulate an actual input method or actual key-window switching.
    }
    @Test func parameterizedProductionInstallAndWidth() throws {
        let view = ArticleTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 480))
        let scroll = NSScrollView(frame: view.frame); scroll.documentView = view
        let w = window(scroll); defer { w.close() }
        let paragraphs = (0..<40).map { "段落\($0)。" + String(repeating: "日本語とEnglishの合成文章を読みます。", count: 35) }
        let linkRange = (paragraphs[7] as NSString).range(of: "English")
        let blocks = paragraphs.enumerated().map { i, text in
            BodyParagraph(text: text, links: i == 7 ? [BodyLink(location: linkRange.location, length: linkRange.length, url: "https://synthetic.example/")] : [], quoteDepth: i == 7 ? 1 : 0)
        }
        var count = 0
        for viewport in [CGFloat(360), 600, 1000] {
            for size in [CGFloat(14), 16, 18, 20] {
                for spacing in [CGFloat(4), 8, 12] {
                    for maximum in [CGFloat(560), 670, 800] {
                        scroll.setFrameSize(NSSize(width: viewport, height: 480))
                        view.setFrameSize(NSSize(width: scroll.contentSize.width, height: view.frame.height))
                        view.install(title: "合成記事", publisher: "SYNTHETIC", date: "", coverage: "RSS要約", paragraphs: paragraphs, unavailable: nil, bodyParagraphs: blocks,
                                     bodyFontSize: size, bodyLineSpacing: spacing, maximumBodyWidth: maximum)
                        let storage = try #require(view.textStorage), container = try #require(view.textContainer)
                        let expectedWidth = min(maximum, view.frame.width - 84)
                        #expect(abs(container.containerSize.width - expectedWidth) < 0.01)
                        #expect(abs(view.textContainerInset.width - max(42, (view.frame.width - expectedWidth) / 2)) < 0.01)
                        for (i, paragraph) in paragraphs.enumerated() {
                            let range = (view.string as NSString).range(of: paragraph)
                            #expect(range.location != NSNotFound)
                            let font = try #require(storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont)
                            let style = try #require(storage.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle)
                            #expect(font.pointSize == size && style.lineSpacing == spacing)
                            #expect(style.headIndent == (i == 7 ? 20 : 0))
                        }
                        let linked = (view.string as NSString).range(of: paragraphs[7]).location + linkRange.location
                        #expect(storage.attribute(.link, at: linked, effectiveRange: nil) as? URL == URL(string: "https://synthetic.example/"))
                        var opened: URL?
                        view.onOpenLink = { opened = $0; return true }
                        _ = view.textView(view, clickedOnLink: "https://synthetic.example/", at: linked)
                        #expect(opened?.absoluteString == "https://synthetic.example/")
                        #expect((storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize == 11)
                        // Resize after install: the production setFrameSize must retain this cap, too.
                        view.setFrameSize(NSSize(width: 1050, height: view.frame.height))
                        #expect(container.containerSize.width == maximum)
                        #expect(view.textContainerInset.width == (1050 - maximum) / 2)
                        count += 1
                    }
                }
            }
        }
        print("PROBE parameterized production install/setFrameSize: \(count) combinations")
    }
    @Test func windowBackedReadingPosition() throws {
        let view = ArticleTextView(frame: NSRect(x: 0, y: 0, width: 360, height: 480))
        let scroll = NSScrollView(frame: view.frame); scroll.documentView = view
        let w = window(scroll, width: 360); defer { w.close() }
        let paragraphs = (0..<40).map { "段落\($0)。" + String(repeating: "日本語とEnglishの合成文章を読みます。", count: 35) }
        view.install(title: "合成記事", publisher: "SYNTHETIC", date: "", coverage: "RSS要約", paragraphs: paragraphs, unavailable: nil)
        let manager = try #require(view.layoutManager), container = try #require(view.textContainer)
        let range = (view.string as NSString).range(of: paragraphs[7])
        func paragraphRect() -> NSRect {
            manager.ensureLayout(for: container)
            return manager.boundingRect(forGlyphRange: manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil), in: container)
                .offsetBy(dx: view.textContainerOrigin.x, dy: view.textContainerOrigin.y)
        }
        func topCharacter() -> Int {
            manager.ensureLayout(for: container)
            let rect = NSRect(x: 0, y: scroll.contentView.bounds.minY - view.textContainerOrigin.y, width: container.containerSize.width, height: 1)
            return manager.characterRange(forGlyphRange: manager.glyphRange(forBoundingRect: rect, in: container), actualGlyphRange: nil).location
        }
        view.restore(anchor: "paragraph-7", offset: 80)
        let before = view.readingPosition(), beforeRect = paragraphRect(), first = topCharacter()
        #expect(before.anchor == "paragraph-7" && before.offset == 80)
        #expect(beforeRect.height > 80 && first >= range.location && first < NSMaxRange(range))
        scroll.setFrameSize(NSSize(width: 1000, height: 480))
        view.setFrameSize(NSSize(width: scroll.contentSize.width, height: view.frame.height))
        let after = view.readingPosition(), afterRect = paragraphRect(), second = topCharacter()
        #expect(after.anchor == "paragraph-7" && abs(after.offset - 80) < 0.01)
        #expect(afterRect.height > 80 && second >= range.location && second < NSMaxRange(range))
        #expect(first != second)
        print("PROBE mounted scroll: viewport=\(scroll.contentSize), paragraph UTF16 length=\(range.length), heights=\(beforeRect.height)->\(afterRect.height), anchor=\(before.anchor)/\(before.offset)->\(after.anchor)/\(after.offset), topUTF16=\(first)->\(second)")
    }
    @Test func onDeviceAvailabilityOnly() {
        print("PROBE FoundationModels availability: \(SystemLanguageModel.default.availability)")
        if let embedding = NLContextualEmbedding(language: .japanese) {
            print("PROBE Japanese embedding assets present: \(embedding.hasAvailableAssets)")
        }
    }
}
