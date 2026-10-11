import Testing
@testable import ReaderCore

struct FolderPickerTests {
    private let folders = ["技術", "ニュース", "Tech", "趣味"]

    @Test func withNothingTypedTheCandidatesAreUnfiledAndTheOtherFolders() {
        let all = FolderPicker.entries(query: "", folders: folders, current: "")
        #expect(all == [.existing("Tech"), .existing("ニュース"), .existing("技術"), .existing("趣味")])   // no 「未分類」: it is already unfiled
        let inTech = FolderPicker.entries(query: "  ", folders: folders, current: "Tech")
        #expect(inTech.first == .unfiled && !inTech.contains(.existing("Tech")))                   // not the folder it is in; unfiled first
    }
    @Test func typingNarrowsTheCandidatesAndOffersToCreateTheTypedName() {
        let narrowed = FolderPicker.entries(query: "tec", folders: folders, current: "")
        #expect(narrowed == [.existing("Tech"), .create("tec")])                                   // a match, then "make it"
        #expect(FolderPicker.entries(query: "Tech", folders: folders, current: "") == [.existing("Tech")])   // exactly an existing folder: nothing to create
        #expect(FolderPicker.entries(query: "新しい", folders: folders, current: "") == [.create("新しい")])
        #expect(FolderPicker.entries(query: "　新しい 名前 ", folders: folders, current: "") == [.create("新しい 名前")])   // trimmed like every folder name
    }
    @Test func unfiledCanBeTypedAndAFolderCannotBeNamedLikeIt() {
        #expect(FolderPicker.entries(query: "未分", folders: folders, current: "Tech").first == .unfiled)
        #expect(FolderPicker.entries(query: "未分類", folders: folders, current: "Tech") == [.unfiled])
        #expect(FolderPicker.entries(query: "未分類", folders: folders, current: "") == [])           // already unfiled: nothing to do
    }
    @Test func theFolderItIsInIsNeverACandidateAndNotCreatedAgain() {
        #expect(FolderPicker.entries(query: "Tech", folders: folders, current: "Tech") == [])
        #expect(FolderPicker.entries(query: "技", folders: folders, current: "技術") == [.create("技")])
    }
    @Test func aCandidateKnowsTheFolderItMovesTo() {
        #expect(FolderPicker.Entry.unfiled.folder == "" && FolderPicker.Entry.existing("Tech").folder == "Tech" && FolderPicker.Entry.create("新規").folder == "新規")
    }
}
