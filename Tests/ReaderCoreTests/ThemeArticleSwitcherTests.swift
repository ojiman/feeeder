import Foundation
import Testing
@testable import ReaderCore

@MainActor struct ThemeArticleSwitcherTests {
    let at = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func entriesFollowTheListOrderAndMarkTheCurrentArticle() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let ids = store.articles.map(\.id)
        let theme = try store.createTheme(name: "T", at: at)
        try store.addArticle(ids[2], toTheme: theme.id, at: at); try store.addArticle(ids[0], toTheme: theme.id, at: at)
        let entries = store.themeArticleEntries(themeID: theme.id, selection: ids[2])
        #expect(entries.map(\.id) == [ids[0], ids[2]] && entries.map(\.isCurrent) == [false, true] && entries.allSatisfy(\.inTheme))
        #expect(entries[0].title == store.article(id: ids[0])?.title)
        #expect(store.themeArticleEntries(themeID: theme.id, selection: nil).allSatisfy { !$0.isCurrent })
    }

    @Test func aShownArticleThatLeftTheThemeStaysListedAndIsMarked() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let ids = store.articles.map(\.id)
        let theme = try store.createTheme(name: "T", at: at)
        try store.addArticle(ids[0], toTheme: theme.id, at: at); try store.addArticle(ids[1], toTheme: theme.id, at: at)
        try store.removeArticle(ids[1], fromTheme: theme.id, at: at)
        let entries = store.themeArticleEntries(themeID: theme.id, selection: ids[1])
        #expect(Set(entries.map(\.id)) == [ids[0], ids[1]])
        #expect(entries.first { $0.id == ids[1] }.map { $0.isCurrent && !$0.inTheme } == true)
        #expect(entries.first { $0.id == ids[0] }.map { $0.inTheme && !$0.isCurrent } == true)
    }

    @Test func anEmptyThemeHasNoEntries() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let theme = try store.createTheme(name: "Empty", at: at)
        #expect(store.themeArticleEntries(themeID: theme.id, selection: nil).isEmpty)
        #expect(!ThemeArticleSwitcher.canMove(1, from: nil, in: []) && !ThemeArticleSwitcher.canMove(-1, from: nil, in: []))
    }

    @Test func theEndsAreDisabledAndNothingShownOpensTheFirst() {
        let ids = [UUID(), UUID(), UUID()]
        #expect(!ThemeArticleSwitcher.canMove(-1, from: ids[0], in: ids) && ThemeArticleSwitcher.canMove(1, from: ids[0], in: ids))
        #expect(ThemeArticleSwitcher.canMove(-1, from: ids[1], in: ids) && ThemeArticleSwitcher.canMove(1, from: ids[1], in: ids))
        #expect(ThemeArticleSwitcher.canMove(-1, from: ids[2], in: ids) && !ThemeArticleSwitcher.canMove(1, from: ids[2], in: ids))
        #expect(ThemeArticleSwitcher.canMove(1, from: nil, in: ids) && ThemeArticleSwitcher.canMove(-1, from: UUID(), in: ids))
        #expect(ReaderNavigation.move(nil, by: 1, in: ids) == ids[0])
    }
}
