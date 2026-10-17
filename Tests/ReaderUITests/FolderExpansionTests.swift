import Foundation
import Testing
@testable import UnagiReader

struct FolderExpansionTests {
    @Test func aFolderThatReceivesASubscriptionIsOpenedAndRenamingKeepsItsState() {
        let name = "unagi-reader-test-\(UUID().uuidString)"
        let store = UserDefaults(suiteName: name)!; defer { store.removePersistentDomain(forName: name) }
        var expansion = FolderExpansion(defaults: store)
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

/// The open folders are kept across launches (specification 3.1.4, PRD-11): a second `FolderExpansion` on the same defaults is the next launch.
struct FolderExpansionMemoryTests {
    private func defaults() -> (UserDefaults, String) {
        let name = "unagi-reader-test-\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    @Test func foldersLeftOpenAreOpenAfterARestartAndClosedOnesStayClosed() {
        let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
        var expansion = FolderExpansion(defaults: store)
        #expect(!expansion.isExpanded("Tech"))                                                 // the first launch: all closed, as before
        expansion.set("Tech", expanded: true)
        expansion.set("ニュース", expanded: true)
        expansion.set("Tech", expanded: false)
        expansion.reveal("Blogs")                                                              // a folder that received a subscription
        let relaunched = FolderExpansion(defaults: store)
        #expect(relaunched.isExpanded("ニュース") && relaunched.isExpanded("Blogs") && !relaunched.isExpanded("Tech"))
    }

    @Test func aRenamedFolderKeepsItsStateAfterARestart() {
        let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
        var expansion = FolderExpansion(defaults: store)
        expansion.set("ニュース", expanded: true)
        expansion.rename(from: "ニュース", to: "News")
        let relaunched = FolderExpansion(defaults: store)
        #expect(relaunched.isExpanded("News") && !relaunched.isExpanded("ニュース"))
    }

    @Test func aFolderThatDisappearedIsForgotten() {
        let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
        var expansion = FolderExpansion(defaults: store)
        expansion.set("Tech", expanded: true)
        expansion.set("News", expanded: true)
        expansion.forget(["Tech"])                                                             // its last subscription left
        let relaunched = FolderExpansion(defaults: store)
        #expect(relaunched.isExpanded("News") && !relaunched.isExpanded("Tech"))               // a new folder of the same name starts closed
    }

    @Test func anUnreadableValueMeansAllClosed() {
        let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
        store.set("Tech", forKey: FolderExpansion.key)                                          // not a list of names
        #expect(!FolderExpansion(defaults: store).isExpanded("Tech"))
        store.set([1, 2], forKey: FolderExpansion.key)
        #expect(!FolderExpansion(defaults: store).isExpanded("1"))
    }
}
