import SwiftUI

struct SidebarTitlebarControls: NSViewRepresentable {
    var refreshing: Bool
    var onAdd: () -> Void
    var onRefresh: () -> Void

    func makeNSView(context: Context) -> Anchor { Anchor() }
    func updateNSView(_ view: Anchor, context: Context) {
        view.host.rootView = Buttons(refreshing: refreshing, onAdd: onAdd, onRefresh: onRefresh)
    }
    static func dismantleNSView(_ view: Anchor, coordinator: ()) { view.detach() }

    final class Anchor: NSView {
        let accessory = NSTitlebarAccessoryViewController()
        let host = NSHostingView(rootView: Buttons(refreshing: false, onAdd: {}, onRefresh: {}))
        private weak var installedWindow: NSWindow?

        init() {
            super.init(frame: .zero)
            host.sizingOptions = []
            host.frame.size = NSSize(width: 100, height: 40)
            accessory.view = host
            accessory.layoutAttribute = .left
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window !== installedWindow else { return }
            detach()
            if let window {
                installedWindow = window
                window.addTitlebarAccessoryViewController(accessory)
                needsLayout = true
            }
        }
        override func layout() {
            super.layout()
            guard window != nil else { return }
            // SwiftUI's navigation toolbar is placed after the sidebar separator.
            let right = convert(bounds, to: nil).maxX
            let left = host.convert(host.bounds, to: nil).minX
            host.setFrameSize(NSSize(width: max(0, right - left), height: host.frame.height))
            host.isHidden = bounds.width < 80
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
                    .help("URLから購読を追加").accessibilityLabel("購読を追加")
                Button(action: onRefresh) {
                    Group {
                        if refreshing { ProgressView().controlSize(.small) }
                        else { Image(systemName: "arrow.clockwise") }
                    }.frame(width: 28, height: 28)
                }.disabled(refreshing).help("購読を更新").accessibilityLabel("購読を更新")
            }.buttonStyle(.borderless)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing).padding(.trailing, 12)
        }
    }
}
