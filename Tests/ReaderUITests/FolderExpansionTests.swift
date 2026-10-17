import Testing
@testable import UnagiReader

@Suite(EnglishLanguage()) struct FolderExpansionTests {
    @Test func aFolderThatReceivesASubscriptionIsOpenedAndRenamingKeepsItsState() {
        var expansion = FolderExpansion()
        #expect(!expansion.isExpanded("Tech"))                                                  // folders start closed, as before
        expansion.reveal("Tech")
        #expect(expansion.isExpanded("Tech"))
        expansion.reveal("")                                                                    // "unfiled" has no folder row: nothing to open
        #expect(!expansion.isExpanded(""))
        expansion.set("Tech", expanded: false)
        #expect(!expansion.isExpanded("Tech"))
        expansion.set("ニュース", expanded: true)
        expansion.rename(from: "ニュース", to: "News")
        #expect(expansion.isExpanded("News") && !expansion.isExpanded("ニュース"))
        expansion.rename(from: "Tech", to: "News")                                              // merging into an open folder: stays open
        #expect(expansion.isExpanded("News"))
    }
}
