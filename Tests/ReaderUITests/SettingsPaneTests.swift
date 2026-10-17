import Testing
@testable import UnagiReader

// Checks the remembered Settings pane in specification 3.7.
struct SettingsPaneTests {
    @Test(arguments: ["general", "articles", "shortcuts"])
    func currentPaneIsRestored(_ stored: String) {
        #expect(ReaderSettingsView.Pane.stored(stored).rawValue == stored)
    }

    @Test(arguments: ["appearance", "language", "storage", "", nil, "unknown"] as [String?])
    func oldOrMissingPaneOpensGeneral(_ stored: String?) {
        #expect(ReaderSettingsView.Pane.stored(stored) == .general)
    }
}
