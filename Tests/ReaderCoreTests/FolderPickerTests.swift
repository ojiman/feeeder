import Testing
@testable import ReaderCore

// Checks PRD-16 (specification 7).
@Suite(EnglishLanguage()) struct FolderPickerTests {
    private let folders = ["技術", "ニュース", "Tech", "趣味"]

    @Test func withNothingTypedTheCandidatesAreUnfiledAndTheOtherFolders() {
        let all = FolderPicker.entries(query: "", folders: folders, current: "")
        #expect(all == [.existing("Tech"), .existing("ニュース"), .existing("技術"), .existing("趣味")])   // no 「未分類」: it is already unfiled
        let inTech = FolderPicker.entries(query: "  ", folders: folders, current: "Tech")
        #expect(inTech.first == .unfiled && !inTech.contains(.existing("Tech")))                   // not the folder it is in; unfiled first
    }
    @Test func aUserFolderThatMatchesTheLocalizedUnfiledLabelKeepsItsIdentity() {
        #expect(FolderPicker.entries(query: "Unfiled", folders: ["Unfiled", "Mine"], current: "Mine") == [.existing("Unfiled")])
        #expect(FolderPicker.entries(query: "Unfiled", folders: ["Unfiled"], current: "Unfiled") == [])
    }

    @Test func typingNarrowsTheCandidatesAndOffersToCreateTheTypedName() {
        let narrowed = FolderPicker.entries(query: "tec", folders: folders, current: "")
        #expect(narrowed == [.existing("Tech"), .create("tec")])                                   // a match, then "make it"
        #expect(FolderPicker.entries(query: "Tech", folders: folders, current: "") == [.existing("Tech")])   // exactly an existing folder: nothing to create
        #expect(FolderPicker.entries(query: "新しい", folders: folders, current: "") == [.create("新しい")])
        #expect(FolderPicker.entries(query: "　新しい 名前 ", folders: folders, current: "") == [.create("新しい 名前")])   // trimmed like every folder name
    }
    @Test func unfiledCanBeTypedAndAFolderCannotBeNamedLikeIt() {
        #expect(FolderPicker.entries(query: "Unfi", folders: folders, current: "Tech").first == .unfiled)
        #expect(FolderPicker.entries(query: "Unfiled", folders: folders, current: "Tech") == [.unfiled])
        #expect(FolderPicker.entries(query: "Unfiled", folders: folders, current: "") == [])           // already unfiled: nothing to do
    }
    @Test func theFolderItIsInIsNeverACandidateAndNotCreatedAgain() {
        #expect(FolderPicker.entries(query: "Tech", folders: folders, current: "Tech") == [])
        #expect(FolderPicker.entries(query: "技", folders: folders, current: "技術") == [.create("技")])
    }
    @Test func aCandidateKnowsTheFolderItMovesTo() {
        #expect(FolderPicker.Entry.unfiled.folder == "" && FolderPicker.Entry.existing("Tech").folder == "Tech" && FolderPicker.Entry.create("新規").folder == "新規")
    }

    // MARK: Choosing at registration (the add sheet): nothing is highlighted until the person types or presses a key, so Return adds as unfiled

    @Test func nothingIsHighlightedUntilSomethingIsTyped() {
        let entries = FolderPicker.entries(query: "tec", folders: folders, current: "")
        #expect(FolderPicker.highlight(afterTyping: "", entries: FolderPicker.entries(query: "", folders: folders, current: "")) == nil)
        #expect(FolderPicker.highlight(afterTyping: "  ", entries: entries) == nil)
        #expect(FolderPicker.highlight(afterTyping: "tec", entries: entries) == 0)                  // the best match, so typing a name and pressing Return goes there
        #expect(FolderPicker.highlight(afterTyping: "tec", entries: []) == nil)
    }
    @Test func theArrowKeysMoveTheHighlightAndTheTopReturnsToUnfiledWhenNothingIsTyped() {
        func move(_ from: Int?, _ step: FolderPicker.Step, count: Int = 3, query: String = "") -> Int? {
            FolderPicker.highlight(from: from, step: step, count: count, query: query)
        }
        #expect(move(nil, .down) == 0 && move(0, .down) == 1 && move(2, .down) == 2)                 // stops at the last
        #expect(move(1, .up) == 0 && move(0, .up) == nil && move(nil, .up) == nil)                   // up from the first: back to "no folder"
        #expect(move(0, .up, query: "tec") == 0)                                                     // with a name typed there is always a target
        #expect(move(nil, .down, count: 0) == nil && move(1, .down, count: 0) == nil)
    }
    @Test func theDestinationIsTheHighlightedFolderOrUnfiled() {
        let entries = FolderPicker.entries(query: "tec", folders: folders, current: "")
        #expect(FolderPicker.destination(highlighted: nil, in: entries) == "")
        #expect(FolderPicker.destination(highlighted: 0, in: entries) == "Tech")
        #expect(FolderPicker.destination(highlighted: 1, in: entries) == "tec")                      // "make it"
        #expect(FolderPicker.destination(highlighted: 9, in: entries) == "")                         // a stale index never picks a wrong folder
    }
}
