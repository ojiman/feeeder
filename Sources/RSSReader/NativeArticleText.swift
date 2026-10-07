import AppKit
import SwiftUI
import QuartzCore
import ReaderCore

// A single native text layout replaces per-paragraph SwiftUI geometry/preferences.
@MainActor final class ArticleTextView: NSTextView {
    private var paragraphRanges: [NSRange] = []
    private var paragraphYs: [CGFloat] = []
    private var bodyRange: NSRange?
    private var heroRange: NSRange?
    private var heroView: NSView?
    private var installing = false
    var onDisplayBegin: (() -> Void)?
    var onDisplayed: (() -> Void)?
    var onInteraction: (() -> Void)?
    var onScroll: ((String, Double) -> Void)?
    private var didDisplayBody = false

    override init(frame: NSRect) {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(containerSize: NSSize(width: max(1, frame.width - 84), height: .greatestFiniteMagnitude))
        storage.addLayoutManager(layout); layout.addTextContainer(container)
        super.init(frame: frame, textContainer: container)
        container.widthTracksTextView = false; container.lineFragmentPadding = 0
        isEditable = false; isSelectable = true; isRichText = true
        isVerticallyResizable = true; isHorizontallyResizable = false
        minSize = NSSize(width: 0, height: 0); maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        autoresizingMask = [.width]
        drawsBackground = true; backgroundColor = .textBackgroundColor
        textContainerInset = NSSize(width: 42, height: 44)
        setAccessibilityLabel("記事本文")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configureHero(_ view: NSView?) {
        if heroView !== view { heroView?.removeFromSuperview(); heroView = view; if let view { addSubview(view) } }
        positionHero()
    }
    func install(title: String, publisher: String, date: String, coverage: String, paragraphs: [String], unavailable: String?, hero: Bool = false) {
        if !paragraphs.isEmpty { onDisplayBegin?() }
        installing = true; defer { installing = false }
        let document = NSMutableAttributedString()
        func append(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, secondary: Bool = false, spacing: CGFloat = 22) {
            let style = NSMutableParagraphStyle(); style.lineSpacing = size == 16 ? 8 : 5; style.paragraphSpacing = spacing
            document.append(NSAttributedString(string: text + "\n", attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: secondary ? NSColor.secondaryLabelColor : NSColor.labelColor, .paragraphStyle: style]))
        }
        append(publisher + "    " + coverage, size: 11, weight: .medium, secondary: true)
        append(title, size: 30, weight: .bold)
        append(date, size: 12, secondary: true)
        heroRange = nil
        if hero {
            heroRange = NSRange(location: document.length, length: 1)
            let style = NSMutableParagraphStyle(); style.minimumLineHeight = 180; style.maximumLineHeight = 180; style.paragraphSpacing = 22
            document.append(NSAttributedString(string: " \n", attributes: [.font: NSFont.systemFont(ofSize: 1), .foregroundColor: NSColor.clear, .paragraphStyle: style]))
        }
        paragraphRanges = []; paragraphYs = []; bodyRange = nil
        let start = document.length
        for paragraph in paragraphs {
            paragraphRanges.append(NSRange(location: document.length, length: (paragraph as NSString).length))
            append(paragraph, size: 16)
        }
        if !paragraphs.isEmpty { bodyRange = NSRange(location: start, length: document.length - start) }
        if let unavailable { append(unavailable, size: 16, secondary: true) }
        append(coverage, size: 11, secondary: true, spacing: 0)
        textStorage?.setAttributedString(document)
        didDisplayBody = false
        layoutDocument()
        needsDisplay = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        let widthChanged = abs(newSize.width - frame.width) > 0.5
        let previous = widthChanged && !installing && !paragraphRanges.isEmpty ? readingPosition() : nil
        super.setFrameSize(newSize)
        if widthChanged {
            let width = max(1, min(670, newSize.width - 84))
            textContainer?.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
            textContainerInset = NSSize(width: max(42, (newSize.width - width) / 2), height: 44)
            paragraphYs = []
            layoutDocument()
            if let previous { restore(anchor: previous.anchor, offset: previous.offset) }
        }
    }

    private func layoutDocument() {
        guard let manager = layoutManager, let container = textContainer else { return }
        manager.ensureLayout(for: container)
        let height = max(enclosingScrollView?.contentSize.height ?? 0, manager.usedRect(for: container).maxY + 88)
        if abs(frame.height - height) > 0.5 { super.setFrameSize(NSSize(width: frame.width, height: height)) }
        positionHero()
    }
    private func positionHero() {
        guard let heroView, let heroRange, let manager = layoutManager, let container = textContainer else { self.heroView?.isHidden = true; return }
        let glyphs = manager.glyphRange(forCharacterRange: heroRange, actualCharacterRange: nil)
        let rect = manager.lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: nil)
        heroView.isHidden = false
        heroView.frame = NSRect(x: textContainerOrigin.x, y: textContainerOrigin.y + rect.minY, width: container.containerSize.width, height: 180)
    }
    private func paragraphPositions() -> [CGFloat] {
        if paragraphYs.count == paragraphRanges.count { return paragraphYs }
        guard let manager = layoutManager, let container = textContainer else { return [] }
        paragraphYs = paragraphRanges.map { range in
            let first = NSRange(location: range.location, length: min(1, range.length))
            let glyph = manager.glyphRange(forCharacterRange: first, actualCharacterRange: nil)
            return manager.boundingRect(forGlyphRange: glyph, in: container).minY + textContainerOrigin.y
        }
        return paragraphYs
    }
    func readingPosition() -> (anchor: String, offset: Double) {
        let y = enclosingScrollView?.contentView.bounds.minY ?? 0
        let positions = paragraphPositions()
        // Sorted paragraph positions keep scroll bookkeeping off the SwiftUI update graph.
        var lower = 0, upper = positions.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if positions[middle] <= y { lower = middle + 1 } else { upper = middle }
        }
        guard lower > 0 else { return ("top", Double(max(0, y))) }
        return ("paragraph-\(lower - 1)", Double(max(0, y - positions[lower - 1])))
    }
    func restore(anchor: String?, offset: Double) {
        layoutDocument()
        let positions = paragraphPositions()
        let index = anchor.flatMap { Int($0.replacingOccurrences(of: "paragraph-", with: "")) }
        let base = index.flatMap { positions.indices.contains($0) ? positions[$0] : nil } ?? 0
        guard let scroll = enclosingScrollView else { return }
        let target = min(max(0, frame.height - scroll.contentSize.height), max(0, base + offset))
        scroll.contentView.scroll(to: NSPoint(x: 0, y: target)); scroll.reflectScrolledClipView(scroll.contentView)
    }
    var hasVisibleBody: Bool {
        guard let bodyRange, let manager = layoutManager, let container = textContainer else { return false }
        let visible = visibleRect.offsetBy(dx: -textContainerOrigin.x, dy: -textContainerOrigin.y)
        let glyphs = manager.glyphRange(forBoundingRect: visible, in: container)
        let characters = manager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        return NSIntersectionRange(bodyRange, characters).length > 0
    }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !didDisplayBody, window != nil, hasVisibleBody else { return }
        didDisplayBody = true
        // SwiftUI state/storage writes happen after the native draw, never inside its update.
        let callback = onDisplayed
        DispatchQueue.main.async { callback?() }
    }
    override func mouseDown(with event: NSEvent) { onInteraction?(); super.mouseDown(with: event) }
    func recordScroll() {
        guard !installing else { return }
        let position = readingPosition(); onScroll?(position.anchor, position.offset)
    }
}

struct NativeArticleText: NSViewRepresentable {
    let articleID: UUID
    let title: String
    let publisher: String
    let date: String
    let coverage: String
    let paragraphs: [String]
    let unavailable: String?
    let initialAnchor: String?
    let initialOffset: Double
    let reduceMotion: Bool
    let onScroll: (String, Double) -> Void
    let onInteraction: () -> Void
    let onDisplayBegin: () -> Void
    let onDisplayed: () -> Void
    var imageLoader: ReaderImageLoader? = nil
    var heroURL: URL? = nil

    @MainActor final class Coordinator {
        var signature: [String] = []
        nonisolated(unsafe) var observer: NSObjectProtocol?
        var restoring = false
        var hero: NSHostingView<ArticleImageView>?
        deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        // The reader proposes a viewport; document height must never size the split pane.
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: 600, height: 400))
    }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = ArticleScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = true; scroll.backgroundColor = .textBackgroundColor
        let text = ArticleTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        scroll.documentView = text
        scroll.contentView.postsBoundsChangedNotifications = true
        let coordinator = context.coordinator
        coordinator.observer = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scroll.contentView, queue: .main) { [weak text, weak coordinator] _ in
            MainActor.assumeIsolated { if coordinator?.restoring == false { text?.recordScroll() } }
        }
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let text = scroll.documentView as? ArticleTextView else { return }
        let signature = [articleID.uuidString, title, publisher, date, coverage, unavailable ?? "", heroURL?.absoluteString ?? ""] + paragraphs
        let changed = signature != context.coordinator.signature
        if changed { text.recordScroll() }
        text.onScroll = onScroll; text.onInteraction = onInteraction; text.onDisplayBegin = onDisplayBegin; text.onDisplayed = onDisplayed
        (scroll as? ArticleScrollView)?.onInteraction = onInteraction
        if let imageLoader, let heroURL {
            let image = ArticleImageView(loader: imageLoader, articleID: articleID, url: heroURL, size: CGSize(width: 0, height: 180))
            if let hero = context.coordinator.hero { if changed { hero.rootView = image } }
            else {
                let hero = NSHostingView(rootView: image)
                // ArticleTextView owns the fixed frame; intrinsic-size constraints
                // must not resize the surrounding text layout when an image arrives.
                hero.sizingOptions = []
                context.coordinator.hero = hero
            }
            text.configureHero(context.coordinator.hero)
        } else { text.configureHero(nil); context.coordinator.hero = nil }
        guard changed else { return }
        context.coordinator.restoring = true
        context.coordinator.signature = signature
        text.install(title: title, publisher: publisher, date: date, coverage: coverage, paragraphs: paragraphs, unavailable: unavailable, hero: heroURL != nil)
        text.restore(anchor: initialAnchor, offset: initialOffset)
        context.coordinator.restoring = false
        scroll.wantsLayer = true
        scroll.layer?.removeAllAnimations()
        if !reduceMotion {
            let fade = CABasicAnimation(keyPath: "opacity"); fade.fromValue = 0.5; fade.toValue = 1; fade.duration = 0.18
            let move = CABasicAnimation(keyPath: "transform.translation.y"); move.fromValue = -12; move.toValue = 0; move.duration = 0.18
            scroll.layer?.add(fade, forKey: "article-fade"); scroll.layer?.add(move, forKey: "article-move")
        }
    }
    static func dismantleNSView(_ scroll: NSScrollView, coordinator: Coordinator) {
        (scroll.documentView as? ArticleTextView)?.recordScroll()
        if let observer = coordinator.observer { NotificationCenter.default.removeObserver(observer); coordinator.observer = nil }
    }
}

private final class ArticleScrollView: NSScrollView {
    var onInteraction: (() -> Void)?
    override func scrollWheel(with event: NSEvent) { onInteraction?(); super.scrollWheel(with: event) }
}
