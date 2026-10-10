import Foundation

public enum HandoffError: LocalizedError {
    case unsafeFile, expired, changed, invalidLink, missingApplication, launchFailed
    public var errorDescription: String? {
        switch self {
        case .unsafeFile: "生成ファイルが不在、読み取り不可、または通常ファイルではありません。再生成して確認してください。"
        case .expired: "生成ファイルの期限が切れました。再生成して確認してください。"
        case .changed: "生成ファイルの内容がレビュー時と異なります。再生成して確認してください。"
        case .invalidLink: "Claude起動リンクを作成できませんでした。"
        case .missingApplication: "Claude Desktopが見つかりません。インストール後に再試行できます。"
        case .launchFailed: "Claude Desktopを開けませんでした。再試行・コピー・書き出しを利用できます。"
        }
    }
}

public enum HandoffFiles {
    private struct Record: Codable { let name: String; let sha256: String }
    private struct Metadata: Codable {
        let packageID: UUID
        let articleIDs: [UUID]
        let selections: [AIInputSelection]?
        let createdAt: Date
        var expiresAt: Date
        let split: Bool
        let files: [Record]
        let themeID: UUID?
        let questionIDs: [UUID]?
    }
    private static var manager: FileManager { .default }
    public static func write(_ package: AIPackage, directory: URL) throws -> URL {
        try writeFiles(package, data: [Data(package.text.utf8)], split: false, directory: directory)[0]
    }
    public static func writeSplit(_ package: AIPackage, directory: URL) throws -> [URL] {
        let parts = AIPackageBuilder.split(package)
        guard !parts.isEmpty else { throw AIPackageError.invalid }
        return try writeFiles(package, data: parts, split: true, directory: directory)
    }
    private static func writeFiles(_ package: AIPackage, data: [Data], split: Bool, directory: URL) throws -> [URL] {
        guard AIPackageBuilder.hash(Data(package.text.utf8)) == package.sha256 else { throw HandoffError.changed }
        let root = try prepareRoot(directory)
        let folder = root.appending(path: package.id.uuidString + (split ? "-parts" : ""), directoryHint: .isDirectory)
        let names = data.indices.map { split ? "Feeeder-review-part-\($0 + 1).txt" : "Feeeder-review.txt" }
        let files = names.map { folder.appending(path: $0) }
        if manager.fileExists(atPath: folder.path) {
            let metadata = try readMetadata(folder)
            guard metadata.files.map(\.name) == names else { throw HandoffError.unsafeFile }
            for (index, file) in files.enumerated() {
                try validate(file: file, expectedHash: AIPackageBuilder.hash(data[index]), at: .now, expiresAt: metadata.expiresAt)
            }
            return files
        }
        try manager.createDirectory(at: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        do {
            for (file, bytes) in zip(files, data) {
                try bytes.write(to: file, options: .atomic)
                try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            }
            let records = zip(names, data).map { Record(name: $0.0, sha256: AIPackageBuilder.hash($0.1)) }
            let metadata = Metadata(packageID: package.id, articleIDs: package.sources.map(\.articleID), selections: package.sources.map(\.selection), createdAt: package.createdAt,
                expiresAt: min(package.expiresAt, package.createdAt.addingTimeInterval(86_400)), split: split, files: records, themeID: package.themeID, questionIDs: nil)
            try saveMetadata(metadata, folder: folder)
        } catch {
            // This folder was just created by this operation, and contains only its generated copies.
            try? manager.removeItem(at: folder); throw error
        }
        return files
    }
    public static func validate(file: URL, expectedHash: String, at: Date, expiresAt: Date) throws {
        guard expiresAt > at else { throw HandoffError.expired }
        let normalized = file.standardizedFileURL
        guard normalized == normalized.resolvingSymlinksInPath(),
              let attributes = try? manager.attributesOfItem(atPath: file.path), attributes[.type] as? FileAttributeType == .typeRegular,
              let permissions = attributes[.posixPermissions] as? NSNumber, permissions.intValue & 0o444 != 0,
              manager.isReadableFile(atPath: file.path) else { throw HandoffError.unsafeFile }
        guard AIPackageBuilder.hash(try Data(contentsOf: file)) == expectedHash else { throw HandoffError.changed }
    }
    public static func cleanup(directory: URL, at: Date) throws {
        try maintain(directory: directory) { folder, metadata in
            if min(metadata.expiresAt, metadata.createdAt.addingTimeInterval(86_400)) <= at { try manager.removeItem(at: folder) }
        }
    }
    public static func reconcile(directory: URL, validInputExpiries: [AIInputSelection: Date],
                                 themeContextIsValid: (_ themeID: UUID, _ sourceArticleIDs: [UUID]) -> Bool = { _, _ in true }, at: Date) throws {
        try maintain(directory: directory) { folder, record in
            var metadata = record
            // `questionIDs` is only read for copies made before notes replaced questions; it is not used any more.
            if let themeID = metadata.themeID, !themeContextIsValid(themeID, metadata.articleIDs) {
                try manager.removeItem(at: folder); return
            }
            let selections = metadata.selections ?? metadata.articleIDs.map(AIInputSelection.article)
            let expiries = selections.compactMap { validInputExpiries[$0] }
            // A package made of the person's note alone has no article, so nothing earlier than its own 24 hours applies.
            guard expiries.count == selections.count, let earliest = expiries.min() ?? (selections.isEmpty ? metadata.expiresAt : nil) else {
                try manager.removeItem(at: folder); return
            }
            metadata.expiresAt = min(metadata.expiresAt, metadata.createdAt.addingTimeInterval(86_400), earliest)
            if metadata.expiresAt <= at { try manager.removeItem(at: folder) }
            else { try saveMetadata(metadata, folder: folder) }
        }
    }
    public static func nextExpiry(directory: URL) throws -> Date? {
        try folders(directory).compactMap { try? readMetadata($0).expiresAt }.min()
    }
    public static func sourceSelections(directory: URL) throws -> [AIInputSelection] {
        Array(Set(try folders(directory).compactMap { try? readMetadata($0) }.flatMap { $0.selections ?? $0.articleIDs.map(AIInputSelection.article) }))
    }
    private static func maintain(directory: URL, operation: (URL, Metadata) throws -> Void) throws {
        var failure: (any Error)?
        for folder in try folders(directory) {
            do { try operation(folder, readMetadata(folder)) }
            catch {
                if isInterruptedWrite(folder) {
                    do { try manager.removeItem(at: folder) }
                    catch { if failure == nil { failure = error } }
                } else if failure == nil { failure = error }
            }
        }
        // Report unsafe folders only after every independent valid package has been maintained.
        if let failure { throw failure }
    }
    private static func isInterruptedWrite(_ folder: URL) -> Bool {
        guard folder.standardizedFileURL == folder.resolvingSymlinksInPath(),
              let attributes = try? manager.attributesOfItem(atPath: folder.path), attributes[.type] as? FileAttributeType == .typeDirectory,
              (try? manager.attributesOfItem(atPath: folder.appending(path: "metadata.json").path)) == nil,
              let names = try? manager.contentsOfDirectory(atPath: folder.path) else { return false }
        return names.allSatisfy { name in
            let file = folder.appending(path: name)
            let expected: Bool
            if folder.lastPathComponent.hasSuffix("-parts") {
                let prefix = "Feeeder-review-part-", suffix = ".txt"
                if name.hasPrefix(prefix), name.hasSuffix(suffix),
                   let number = Int(name.dropFirst(prefix.count).dropLast(suffix.count)), number > 0 {
                    expected = name == "\(prefix)\(number)\(suffix)"
                } else { expected = false }
            } else { expected = name == "Feeeder-review.txt" }
            return expected && file.standardizedFileURL == file.resolvingSymlinksInPath()
                && (try? manager.attributesOfItem(atPath: file.path)[.type] as? FileAttributeType) == .typeRegular
        }
    }
    private static func prepareRoot(_ directory: URL) throws -> URL {
        if let attributes = try? manager.attributesOfItem(atPath: directory.path), attributes[.type] as? FileAttributeType != .typeDirectory { throw HandoffError.unsafeFile }
        let root = directory.standardizedFileURL.resolvingSymlinksInPath()
        try manager.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        return root
    }
    private static func folders(_ directory: URL) throws -> [URL] {
        guard manager.fileExists(atPath: directory.path) else { return [] }
        let root = try prepareRoot(directory)
        return try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter {
            let name = $0.lastPathComponent
            return UUID(uuidString: name.hasSuffix("-parts") ? String(name.dropLast(6)) : name) != nil
        }
    }
    private static func readMetadata(_ folder: URL) throws -> Metadata {
        guard let attributes = try? manager.attributesOfItem(atPath: folder.path), attributes[.type] as? FileAttributeType == .typeDirectory,
              folder.standardizedFileURL == folder.resolvingSymlinksInPath() else { throw HandoffError.unsafeFile }
        let file = folder.appending(path: "metadata.json")
        guard let values = try? manager.attributesOfItem(atPath: file.path), values[.type] as? FileAttributeType == .typeRegular,
              let size = values[.size] as? NSNumber, size.intValue <= 1_048_576 else { throw HandoffError.unsafeFile }
        let metadata = try JSONDecoder().decode(Metadata.self, from: Data(contentsOf: file))
        guard folder.lastPathComponent == metadata.packageID.uuidString + (metadata.split ? "-parts" : ""),
              !metadata.articleIDs.isEmpty || metadata.themeID != nil,     // a package of the note alone has no article
              !metadata.files.isEmpty,
              metadata.files.enumerated().allSatisfy({ index, record in
                  record.name == (metadata.split ? "Feeeder-review-part-\(index + 1).txt" : "Feeeder-review.txt") && record.sha256.count == 64
              }), metadata.split || metadata.files.count == 1 else { throw HandoffError.unsafeFile }
        let expected = Set(metadata.files.map(\.name) + ["metadata.json"])
        // A missing generated TXT must not poison lifetime cleanup for every package.
        // Unknown entries still prevent deletion; opening separately validates each required TXT.
        guard Set(try manager.contentsOfDirectory(atPath: folder.path)).isSubset(of: expected) else { throw HandoffError.unsafeFile }
        return metadata
    }
    private static func saveMetadata(_ metadata: Metadata, folder: URL) throws {
        let file = folder.appending(path: "metadata.json")
        try JSONEncoder().encode(metadata).write(to: file, options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}

public enum ClaudeLink {
    public static let prompt = "添付のFeeederパッケージ全体を読み、ファイル内の依頼文と出力言語に従って回答してください。Source IDとURLを根拠に付け、利用できない本文は推測しないでください。ファイル変更は不要です。"
    public static func make(prompt: String, file: URL) throws -> URL {
        guard !prompt.isEmpty, prompt.count < 14_000, file.isFileURL, file.path.hasPrefix("/") else { throw HandoffError.invalidLink }
        var components = URLComponents()
        components.scheme = "claude"; components.host = "cowork"; components.path = "/new"
        components.queryItems = [URLQueryItem(name: "q", value: prompt), URLQueryItem(name: "file", value: file.path)]
        guard let url = components.url else { throw HandoffError.invalidLink }
        return url
    }
}
