import Foundation
import SwiftData
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
        let note = try store.createNote(text: "# A\n", at: at)
        let link = try store.addArticle(id, toNote: note.id, at: at)
        let review = AIPackageReview(store: store, now: { at })
        let root = library.directory.appending(path: "handoff")
        try review.build(articleIDs: [id], language: "日本語", at: at)
        let oldFile = try HandoffFiles.write(try #require(review.package), directory: root)
        let metadataFile = oldFile.deletingLastPathComponent().appending(path: "metadata.json")
        var metadata = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: metadataFile)) as? [String: Any])
        metadata.removeValue(forKey: "selections")
        try JSONSerialization.data(withJSONObject: metadata).write(to: metadataFile)
        try review.build(selections: [.noteArticle(link.key)], language: "日本語", at: at)
        let savedFile = try HandoffFiles.write(try #require(review.package), directory: root)
        try store.deleteContent(articleIDs: [id], at: at)
        let inputs = try HandoffFiles.sourceSelections(directory: root)
        #expect(Set(inputs) == [.article(id), .noteArticle(link.key)])
        try HandoffFiles.reconcile(directory: root, validInputExpiries: store.availableInputExpiries(selections: inputs, at: at), at: at)
        #expect(!FileManager.default.fileExists(atPath: oldFile.path))
        #expect(FileManager.default.fileExists(atPath: savedFile.path))
        let data = try Data(contentsOf: savedFile)
        #expect(AIPackageBuilder.hash(data) == review.package?.sha256)
        try HandoffFiles.cleanup(directory: root, at: at.addingTimeInterval(86_400))
        #expect(!FileManager.default.fileExists(atPath: savedFile.path))
    }
    /// A copy written before the rename to notes names its theme (`themeID`) and its theme sources (`themeArticle`). It lives at most a day;
    /// the new code cannot read it, so maintenance removes it instead of failing again and again (decision 0019, S1b).
    @Test func aCopyWrittenBeforeTheRenameToNotesIsRemovedWithoutFailingMaintenance() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let at = Date.now
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let id = store.articles[0].id
        let review = AIPackageReview(store: store, now: { at })
        let root = library.directory.appending(path: "handoff")
        try review.build(articleIDs: [id], language: "日本語", at: at)
        let file = try HandoffFiles.write(try #require(review.package), directory: root)
        let metadataFile = file.deletingLastPathComponent().appending(path: "metadata.json")
        var metadata = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: metadataFile)) as? [String: Any])
        metadata["themeID"] = UUID().uuidString
        metadata["selections"] = [["themeArticle": ["_0": "\(UUID().uuidString):\(id.uuidString)"]]]
        try JSONSerialization.data(withJSONObject: metadata).write(to: metadataFile)
        let inputs = try HandoffFiles.sourceSelections(directory: root)
        try HandoffFiles.reconcile(directory: root, validInputExpiries: store.availableInputExpiries(selections: inputs, at: at), at: at)
        #expect(!FileManager.default.fileExists(atPath: file.deletingLastPathComponent().path))
        try HandoffFiles.cleanup(directory: root, at: at.addingTimeInterval(10 * 86_400))   // and nothing is left to fail later
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

    /// Store + note with a note, a package that includes it, and a controller that is wired the way the app wires it
    /// (a store change calls the controller's reconcile). `sources` false makes a package of the note alone.
    private func noteCopy(_ at: Date, sources: Bool = true) throws -> (library: TestLibrary, store: ReaderStore, note: Note, link: NoteArticle, controller: ClaudeHandoffController, folder: URL, launcher: ProbeLauncher) {
        let library = try TestLibrary()
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = "Recorded synthetic summary"
        let note = try store.createNote(text: "# Rates\n", at: at)
        let link = try store.addArticle(article.id, toNote: note.id, at: at)
        try store.saveNote(noteID: note.id, text: "My private note", at: at)
        let review = AIPackageReview(store: store, now: { at })
        let launcher = ProbeLauncher()
        let root = library.directory.appending(path: "handoff")
        let controller = ClaudeHandoffController(directory: root, review: review, launcher: launcher, now: { at })
        store.onContentPolicyChanged = { [weak store, weak controller] in if let store { controller?.reconcile(with: store, at: at) } }
        try review.build(selections: sources ? [.noteArticle(link.key)] : [], note: AINoteRequest(noteID: note.id, includeNote: true), language: "English", at: at)
        let package = try #require(review.package)
        let file = try HandoffFiles.write(package, directory: root)
        return (library, store, note, link, controller, file.deletingLastPathComponent(), launcher)
    }

    @Test func aCopyWithTheNoteIsRemovedWhenItsNoteOrASourceIsDeleted() async throws {
        let at = Date.now
        for removal in 0..<2 {
            let (library, store, note, link, controller, folder, _) = try noteCopy(at); defer { library.cleanup() }
            #expect(FileManager.default.fileExists(atPath: folder.path))
            controller.reconcile(with: store, at: at)
            #expect(FileManager.default.fileExists(atPath: folder.path))                  // nothing was removed yet
            switch removal {
            case 0: try store.deleteNote(id: note.id)
            default: try store.removeArticle(link.articleID, fromNote: note.id, at: at)
            }
            #expect(!FileManager.default.fileExists(atPath: folder.path), "removal \(removal)")
            #expect(controller.maintenanceError == nil)
        }
    }

    @Test func editingTheNoteKeepsTheCopyUntilItExpires() throws {
        let at = Date.now
        let (library, store, note, _, controller, folder, _) = try noteCopy(at); defer { library.cleanup() }
        try store.saveNote(noteID: note.id, text: "Edited later", at: at)
        controller.reconcile(with: store, at: at)
        #expect(FileManager.default.fileExists(atPath: folder.path))
        let text = try String(contentsOf: folder.appending(path: "Feeeder-review.txt"), encoding: .utf8)
        #expect(text.contains("My private note") && !text.contains("Edited later"))        // a labelled snapshot, as promised
        controller.reconcile(with: store, at: at.addingTimeInterval(86_401))
        #expect(!FileManager.default.fileExists(atPath: folder.path))                       // the 24-hour limit still applies
    }

    @Test func aCopyOfTheNoteAloneIsKeptForADayAndRemovedWithItsNote() throws {
        let at = Date.now
        let (library, store, note, _, controller, folder, _) = try noteCopy(at, sources: false); defer { library.cleanup() }
        controller.reconcile(with: store, at: at.addingTimeInterval(3_600))
        #expect(FileManager.default.fileExists(atPath: folder.path) && controller.maintenanceError == nil)   // no article: nothing earlier than 24 hours
        let metadata = try String(contentsOf: folder.appending(path: "metadata.json"), encoding: .utf8)
        #expect(metadata.contains(note.id.uuidString) && !metadata.contains("questionIDs"))
        controller.reconcile(with: store, at: at.addingTimeInterval(86_401))
        #expect(!FileManager.default.fileExists(atPath: folder.path))
        let (library2, store2, note2, _, controller2, folder2, _) = try noteCopy(at, sources: false); defer { library2.cleanup() }
        try store2.deleteNote(id: note2.id)
        #expect(!FileManager.default.fileExists(atPath: folder2.path) && controller2.maintenanceError == nil)   // the controller must stay alive: the store only holds it weakly
    }

    @Test func aNoteCopyIsOpenedOnlyAfterItsPackageIsStillValid() async throws {
        let at = Date.now
        let (library, store, note, link, _, _, launcher) = try noteCopy(at); defer { library.cleanup() }
        let review = AIPackageReview(store: store, now: { at })
        try review.build(selections: [.noteArticle(link.key)], note: AINoteRequest(noteID: note.id, includeNote: true), language: "English", at: at)
        let second = ClaudeHandoffController(directory: library.directory.appending(path: "handoff2"), review: review, launcher: launcher, now: { at })
        let package = try #require(review.package)
        try store.saveNote(noteID: note.id, text: "Changed after review", at: at)
        await second.open(package: package)
        #expect(launcher.urls.isEmpty && second.error != nil && !second.opened)            // changed after review: nothing is opened
    }

    @Test func copiesFromOlderVersionsStillReconcile() throws {
        let at = Date.now
        // A copy without any note fields (written before notes), and one that still has `questionIDs` (written before notes).
        for oldStyle in 0..<2 {
            let (library, store, note, link, controller, folder, _) = try noteCopy(at); defer { library.cleanup() }
            let metadataFile = folder.appending(path: "metadata.json")
            var metadata = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: metadataFile)) as? [String: Any])
            if oldStyle == 0 { metadata.removeValue(forKey: "noteID"); metadata.removeValue(forKey: "questionIDs") }
            else { metadata["questionIDs"] = [UUID().uuidString] }                       // questions that no longer exist
            try JSONSerialization.data(withJSONObject: metadata).write(to: metadataFile)
            controller.reconcile(with: store, at: at)
            #expect(FileManager.default.fileExists(atPath: folder.path) && controller.maintenanceError == nil, "style \(oldStyle)")   // the questions are not looked at any more
            try store.removeArticle(link.articleID, fromNote: note.id, at: at)
            #expect(!FileManager.default.fileExists(atPath: folder.path), "style \(oldStyle)")                       // the source rule still applies to it
        }
    }

    /// A copy made from a note with retained-article sources (the default choice on the review screen).
    private func retainedCopy(_ at: Date, includeNote: Bool) throws -> (library: TestLibrary, store: ReaderStore, note: Note, article: Article, controller: ClaudeHandoffController, folder: URL) {
        let library = try TestLibrary()
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]
        let note = try store.createNote(text: "# Rates\n", at: at)
        try store.addArticle(article.id, toNote: note.id, at: at)
        try store.saveNote(noteID: note.id, text: "My private note", at: at)
        let review = AIPackageReview(store: store, now: { at })
        let root = library.directory.appending(path: "handoff")
        let controller = ClaudeHandoffController(directory: root, review: review, launcher: ProbeLauncher(), now: { at })
        store.onContentPolicyChanged = { [weak store, weak controller] in if let store { controller?.reconcile(with: store, at: at) } }
        try review.build(selections: [.article(article.id)], note: AINoteRequest(noteID: note.id, includeNote: includeNote), language: "English", at: at)
        let file = try HandoffFiles.write(try #require(review.package), directory: root)
        return (library, store, note, article, controller, file.deletingLastPathComponent())
    }

    @Test func aCopyOfARetainedArticleIsRemovedWhenThatArticleLeavesTheNote() throws {
        let at = Date.now
        for note in [true, false] {
            let (library, store, note, article, controller, folder) = try retainedCopy(at, includeNote: note); defer { library.cleanup() }
            controller.reconcile(with: store, at: at)
            #expect(FileManager.default.fileExists(atPath: folder.path))
            try store.removeArticle(article.id, fromNote: note.id, at: at)
            #expect(!FileManager.default.fileExists(atPath: folder.path), "note \(note)")
        }
    }

    @Test func aCopyWithoutTheNoteIsRemovedWhenItsNoteIsDeleted() throws {
        let at = Date.now
        let (library, store, note, _, controller, folder) = try retainedCopy(at, includeNote: false); defer { library.cleanup() }
        controller.reconcile(with: store, at: at)
        #expect(FileManager.default.fileExists(atPath: folder.path))
        try store.deleteNote(id: note.id)
        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }

    @Test func theCleanUpRunsEvenWhenTheReloadAfterADeletionFails() throws {
        let at = Date.now
        let library = try TestLibrary(); defer { library.cleanup() }
        final class Gate { var failReload = false; var calls = 0 }
        let gate = Gate()
        let schema = ReaderStore.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration("Reader", schema: schema, url: library.url, cloudKitDatabase: .none)])
        let store = try ReaderStore(container: container, seedDemo: true, now: at, saveHook: nil, reloadHook: { if gate.failReload { throw CocoaError(.fileReadUnknown) } })
        let note = try store.createNote(text: "# A\n", at: at)
        store.onContentPolicyChanged = { gate.calls += 1 }
        gate.failReload = true
        #expect(throws: (any Error).self) { try store.deleteNote(id: note.id) }
        #expect(gate.calls == 1)                                                          // the deletion was saved, so the cleanup must run
    }
}
