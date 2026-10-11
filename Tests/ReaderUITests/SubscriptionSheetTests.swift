import AppKit
import SwiftUI
import Testing
@testable import UnagiReader

@MainActor struct SubscriptionSheetTests {
    @Test func theFolderFieldListsTheFoldersAndAcceptsTypedNames() throws {
        var folder = ""
        let field = FolderComboBox(text: Binding(get: { folder }, set: { folder = $0 }), folders: ["Tech", "ニュース"], prompt: "フォルダ")
        let coordinator = field.makeCoordinator()
        let box = field.makeBox(coordinator: coordinator)
        #expect((0..<box.numberOfItems).map { box.itemObjectValue(at: $0) as? String } == ["Tech", "ニュース"])
        #expect(box.placeholderString == "フォルダ" && box.completes)
        box.stringValue = "新しい名前"                                                            // typing a new name makes a new folder
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: box))
        #expect(folder == "新しい名前")
        box.selectItem(at: 1)                                                                   // choosing an existing one
        coordinator.comboBoxSelectionDidChange(Notification(name: NSComboBox.selectionDidChangeNotification, object: box))
        #expect(folder == "ニュース")
        folder = ""                                                                             // the sheet clears it from outside
        field.apply(to: box)
        #expect(box.stringValue == "")
    }
    @Test func theXMLInputIsOnlyOfferedWithTheOptionKey() {
        #expect(!SubscriptionSheet.offersXMLInput(modifiers: []))
        #expect(!SubscriptionSheet.offersXMLInput(modifiers: [.command, .shift]))
        #expect(SubscriptionSheet.offersXMLInput(modifiers: [.option]))
    }
}
