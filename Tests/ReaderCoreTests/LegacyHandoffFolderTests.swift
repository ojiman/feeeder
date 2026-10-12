import Foundation
import Testing
@testable import ReaderCore

/// Decision 0049: the hand-off to Claude is gone. Earlier versions kept copies of the note text in a `Handoffs` folder of the library,
/// and nothing deletes them any more, so the folder is removed at the start.
struct LegacyHandoffFolderTests {
    private func makeLibrary() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "unagi-legacy-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func theFolderWithTheOldCopiesIsRemovedAndTheRestOfTheLibraryStays() throws {
        let library = try makeLibrary(); defer { try? FileManager.default.removeItem(at: library) }
        let folder = library.appending(path: "Handoffs", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder.appending(path: "package-1"), withIntermediateDirectories: true)
        try Data("note text".utf8).write(to: folder.appending(path: "package-1/note.txt"))
        try Data("store".utf8).write(to: library.appending(path: "Reader.store"))
        #expect(try LegacyHandoffFolder.remove(in: library))
        #expect(!FileManager.default.fileExists(atPath: folder.path))
        #expect(FileManager.default.fileExists(atPath: library.appending(path: "Reader.store").path))
    }

    @Test func withNoFolderNothingHappens() throws {
        let library = try makeLibrary(); defer { try? FileManager.default.removeItem(at: library) }
        #expect(try !LegacyHandoffFolder.remove(in: library))
    }

    @Test func aLinkNamedHandoffsIsRemovedButNotWhatItPointsTo() throws {
        let library = try makeLibrary(); defer { try? FileManager.default.removeItem(at: library) }
        let elsewhere = try makeLibrary(); defer { try? FileManager.default.removeItem(at: elsewhere) }
        try Data("keep".utf8).write(to: elsewhere.appending(path: "keep.txt"))
        try FileManager.default.createSymbolicLink(at: library.appending(path: "Handoffs"), withDestinationURL: elsewhere)
        #expect(try LegacyHandoffFolder.remove(in: library))
        #expect(FileManager.default.fileExists(atPath: elsewhere.appending(path: "keep.txt").path))
    }
}
