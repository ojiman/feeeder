import SwiftUI
import ReaderCore

struct SidebarTitlebarControls: NSViewRepresentable {
    var refreshing: Bool
    var visible: Bool
    var onAdd: () -> Void
    var onRefresh: () -> Void

    func makeNSView(context: Context) -> Anchor { Anchor() }
    func updateNSView(_ view: Anchor, context: Context) {
        view.host.rootView = Buttons(refreshing: refreshing, onAdd: onAdd, onRefresh: onRefresh)
        view.sidebarVisible = visible
    }
    static func dismantleNSView(_ view: Anchor, coordinator: ()) { view.detach(); view.stopObserving() }

    final class Anchor: NSView {
        let accessory = NSTitlebarAccessoryViewController()
        let host = NSHostingView(rootView: Buttons(refreshing: false, onAdd: {}, onRefresh: {}))
        private weak var installedWindow: NSWindow?
        var sidebarVisible = true { didSet { updateAttachment() } }

        init() {
            super.init(frame: .zero)
            host.sizingOptions = []
            host.frame.size = NSSize(width: 100, height: 40)
            accessory.view = host
            accessory.layoutAttribute = .left
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        /// What tells the buttons' width to be worked out again. The width comes from where this view is in the window. While the sidebar
        /// slides in or out, the views above this one are still on their way, so a width worked out at the first frame can be 0 and
        /// nothing here changes afterwards (the buttons stayed invisible next to a sidebar that was there). The split view says when its
        /// panes have a new size, also at the end of the move.
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            updateAttachment()
            observeSizeChanges()
        }

        private func observeSizeChanges() {
            stopObserving()
            guard window != nil else { return }
            var view: NSView? = superview
            while let current = view {
                if let split = current as? NSSplitView {
                    observers.append(NotificationCenter.default.addObserver(forName: NSSplitView.didResizeSubviewsNotification, object: split, queue: .main) { [weak self] _ in
                        MainActor.assumeIsolated { self?.placeButtonsSoon() }
                    })
                }
                view = current.superview
            }
        }
        private func updateAttachment() {
            let target = sidebarVisible ? window : nil
            guard target !== installedWindow else { return }
            detach()
            if let window = target {
                installedWindow = window
                window.addTitlebarAccessoryViewController(accessory)
                needsLayout = true
                // The sidebar may still be sliding in. Work the width out once more when the move has ended, in case no resize
                // notification came with the last frame.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                    MainActor.assumeIsolated { self?.placeButtons() }
                }
            }
        }
        override func layout() {
            super.layout()
            placeButtons()
        }

        private func placeButtons() {
            guard installedWindow != nil else { return }
            // SwiftUI's navigation toolbar is placed after the sidebar separator.
            let right = convert(bounds, to: nil).maxX
            let left = host.convert(host.bounds, to: nil).minX
            // Only a real change is written: a write inside a layout pass makes another pass, and the window gave up on a loop of them.
            let width = max(0, right - left)
            if abs(host.frame.width - width) > 0.5 { host.setFrameSize(NSSize(width: width, height: host.frame.height)) }
            let hidden = bounds.width < 80
            if host.isHidden != hidden { host.isHidden = hidden }
        }

        /// Works the width out a moment later, not inside the layout pass that told us. Several notices in one pass make one call.
        private var placePending = false
        private func placeButtonsSoon() {
            guard !placePending else { return }
            placePending = true
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated {
                    self?.placePending = false
                    self?.placeButtons()
                }
            }
        }
        func stopObserving() {
            for observer in observers { NotificationCenter.default.removeObserver(observer) }
            observers = []
        }
        func detach() {
            if let window = installedWindow, let index = window.titlebarAccessoryViewControllers.firstIndex(where: { $0 === accessory }) {
                window.removeTitlebarAccessoryViewController(at: index)
            }
            installedWindow = nil
        }
    }

    struct Buttons: View {
        var refreshing: Bool
        var onAdd: () -> Void
        var onRefresh: () -> Void
        var body: some View {
            HStack(spacing: 8) {
                Button(action: onAdd) { Image(systemName: "plus").frame(width: 28, height: 28) }
                    .help(String(localized: "Add Subscription from URL", bundle: ReaderLocalization.bundle)).accessibilityLabel(String(localized: "Add Subscription", bundle: ReaderLocalization.bundle))
                // The arrow itself turns while the feeds are being updated (the system stops the motion for Reduce Motion).
                // The button is not disabled: pressing it again while it works does nothing (FeedRefreshController.refresh).
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .symbolEffect(.rotate, isActive: refreshing)
                        .frame(width: 28, height: 28)
                }.help(String(localized: "Refresh Subscriptions", bundle: ReaderLocalization.bundle)).accessibilityLabel(String(localized: "Refresh Subscriptions", bundle: ReaderLocalization.bundle)).accessibilityValue(refreshing ? String(localized: "Refreshing", bundle: ReaderLocalization.bundle) : "")
            }.buttonStyle(.borderless)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing).padding(.trailing, 12)
        }
    }
}
