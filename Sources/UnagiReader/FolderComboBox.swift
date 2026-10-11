import SwiftUI
import AppKit

/// One field for the folder of a subscription: type a new name, or open the list and choose an existing one. This is what a combo box is
/// for (Apple's guidelines: use a combo box when the person can pick from a list or enter their own value). An empty field means 「未分類」.
struct FolderComboBox: NSViewRepresentable {
    @Binding var text: String
    let folders: [String]
    let prompt: String

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeBox(coordinator: Coordinator) -> NSComboBox {
        let box = NSComboBox()
        box.completes = true
        box.numberOfVisibleItems = 8
        box.usesSingleLineMode = true
        box.lineBreakMode = .byTruncatingTail
        box.delegate = coordinator
        box.setAccessibilityLabel("フォルダ")
        apply(to: box)
        return box
    }
    func apply(to box: NSComboBox) {
        box.placeholderString = prompt
        if box.objectValues.map({ $0 as? String }) != folders.map(Optional.some) {
            box.removeAllItems(); box.addItems(withObjectValues: folders)
        }
        if box.stringValue != text { box.stringValue = text }
    }

    func makeNSView(context: Context) -> NSComboBox { makeBox(coordinator: context.coordinator) }
    func updateNSView(_ box: NSComboBox, context: Context) { context.coordinator.text = $text; apply(to: box) }

    @MainActor final class Coordinator: NSObject, NSComboBoxDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func controlTextDidChange(_ notification: Notification) {
            guard let box = notification.object as? NSComboBox else { return }
            text.wrappedValue = box.stringValue.replacingOccurrences(of: "\n", with: " ")
        }
        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let box = notification.object as? NSComboBox, box.indexOfSelectedItem >= 0,
                  let chosen = box.objectValueOfSelectedItem as? String else { return }
            text.wrappedValue = chosen
        }
    }
}
