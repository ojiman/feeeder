import Foundation
import Testing
@testable import ReaderCore

@MainActor private final class ProbeLauncher: ClaudeLaunching {
    var urls: [URL] = []
    var fail = false
    func open(_ url: URL) async throws { urls.append(url); if fail { throw AIPackageError.invalid } }
}

@MainActor struct ClaudeHandoffTests {
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
        #expect(try HandoffFiles.sourceIDs(directory: root).isEmpty)
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
        try HandoffFiles.reconcile(directory: root, validSourceExpiries: store.availableContentExpiries(at: .now), at: .now)
        #expect(!FileManager.default.fileExists(atPath: file.path) && parts.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
        #expect(try Data(contentsOf: export) == bytes)
    }
    @Test func generatedLifetimeShortensAndNeverExtends() throws {
        let (library, _, _, package, root) = try fixture(); defer { library.cleanup() }
        let file = try HandoffFiles.write(package, directory: root)
        let early = Date.now.addingTimeInterval(60)
        try HandoffFiles.reconcile(directory: root, validSourceExpiries: [package.sources[0].articleID: early], at: .now)
        try HandoffFiles.reconcile(directory: root, validSourceExpiries: [package.sources[0].articleID: package.expiresAt], at: .now)
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
}
