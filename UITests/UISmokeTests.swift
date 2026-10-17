import XCTest
import Carbon

@MainActor final class UISmokeTests: XCTestCase {
    private var app: XCUIApplication!
    private var directory: URL!
    private var inputSource: TISInputSource?

    override func setUp() async throws {
        try await MainActor.run {
            continueAfterFailure = false
            let path = try XCTUnwrap(ProcessInfo.processInfo.environment["UNAGI_UI_SMOKE_APP"])
            let url = URL(fileURLWithPath: path)
            XCTAssertEqual(Bundle(url: url)?.bundleIdentifier, "xyz.ojima.UnagiReader.Synthetic.UISmoke", "Refusing app at: \(path)")
            directory = FileManager.default.temporaryDirectory.appending(path: "unagi-ui-smoke-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            app = XCUIApplication(url: url)
            app.launchArguments = ["--data-directory", directory.path, "--seed-demo"]
            app.launch()
            app.activate()
            inputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
            let ascii = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeRetainedValue()
            XCTAssertEqual(TISSelectInputSource(ascii), noErr)
            XCTAssertTrue(app.tables["記事一覧"].waitForExistence(timeout: 15), app.windows.debugDescription)
            XCTAssertTrue(app.outlines.staticTexts["開発ノート"].exists)
        }
    }

    override func tearDown() async throws {
        try await MainActor.run {
            if let inputSource { XCTAssertEqual(TISSelectInputSource(inputSource), noErr) }
            app?.terminate()
            if let directory { try FileManager.default.removeItem(at: directory) }
        }
    }

    // Checks PRD-01: a real click and j/k must select and display the corresponding article.
    func testLaunchSelectionAndReadingKeys() {
        let table = app.tables["記事一覧"]
        XCTAssertEqual(table.tableRows.count, 6)
        // Native cell accessibility clicks can select without giving the table the keyboard.
        table.tableRows.element(boundBy: 1).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        let body = app.textViews["記事本文"]
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        waitForValue(body, containing: "毎日届く情報")
        let ascii = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeRetainedValue()
        XCTAssertEqual(TISSelectInputSource(ascii), noErr)
        table.typeText("j")
        waitForValue(body, containing: "朝の空気")
        table.typeText("k")
        waitForValue(body, containing: "毎日届く情報")
    }

    // Checks PRD-04 and decision 0050: the panel's own close button and Esc close the note.
    func testNoteCloseButtonAndEscape() {
        selectFirst()
        app.windows.firstMatch.typeKey("n", modifierFlags: [])
        let editor = app.textViews["ノート"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        app.groups["ノート"].buttons["ノートを閉じる"].click()
        XCTAssertTrue(editor.waitForNonExistence(timeout: 5))
        app.windows.firstMatch.typeKey("n", modifierFlags: [])
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.click()
        app.windows.firstMatch.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(editor.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.tables["記事一覧"].tableRows.firstMatch.isHittable)
    }

    // Checks PRD-04: layout changes keep the note, and committed typing survives a restart.
    func testNoteLayoutKeepsEditing() {
        selectFirst()
        app.windows.firstMatch.typeKey("n", modifierFlags: [])
        let editor = app.textViews["ノート"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.click()
        for key in ["j", "k", "n"] { editor.typeText(key) }
        app.buttons["記事の一覧を出す"].click()
        XCTAssertTrue(app.buttons["記事の一覧を隠す"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tables["記事一覧"].tableRows.firstMatch.isHittable)
        XCTAssertEqual(editor.value as? String, "jkn")
        app.buttons["記事の一覧を隠す"].click()
        XCTAssertTrue(app.buttons["記事の一覧を出す"].waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, "jkn")
        app.terminate()
        app.launch()
        let ascii = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeRetainedValue()
        XCTAssertEqual(TISSelectInputSource(ascii), noErr)
        selectFirst()
        app.windows.firstMatch.typeKey("n", modifierFlags: [])
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, "jkn")
    }

    // Checks PRD-14 and PRD-03: normal URL input fetches a loopback feed; v/Esc opens/closes its local page.
    func testLocalFeedAndOriginalPage() throws {
        try addLocalFeed()
        selectFirst()
        let body = app.textViews["記事本文"]
        waitForValue(body, containing: "Smoke local article body.")
        app.windows.firstMatch.typeKey("v", modifierFlags: [])
        XCTAssertTrue(app.buttons["記事に戻る"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.webViews.staticTexts["Smoke original page"].waitForExistence(timeout: 10))
        app.windows.firstMatch.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(app.buttons["記事に戻る"].waitForNonExistence(timeout: 5))
        waitForValue(body, containing: "Smoke local article body.")
        XCTAssertTrue(app.outlines.staticTexts["Smoke local feed"].exists)
    }

    // Checks PRD-16 and PRD-15 with real events. 「名前を変更」 from the context menu puts the keyboard in the name field at once
    // (decision 0043): the person types without clicking it. Several renames, from an unselected and a selected row, because the
    // focus was lost only sometimes (#265).
    func testRenameAndOPMLMenu() {
        var current = "開発ノート"
        for round in 1...4 {
            let row = app.outlines.staticTexts[current]
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            if round > 2 { row.click() }                                       // rounds 3 and 4: the subscription is selected first
            row.rightClick()
            app.menuItems["名前を変更"].click()
            let name = app.textFields["名前"]
            XCTAssertTrue(name.waitForExistence(timeout: 5))
            let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: name)
            XCTAssertEqual(XCTWaiter.wait(for: [focused], timeout: 5), .completed, "round \(round): the name field has no keyboard focus")
            let renamed = "Smoke renamed \(round)"
            app.typeText(renamed)                                              // the whole old name is selected, so typing replaces it
            app.typeKey(.return, modifierFlags: [])
            XCTAssertTrue(app.outlines.staticTexts[renamed].waitForExistence(timeout: 5), "round \(round)")
            XCTAssertFalse(app.outlines.staticTexts[current].exists)
            current = renamed
        }
        let englishFile = app.menuBars.menuBarItems["File"]
        let file = englishFile.exists ? englishFile : app.menuBars.menuBarItems["ファイル"]
        file.click()
        XCTAssertTrue(app.menuItems["OPMLを取り込む…"].exists)
        XCTAssertTrue(app.menuItems["OPMLを取り込む…"].isEnabled)
        app.windows.firstMatch.typeKey(.escape, modifierFlags: [])
    }

    private func selectFirst() {
        let table = app.tables["記事一覧"]
        XCTAssertTrue(table.waitForExistence(timeout: 5))
        table.tableRows.element(boundBy: 0).click()
        app.textViews["記事本文"].click()
    }

    private func waitForValue(_ element: XCUIElement, containing text: String) {
        let predicate = NSPredicate(format: "value CONTAINS %@", text)
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 5) == .completed, "Expected \(text), got: \(String(describing: element.value))")
    }

    private func addLocalFeed() throws {
        let address = try XCTUnwrap(ProcessInfo.processInfo.environment["UNAGI_UI_SMOKE_FEED"])
        XCTAssertTrue(address.hasPrefix("http://127.0.0.1:"))
        app.buttons["購読を追加"].click()
        let field = app.textFields["フィードのURL"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeText(address)
        let add = app.buttons["追加"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: add)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        add.click()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.outlines.staticTexts["Smoke local feed"].waitForExistence(timeout: 5))
    }
}
