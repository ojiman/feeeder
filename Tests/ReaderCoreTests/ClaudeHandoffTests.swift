import Foundation
import Testing
@testable import ReaderCore

@MainActor private final class ProbeLauncher: ClaudeLaunching {
    var urls: [URL] = []
    var fail = false
    func open(_ url: URL) async throws { urls.append(url); if fail { throw AIPackageError.invalid } }
}

@MainActor struct ClaudeHandoffTests {
    @Test func savedSourcesAndOldMetadataReconcile() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let at = Date.now
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let id = store.articles[0].id
        let theme = try store.createTheme(name: "A", at: at)
        let link = try store.addArticle(id, toTheme: theme.id, at: at)
        let review = AIPackageReview(store: store, now: { at })
        let root = library.directory.appending(path: "handoff")
        try review.build(articleIDs: [id], language: "日本語", at: at)
        let oldFile = try HandoffFiles.write(try #require(review.package), directory: root)
        let metadataFile = oldFile.deletingLastPathComponent().appending(path: "metadata.json")
        var metadata = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: metadataFile)) as? [String: Any])
        metadata.removeValue(forKey: "selections")
        try JSONSerialization.data(withJSONObject: metadata).write(to: metadataFile)
        try review.build(selections: [.themeArticle(link.key)], language: "日本語", at: at)
        let savedFile = try HandoffFiles.write(try #require(review.package), directory: root)
        try store.deleteContent(articleIDs: [id], at: at)
        let inputs = try HandoffFiles.sourceSelections(directory: root)
        #expect(Set(inputs) == [.article(id), .themeArticle(link.key)])
        try HandoffFiles.reconcile(directory: root, validInputExpiries: store.availableInputExpiries(selections: inputs, at: at), at: at)
        #expect(!FileManager.default.fileExists(atPath: oldFile.path))
        #expect(FileManager.default.fileExists(atPath: savedFile.path))
        let data = try Data(contentsOf: savedFile)
        #expect(AIPackageBuilder.hash(data) == review.package?.sha256)
        try HandoffFiles.cleanup(directory: root, at: at.addingTimeInterval(86_400))
        #expect(!FileManager.default.fileExists(atPath: savedFile.path))
    }
    @Test func legacyScrapMetadataIsDeletedInsteadOfFailingEveryMaintenance() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let at = Date.now
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let id = store.articles[0].id
        let review = AIPackageReview(store: store, now: { at })
        let root = library.directory.appending(path: "handoff")
        try review.build(articleIDs: [id], language: "日本語", at: at)
        let file = try HandoffFiles.write(try #require(review.package), directory: root)
        let metadataFile = file.deletingLastPathComponent().appending(path: "metadata.json")
        // A copy written by beta.3 from a daily/weekly note used the removed `scrap` / `noteSource` selections.
        var metadata = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: metadataFile)) as? [String: Any])
        metadata["selections"] = [["scrap": ["_0": "legacy-note:legacy-article"]], ["noteSource": ["_0": "legacy-note:other"]]]
        try JSONSerialization.data(withJSONObject: metadata).write(to: metadataFile)
        let inputs = try HandoffFiles.sourceSelections(directory: root)
        #expect(inputs == [.unresolvable])   // the set collapses both legacy entries
        try HandoffFiles.reconcile(directory: root, validInputExpiries: store.availableInputExpiries(selections: inputs, at: at), at: at)
        #expect(!FileManager.default.fileExists(atPath: file.deletingLastPathComponent().path))
        try HandoffFiles.cleanup(directory: root, at: at.addingTimeInterval(10 * 86_400))
    }
    @Test func interruptedWriteDoesNotBlockExpiredCopiesAndRecoversOwnedFiles() throws {
        let (library, store, review, package, root) = try fixture(); defer { library.cleanup() }
        let expired = try HandoffFiles.write(package, directory: root)
        let orphan = root.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: orphan, withIntermediateDirectories: false)
        try Data("合成の中断コピー".utf8).write(to: orphan.appending(path: "Feeeder-review.txt"))
        let launcher = ProbeLauncher()
        let controller = ClaudeHandoffController(directory: root, review: review, launcher: launcher)
        controller.reconcile(with: store, at: package.expiresAt)
        #expect(!FileManager.default.fileExists(atPath: expired.path))
        #expect(!FileManager.default.fileExists(atPath: orphan.path))
        #expect(controller.maintenanceError == nil && controller.nextExpiry == nil)
    }
    @Test func unsafeFolderDoesNotBlockOtherCleanupAndIsNeverDeleted() throws {
        let (library, store, review, package, root) = try fixture(); defer { library.cleanup() }
        let expired = try HandoffFiles.write(package, directory: root)
        let unknown = root.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: unknown, withIntermediateDirectories: false)
        let unrelated = unknown.appending(path: "keep.txt")
        try Data("保持する合成ファイル".utf8).write(to: unrelated)
        let controller = ClaudeHandoffController(directory: root, review: review, launcher: ProbeLauncher())
        controller.reconcile(with: store, at: package.expiresAt)
        #expect(!FileManager.default.fileExists(atPath: expired.path))
        #expect(try String(contentsOf: unrelated, encoding: .utf8) == "保持する合成ファイル")
        #expect(controller.maintenanceError != nil)
        #expect(try HandoffFiles.sourceSelections(directory: root).isEmpty)
    }
    @Test func japanesePathAndPromptRoundTripWithoutBodyInURL() throws {
        let file = URL(fileURLWithPath: "/private/tmp/日本語 空白/合成.txt")
        let prompt = "添付を読んでください。送信は本人が操作します。"
        let url = try ClaudeLink.make(prompt: prompt, file: file)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(url.scheme == "claude" && url.host == "cowork" && url.path == "/new")
        #expect(components.queryItems?.first { $0.name == "q" }?.value == prompt)
        #expect(components.queryItems?.first { $0.name == "file" }?.value == file.path)
    }
    func fixture() throws -> (TestLibrary, ReaderStore, AIPackageReview, AIPackage, URL) {
        let library = try TestLibrary(), now = Date.now
        let store = try ReaderStore(url: library.url, seedDemo: true, now: now)
        let review = AIPackageReview(store: store, now: { now })
        try review.build(articleIDs: [try #require(store.articles.first).id], language: "日本語", at: now)
        return (library, store, review, try #require(review.package), library.directory.appending(path: "管理 日本語 空白"))
    }
    @Test func invalidPackageNeverLaunchesClaude() async throws {
        for kind in ["missing", "directory", "unreadable", "modified", "symlink"] {
            let (library, _, review, package, root) = try fixture(); defer { library.cleanup() }
            let file = try HandoffFiles.write(package, directory: root)
            switch kind {
            case "missing": try FileManager.default.removeItem(at: file)
            case "directory": try FileManager.default.removeItem(at: file); try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
            case "unreadable": try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)
            case "modified": try Data("tampered".utf8).write(to: file)
            case "symlink": try FileManager.default.removeItem(at: file); try FileManager.default.createSymbolicLink(at: file, withDestinationURL: library.url)
            default: break
            }
            let launcher = ProbeLauncher()
            let controller = ClaudeHandoffController(directory: root, review: review, launcher: launcher)
            await controller.open(package: package)
            #expect(launcher.urls.isEmpty && controller.error != nil && !controller.opened)
        }
        let (library, _, review, package, root) = try fixture(); defer { library.cleanup() }
        let launcher = ProbeLauncher()
        let controller = ClaudeHandoffController(directory: root, review: review, launcher: launcher, now: { package.expiresAt })
        await controller.open(package: package)
        #expect(launcher.urls.isEmpty)
    }
    @Test func launchFailureAndRetryKeepReviewedBytesUntilExpiry() async throws {
        let (library, _, review, package, root) = try fixture(); defer { library.cleanup() }
        let launcher = ProbeLauncher(); launcher.fail = true
        let controller = ClaudeHandoffController(directory: root, review: review, launcher: launcher)
        await controller.open(package: package)
        #expect(controller.error != nil && !controller.opened)
        let file = try #require(controller.file)
        let original = try Data(contentsOf: file)
        #expect(AIPackageBuilder.hash(original) == package.sha256)
        launcher.fail = false
        await controller.open(package: package)
        #expect(controller.opened && launcher.urls.count == 2 && controller.file == file)
        #expect(try Data(contentsOf: file) == original)
        #expect(Set(try FileManager.default.contentsOfDirectory(atPath: file.deletingLastPathComponent().path)) == ["Feeeder-review.txt", "metadata.json"])
        let permissions = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber
        #expect(permissions?.intValue == 0o600)
        #expect((try FileManager.default.attributesOfItem(atPath: file.deletingLastPathComponent().path)[.posixPermissions] as? NSNumber)?.intValue == 0o700)
        try HandoffFiles.cleanup(directory: root, at: package.expiresAt.addingTimeInterval(-1))
        #expect(FileManager.default.fileExists(atPath: file.path))
        try HandoffFiles.cleanup(directory: root, at: package.expiresAt)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }
    @Test func generatedFilesInvalidateAfterDeletionWithoutChangingExports() throws {
        let (library, store, review, package, root) = try fixture(); defer { library.cleanup() }
        let file = try HandoffFiles.write(package, directory: root)
        let parts = try HandoffFiles.writeSplit(package, directory: root)
        let export = library.directory.appending(path: "本人の書き出し.txt")
        let bytes = Data(package.text.utf8); try bytes.write(to: export)
        try store.deleteContent(articleIDs: package.sources.map(\.articleID), at: .now)
        #expect(review.package == nil)
        let remaining = try store.availableInputExpiries(selections: package.sources.map(\.selection), at: .now)
        try HandoffFiles.reconcile(directory: root, validInputExpiries: remaining, at: .now)
        #expect(!FileManager.default.fileExists(atPath: file.path) && parts.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
        #expect(try Data(contentsOf: export) == bytes)
    }
    @Test func generatedLifetimeShortensAndNeverExtends() throws {
        let (library, _, _, package, root) = try fixture(); defer { library.cleanup() }
        let file = try HandoffFiles.write(package, directory: root)
        let early = Date.now.addingTimeInterval(60)
        try HandoffFiles.reconcile(directory: root, validInputExpiries: [package.sources[0].selection: early], at: .now)
        try HandoffFiles.reconcile(directory: root, validInputExpiries: [package.sources[0].selection: package.expiresAt], at: .now)
        try HandoffFiles.cleanup(directory: root, at: early)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }
    @Test func newReviewedPackageCanLaunchAfterAnOlderFileDisappears() async throws {
        let (library, _, review, old, root) = try fixture(); defer { library.cleanup() }
        let file = try HandoffFiles.write(old, directory: root)
        try FileManager.default.removeItem(at: file)
        try review.build(articleIDs: old.sources.map(\.articleID), language: "日本語", at: .now)
        let fresh = try #require(review.package)
        let launcher = ProbeLauncher()
        let controller = ClaudeHandoffController(directory: root, review: review, launcher: launcher)
        await controller.open(package: fresh)
        #expect(controller.opened && launcher.urls.count == 1)
        #expect(controller.nextExpiry == fresh.expiresAt)
    }
    @Test func missingGeneratedFileDoesNotBlockOtherExpiredCopiesCleanup() throws {
        let (library, _, review, old, root) = try fixture(); defer { library.cleanup() }
        let missing = try HandoffFiles.write(old, directory: root)
        try FileManager.default.removeItem(at: missing)
        try review.build(articleIDs: old.sources.map(\.articleID), language: "日本語", at: .now)
        let fresh = try #require(review.package)
        let present = try HandoffFiles.write(fresh, directory: root)
        try HandoffFiles.cleanup(directory: root, at: max(old.expiresAt, fresh.expiresAt))
        #expect(!FileManager.default.fileExists(atPath: present.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }
    @Test func symlinkedParentAndMetadataTraversalAreRejected() throws {
        let (library, _, _, package, root) = try fixture(); defer { library.cleanup() }
        let file = try HandoffFiles.write(package, directory: root)
        let alias = library.directory.appending(path: "alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: file.deletingLastPathComponent())
        #expect(throws: (any Error).self) { try HandoffFiles.validate(file: alias.appending(path: file.lastPathComponent), expectedHash: package.sha256, at: .now, expiresAt: package.expiresAt) }
        let metadata = file.deletingLastPathComponent().appending(path: "metadata.json")
        var object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: metadata)) as? [String: Any])
        object["files"] = [["name": "../../Reader.store", "sha256": package.sha256]]
        try JSONSerialization.data(withJSONObject: object).write(to: metadata)
        #expect(throws: (any Error).self) { try HandoffFiles.cleanup(directory: root, at: package.expiresAt) }
        #expect(FileManager.default.fileExists(atPath: library.url.path))
    }

    /// Store + theme with one question, a package that includes the theme's questions and answers, and a controller that is wired
    /// the way the app wires it (a store change calls the controller's reconcile).
    private func themeCopy(_ at: Date) throws -> (library: TestLibrary, store: ReaderStore, theme: Theme, link: ThemeArticle, question: ThemeQuestion, controller: ClaudeHandoffController, folder: URL, launcher: ProbeLauncher) {
        let library = try TestLibrary()
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = "Recorded synthetic summary"
        let theme = try store.createTheme(name: "Rates", at: at)
        let link = try store.addArticle(article.id, toTheme: theme.id, at: at)
        let question = try store.addQuestion(themeID: theme.id, lens: .assumption, text: "What does this assume?", at: at)
        try store.saveAnswer(questionID: question.id, answer: "My private answer", at: at)
        let review = AIPackageReview(store: store, now: { at })
        let launcher = ProbeLauncher()
        let root = library.directory.appending(path: "handoff")
        let controller = ClaudeHandoffController(directory: root, review: review, launcher: launcher, now: { at })
        store.onContentPolicyChanged = { [weak store, weak controller] in if let store { controller?.reconcile(with: store, at: at) } }
        try review.build(selections: [.themeArticle(link.key)], theme: AIThemeRequest(themeID: theme.id, includeQuestions: true, includeAnswers: true), language: "English", at: at)
        let package = try #require(review.package)
        let file = try HandoffFiles.write(package, directory: root)
        return (library, store, theme, link, question, controller, file.deletingLastPathComponent(), launcher)
    }

    @Test func aCopyWithAnswersIsRemovedWhenItsThemeAQuestionOrASourceIsDeleted() async throws {
        let at = Date.now
        for removal in 0..<3 {
            let (library, store, theme, link, question, controller, folder, _) = try themeCopy(at); defer { library.cleanup() }
            #expect(FileManager.default.fileExists(atPath: folder.path))
            controller.reconcile(with: store, at: at)
            #expect(FileManager.default.fileExists(atPath: folder.path))                  // nothing was removed yet
            switch removal {
            case 0: try store.deleteTheme(id: theme.id)
            case 1: try store.deleteQuestion(id: question.id, at: at)
            default: try store.removeArticle(link.articleID, fromTheme: theme.id, at: at)
            }
            #expect(!FileManager.default.fileExists(atPath: folder.path), "removal \(removal)")
            #expect(controller.maintenanceError == nil)
        }
    }

    @Test func editingAnAnswerOrRenamingTheThemeKeepsTheCopyUntilItExpires() throws {
        let at = Date.now
        let (library, store, theme, _, question, controller, folder, _) = try themeCopy(at); defer { library.cleanup() }
        try store.saveAnswer(questionID: question.id, answer: "Edited later", at: at)
        try store.renameTheme(id: theme.id, to: "Renamed", at: at)
        controller.reconcile(with: store, at: at)
        #expect(FileManager.default.fileExists(atPath: folder.path))
        let text = try String(contentsOf: folder.appending(path: "Feeeder-review.txt"), encoding: .utf8)
        #expect(text.contains("My private answer") && !text.contains("Edited later"))      // a labelled snapshot, as promised
        controller.reconcile(with: store, at: at.addingTimeInterval(86_401))
        #expect(!FileManager.default.fileExists(atPath: folder.path))                       // the 24-hour limit still applies
    }

    @Test func aThemeCopyIsOpenedOnlyAfterItsPackageIsStillValid() async throws {
        let at = Date.now
        let (library, store, _, _, question, controller, _, launcher) = try themeCopy(at); defer { library.cleanup() }
        let review = AIPackageReview(store: store, now: { at })
        let theme = try #require(store.themes.first)
        let link = try #require(store.themeArticles.first)
        try review.build(selections: [.themeArticle(link.key)], theme: AIThemeRequest(themeID: theme.id, includeQuestions: true, includeAnswers: true), language: "English", at: at)
        let second = ClaudeHandoffController(directory: library.directory.appending(path: "handoff2"), review: review, launcher: launcher, now: { at })
        let package = try #require(review.package)
        try store.saveAnswer(questionID: question.id, answer: "Changed after review", at: at)
        await second.open(package: package)
        #expect(launcher.urls.isEmpty && second.error != nil && !second.opened)            // changed after review: nothing is opened
    }

    @Test func copiesFromOlderVersionsWithoutThemeFieldsStillReconcile() throws {
        let at = Date.now
        let (library, store, _, link, _, controller, folder, _) = try themeCopy(at); defer { library.cleanup() }
        let metadataFile = folder.appending(path: "metadata.json")
        var metadata = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: metadataFile)) as? [String: Any])
        metadata.removeValue(forKey: "themeID"); metadata.removeValue(forKey: "questionIDs")
        try JSONSerialization.data(withJSONObject: metadata).write(to: metadataFile)
        controller.reconcile(with: store, at: at)
        #expect(FileManager.default.fileExists(atPath: folder.path) && controller.maintenanceError == nil)
        try store.removeArticle(link.articleID, fromTheme: store.themes[0].id, at: at)
        #expect(!FileManager.default.fileExists(atPath: folder.path))                       // the source rule still applies to it
    }
}
