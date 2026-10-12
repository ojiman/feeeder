import Foundation
import SwiftData
import Testing
@testable import ReaderCore

/// Reading subscriptions from an OPML file (decision 0039).
@MainActor struct OPMLImportTests {
    private func parse(_ opml: String) throws -> OPMLDocument { try OPMLParser.parse(Data(opml.utf8)) }
    private func wrap(_ body: String) -> String { #"<?xml version="1.0"?><opml version="2.0"><head><title>Subscriptions</title></head><body>\#(body)</body></opml>"# }

    // MARK: The parser

    @Test func feedsFoldersAndNamesAreRead() throws {
        let document = try parse(wrap("""
        <outline type="rss" text="Alone" xmlUrl="https://alone.example/feed" htmlUrl="https://alone.example/"/>
        <outline text="Tech"><outline type="rss" text="Text name" title="Title name" xmlUrl="https://tech.example/rss"/>
        <outline type="rss" text="Atom one" xmlUrl="https://tech.example/atom"/></outline>
        """))
        #expect(document.feeds.map(\.url.absoluteString) == ["https://alone.example/feed", "https://tech.example/rss", "https://tech.example/atom"])
        #expect(document.feeds.map(\.folder) == ["", "Tech", "Tech"])
        #expect(document.feeds.map(\.title) == ["Alone", "Title name", "Atom one"])                   // title first, then text
        #expect(document.feeds[0].siteURL?.absoluteString == "https://alone.example/" && document.feeds[1].siteURL == nil)
        #expect(document.skipped == 0)
    }
    @Test func deeperFoldersAreFlattenedToTheTopOneAndSpecialNamesMeanUnfiled() throws {
        let document = try parse(wrap("""
        <outline text="News"><outline text="World"><outline text="Deep"><outline type="rss" text="A" xmlUrl="https://a.example/f"/></outline></outline></outline>
        <outline text="未分類"><outline text="B" xmlUrl="https://b.example/f"/></outline>
        <outline text="  "><outline text="C" xmlUrl="https://c.example/f"/></outline>
        <outline text="Multi
        line"><outline text="D" xmlUrl="https://d.example/f"/></outline>
        """))
        #expect(document.feeds.map(\.folder) == ["News", "", "", "Multi line"])                       // one level of folders, as in the app
    }
    @Test func anOutlineWithoutAFeedAddressIsOnlyAFolderAndBadAddressesAreCounted() throws {
        let document = try parse(wrap("""
        <outline text="Empty folder"/>
        <outline text="x" xmlUrl="ftp://old.example/feed"/><outline text="y" xmlUrl="https://u:p@host.example/f"/><outline text="z" xmlUrl=""/>
        <outline text="Good" xmlUrl="https://good.example/f"/>
        """))
        #expect(document.feeds.map(\.title) == ["Good"] && document.skipped == 3)
    }
    @Test func theSameAddressTwiceIsOneFeedAndTheAttributeNameIsReadWhateverItsCase() throws {
        let document = try parse(wrap("""
        <outline text="One" xmlUrl="https://same.example/f"/>
        <outline text="Folder"><outline text="Two" XMLURL="https://same.example/f"/><outline text="Three" xmlurl="https://other.example/f"/></outline>
        """))
        #expect(document.feeds.map(\.title) == ["One", "Three"] && document.skipped == 0 && document.repeated == 1)
    }
    @Test func aNameFallsBackToTheHost() throws {
        #expect(try parse(wrap(#"<outline xmlUrl="https://nameless.example/f"/>"#)).feeds.first?.title == "nameless.example")
    }
    @Test func aDoctypeIsFineButEntitiesAndOtherDocumentsAreRefused() throws {
        #expect(try parse(#"<?xml version="1.0"?><!DOCTYPE opml><opml version="1.0"><body><outline text="A" xmlUrl="https://a.example/f"/></body></opml>"#).feeds.count == 1)
        #expect(throws: OPMLError.entities) { try parse(#"<!DOCTYPE opml [<!ENTITY x "y">]><opml><body><outline text="&x;" xmlUrl="https://a.example/f"/></body></opml>"#) }
        #expect(throws: OPMLError.notOPML) { try parse("<rss><channel><title>feed</title></channel></rss>") }
        #expect(throws: OPMLError.invalidXML) { try parse("<opml><body><outline") }
        #expect(throws: OPMLError.notOPML) { try parse("") }
    }
    @Test func hugeFilesAndTooManyFeedsAreRefused() throws {
        #expect(throws: OPMLError.tooLarge) { try OPMLParser.parse(Data(repeating: 32, count: 5 * 1024 * 1024 + 1)) }
        let many = (0...OPMLParser.maximumFeeds).map { #"<outline text="f\#($0)" xmlUrl="https://h\#($0).example/f"/>"# }.joined()
        #expect(throws: OPMLError.tooMany) { try parse(wrap(many)) }
    }
    @Test func anEmptyBodyIsNotAnError() throws {
        let document = try parse(wrap(""))
        #expect(document.feeds.isEmpty && document.skipped == 0)
    }

    // MARK: The store

    private func feed(_ title: String, _ url: String, folder: String = "", site: String? = nil) -> OPMLFeed {
        OPMLFeed(title: title, url: URL(string: url)!, siteURL: site.flatMap { URL(string: $0) }, folder: folder)
    }

    @Test func importedSubscriptionsAppearAtOnceWithTheirFoldersAndSurviveReopening() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        let result = try store.importSubscriptions([feed("A", "https://a.example/f", folder: " 技術 ", site: "https://a.example/"), feed("B", "https://b.example/f")])
        #expect(result.addedFeedIDs.count == 2 && result.alreadySubscribed == 0)
        #expect(store.feeds.map(\.title).sorted() == ["A", "B"])
        let a = try #require(store.feeds.first { $0.title == "A" })
        #expect(a.folder == "技術" && a.sourceURL == "https://a.example/f" && a.siteURL == "https://a.example/" && !a.customTitle)
        let reopened = try ReaderStore(url: library.url)
        #expect(reopened.feeds.count == 2 && reopened.feed(id: a.id)?.folder == "技術")
    }
    @Test func aSubscriptionThatExistsIsNeitherDuplicatedNorMoved() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        let parsed = try FeedParser.parse(Data(FeedParserTests.rss.utf8), sourceURL: URL(string: "https://Old.example/f")!)
        let existing = try store.importFeed(parsed, folder: "Mine")
        let result = try store.importSubscriptions([feed("Old", "https://old.example/f", folder: "Theirs"), feed("New", "https://new.example/f")])
        #expect(result.addedFeedIDs.count == 1 && result.alreadySubscribed == 1)
        #expect(store.feeds.count == 2 && existing.folder == "Mine")                                   // the host's case does not make a second subscription
    }
    @Test func aFailedSaveAddsNothingAndSaysSo() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "opml-" + UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }
        let schema = ReaderStore.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration("Reader", schema: schema, url: url.appending(path: "Reader.store"), cloudKitDatabase: .none)])
        var failSave = false
        let store = try ReaderStore(container: container, now: .now, saveHook: { if failSave { throw CocoaError(.fileWriteUnknown) } })
        failSave = true
        #expect(throws: (any Error).self) { try store.importSubscriptions([feed("A", "https://a.example/f")]) }
        #expect(store.feeds.isEmpty)                                                                  // nothing half-added
        failSave = false
        #expect(try store.importSubscriptions([feed("A", "https://a.example/f")]).addedFeedIDs.count == 1)
    }
    @Test func importingNothingChangesNothing() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        let result = try store.importSubscriptions([])
        #expect(result.addedFeedIDs.isEmpty && result.alreadySubscribed == 0 && store.feeds.isEmpty)
    }

    // MARK: The importer (the file, the store and the words for the person)

    private func file(_ opml: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "opml-test-" + UUID().uuidString + ".opml")
        try Data(opml.utf8).write(to: url)
        return url
    }

    @Test func aFileBecomesSubscriptionsAndAPlainReport() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        let url = try file(wrap("""
        <outline text="Tech"><outline text="A" xmlUrl="https://a.example/f"/><outline text="B" xmlUrl="https://b.example/f"/></outline>
        <outline text="Bad" xmlUrl="ftp://c.example/f"/><outline text="A again" xmlUrl="https://a.example/f"/>
        """))
        defer { try? FileManager.default.removeItem(at: url) }
        let report = await OPMLImporter(store: store).importFile(at: url)
        #expect(report.title == "OPMLを取り込みました" && report.addedFeedIDs.count == 2)
        #expect(report.message == "2件の購読を追加しました。\n取り込まなかったもの：すでに購読している1件、読めないアドレス1件。\n記事は、これから順に届きます。")
        #expect(store.feeds.count == 2 && Set(store.feeds.map(\.folder)) == ["Tech"])
    }
    @Test func theReportSaysWhatHappenedWhenNothingWasAdded() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        let body = wrap(#"<outline text="A" xmlUrl="https://a.example/f"/>"#)
        let first = try file(body), empty = try file(wrap(""))
        defer { try? FileManager.default.removeItem(at: first); try? FileManager.default.removeItem(at: empty) }
        _ = await OPMLImporter(store: store).importFile(at: first)
        let again = await OPMLImporter(store: store).importFile(at: first)
        #expect(again.addedFeedIDs.isEmpty && again.message == "新しい購読はありませんでした。\n取り込まなかったもの：すでに購読している1件。")
        let none = await OPMLImporter(store: store).importFile(at: empty)
        #expect(none.addedFeedIDs.isEmpty && none.message == "このファイルに購読は見つかりませんでした。")
    }
    @Test func aFileThatCannotBeUsedGivesAReasonAndChangesNothing() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        let importer = OPMLImporter(store: store)
        let rss = try file("<rss><channel><title>x</title></channel></rss>")
        defer { try? FileManager.default.removeItem(at: rss) }
        let notOPML = await importer.importFile(at: rss)
        #expect(notOPML.title == "OPMLを取り込めませんでした" && notOPML.message == "OPMLファイルではありません。" && notOPML.addedFeedIDs.isEmpty)
        let missing = await importer.importFile(at: FileManager.default.temporaryDirectory.appending(path: "no-such-" + UUID().uuidString + ".opml"))
        #expect(missing.title == "OPMLを取り込めませんでした" && !missing.message.isEmpty)
        let huge = FileManager.default.temporaryDirectory.appending(path: "opml-huge-" + UUID().uuidString + ".opml")
        try Data(repeating: 32, count: OPMLParser.maximumBytes + 1).write(to: huge)
        defer { try? FileManager.default.removeItem(at: huge) }
        #expect(await importer.importFile(at: huge).message == "ファイルが大きすぎます（5MBまで）。")
        #expect(store.feeds.isEmpty)
    }

    // MARK: The whole flow (choose, import, report, then fetch the new subscriptions)

    private func flow(_ store: ReaderStore, urls: [URL], choose: @escaping @MainActor () async -> URL?) -> OPMLImportFlow {
        let client = FeedClient(http: HTTPClient(protocolClasses: [StubURLProtocol.self]))
        for url in urls { StubURLProtocol.register(.init(data: Data(FeedParserTests.rss.utf8)), at: url) }
        return OPMLImportFlow(store: store, refresh: FeedRefreshController(store: store, client: client), chooseFile: choose)
    }

    @Test func choosingAFileAddsTheSubscriptionsThenFetchesTheirArticles() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        let address = "https://\(UUID().uuidString.lowercased()).example/feed"
        let opml = try file(wrap(#"<outline text="Tech"><outline text="A" xmlUrl="\#(address)"/></outline>"#))
        defer { try? FileManager.default.removeItem(at: opml) }
        let flow = flow(store, urls: [URL(string: address)!], choose: { opml })
        await flow.start()
        #expect(flow.report?.message.hasPrefix("1件の購読を追加しました。") == true)
        let added = try #require(store.feeds.first)
        #expect(added.folder == "Tech" && added.lastFetchedAt != nil && !store.articles.isEmpty)       // the articles came, so the person is not left with empty rows
        flow.dismissReport()
        #expect(flow.report == nil)
    }
    @Test func cancellingTheFilePanelDoesNothing() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        let flow = flow(store, urls: [], choose: { nil })
        await flow.start()
        #expect(flow.report == nil && store.feeds.isEmpty && !flow.choosing)
    }
    @Test func aSecondRequestWhileThePanelIsOpenIsIgnored() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        let gate = SlowGate()
        let asked = Recorder<Int>()
        let flow = flow(store, urls: [], choose: { asked.add(1); await gate.wait(); return nil })
        let first = Task { await flow.start() }
        while !flow.choosing { await Task.yield() }
        await flow.start()                                                                           // returns at once
        #expect(asked.values.count == 1)
        await gate.open(); await first.value
        #expect(!flow.choosing)
    }
}
