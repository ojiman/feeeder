import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

public actor ReaderImageLoader {
    public static let maximumResponseBytes = 4 * 1024 * 1024
    public static let maximumDiskBytes = 64 * 1024 * 1024
    private struct Record: Codable {
        let url: String
        let createdAt: Date
        var accessedAt: Date
        let failed: Bool
        var lifetime: TimeInterval { failed ? 600 : 7 * 86_400 }
    }
    private struct Request {
        let task: Task<Data?, any Error>
        var waiters: Set<UUID>
    }
    private let directory: URL
    private let client: any HTTPFetching
    private var requests: [String: Request] = [:]
    private var active = 0
    private var prepared = false
    public init(directory: URL, client: any HTTPFetching = HTTPClient()) { self.directory = directory; self.client = client }
    public func prepare(at: Date = .now) throws { try cleanup(at: at); prepared = true }
    public func image(url: URL, at: Date = .now) async throws -> Data? {
        try Task.checkCancellation()
        guard let url = ArticleURL.validated(url.absoluteString) else { throw HTTPError.invalidURL }
        if !prepared { try prepare(at: at) }
        let key = ImageCacheKey.hash(Data(url.absoluteString.utf8)), token = UUID()
        if let record = readRecord(key), record.url == url.absoluteString, at < record.createdAt.addingTimeInterval(record.lifetime) {
            if record.failed { return nil }
            let file = path(key, "png")
            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 8 * 1024 * 1024, let data = try? Data(contentsOf: file) {
                var updated = record; updated.accessedAt = at
                try writeRecord(updated, key: key)
                return data
            }
        }
        if var shared = requests[key] { shared.waiters.insert(token); requests[key] = shared }
        else {
            let task = Task { try await self.load(url: url, key: key, at: at) }
            requests[key] = Request(task: task, waiters: [token])
        }
        let task = requests[key]!.task
        defer { release(key: key, token: token) }
        return try await withTaskCancellationHandler {
            let data = try await task.value
            try Task.checkCancellation()
            return data
        } onCancel: { Task { await self.cancel(key: key, token: token) } }
    }
    private func release(key: String, token: UUID) {
        guard var request = requests[key], request.waiters.remove(token) != nil else { return }
        if request.waiters.isEmpty { requests.removeValue(forKey: key) }
        else { requests[key] = request }
    }
    private func cancel(key: String, token: UUID) {
        guard var request = requests[key], request.waiters.remove(token) != nil else { return }
        if request.waiters.isEmpty { request.task.cancel(); requests.removeValue(forKey: key) }
        else { requests[key] = request }
    }
    private func load(url: URL, key: String, at: Date) async throws -> Data? {
        while active >= 4 { try await Task.sleep(for: .milliseconds(10)) }
        try Task.checkCancellation(); active += 1
        defer { active -= 1 }
        do {
            let response = try await client.fetch(url: url, headers: [:], maximumBytes: Self.maximumResponseBytes)
            try Task.checkCancellation()
            guard response.statusCode == 200, response.data.count <= Self.maximumResponseBytes else { throw HTTPError.invalidResponse }
            try HTTPClient.validateRedirect(from: url, to: response.finalURL)
            guard let data = Self.downsample(response.data) else { throw HTTPError.invalidResponse }
            try Task.checkCancellation()
            try data.write(to: path(key, "png"), options: .atomic)
            try writeRecord(Record(url: url.absoluteString, createdAt: at, accessedAt: at, failed: false), key: key)
            try cleanup(at: at)
            return data
        } catch is CancellationError { throw CancellationError() }
        catch {
            try Task.checkCancellation()
            try? FileManager.default.removeItem(at: path(key, "png"))
            try writeRecord(Record(url: url.absoluteString, createdAt: at, accessedAt: at, failed: true), key: key)
            try cleanup(at: at)
            return nil
        }
    }
    private static func downsample(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(source), type as String != UTType.svg.identifier,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber, let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.doubleValue > 0, height.doubleValue > 0, width.doubleValue * height.doubleValue <= 20_000_000,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 1200,
                  kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
    private func path(_ key: String, _ ext: String) -> URL { directory.appending(path: key + "." + ext) }
    private func readRecord(_ key: String) -> Record? {
        let file = path(key, "json")
        guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size < 8192,
              let data = try? Data(contentsOf: file), let record = try? JSONDecoder().decode(Record.self, from: data),
              ImageCacheKey.hash(Data(record.url.utf8)) == key else { return nil }
        return record
    }
    private func writeRecord(_ record: Record, key: String) throws { try JSONEncoder().encode(record).write(to: path(key, "json"), options: .atomic) }
    private func cleanup(at: Date) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let files = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
        var remaining: [(String, Record, Int)] = []
        for file in files where file.pathExtension == "json" {
            let key = file.deletingPathExtension().lastPathComponent
            guard key.count == 64, key.allSatisfy({ $0.isHexDigit }) else { continue }
            guard let record = readRecord(key), record.createdAt.addingTimeInterval(record.lifetime) > at else { try remove(key); continue }
            let size = (try? path(key, "png").resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let recordSize = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            remaining.append((key, record, size + recordSize))
        }
        // Remove interrupted PNG writes, too; only hashed cache payload names are owned here.
        let known = Set(remaining.map { $0.0 })
        for file in files where file.pathExtension == "png" {
            let key = file.deletingPathExtension().lastPathComponent
            if key.count == 64, key.allSatisfy({ $0.isHexDigit }), !known.contains(key), manager.fileExists(atPath: file.path) { try manager.removeItem(at: file) }
        }
        var total = remaining.reduce(0) { $0 + $1.2 }
        for entry in remaining.sorted(by: { $0.1.accessedAt < $1.1.accessedAt }) where total > Self.maximumDiskBytes {
            try remove(entry.0); total -= entry.2
        }
    }
    private func remove(_ key: String) throws {
        for ext in ["json", "png"] { let file = path(key, ext); if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) } }
    }
}

/// The file name of a cached image: the SHA-256 of its address, in hexadecimal.
enum ImageCacheKey {
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}
