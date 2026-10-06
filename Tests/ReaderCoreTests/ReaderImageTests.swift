import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Testing
@testable import ReaderCore

private actor ImageClient: HTTPFetching {
    var count = 0, active = 0, maximum = 0
    let delay: Duration
    init(delay: Duration = .milliseconds(30)) { self.delay = delay }
    func fetch(url: URL, headers: [String: String], maximumBytes: Int) async throws -> HTTPResponse {
        count += 1; active += 1; maximum = max(maximum, active)
        defer { active -= 1 }
        try await Task.sleep(for: delay)
        return try await HTTPClient(protocolClasses: [StubURLProtocol.self]).fetch(url: url, headers: headers, maximumBytes: maximumBytes)
    }
}

struct ReaderImageTests {
    func png(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.7, green: 0.3, blue: 0.1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage()), data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil); #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }
    @Test func boundedImagesFailWithoutBlockingText() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let loader = ReaderImageLoader(directory: library.directory.appending(path: "images"), client: HTTPClient(protocolClasses: [StubURLProtocol.self]))
        let base = URL(string: "https://synthetic.example/" + UUID().uuidString + "/")!
        let normal = base.appending(path: "normal.png")
        StubURLProtocol.register(.init(data: try png(width: 2000, height: 1000)), at: normal)
        let data = try #require(try await loader.image(url: normal, at: .now))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(max(image.width, image.height) <= 1200)
        for (name, bytes) in [("huge", Data(repeating: 1, count: 4 * 1024 * 1024 + 1)), ("pixels", try png(width: 5000, height: 4001)), ("bad", Data("bad".utf8)), ("svg", Data("<svg/>".utf8))] {
            let url = base.appending(path: name)
            StubURLProtocol.register(.init(data: bytes), at: url)
            #expect(try await loader.image(url: url, at: .now) == nil)
        }
        #expect(throws: (any Error).self) { try HTTPClient.validateRedirect(from: normal, to: URL(string: "http://synthetic.example/unsafe")!) }
        let slow = ReaderImageLoader(directory: library.directory.appending(path: "slow"), client: ImageClient(delay: .seconds(2)))
        let task = Task { try await slow.image(url: normal, at: .now) }
        try await Task.sleep(for: .milliseconds(30)); task.cancel()
        do { _ = try await task.value; Issue.record("Cancelled fetch returned an image") } catch is CancellationError {} catch { Issue.record("Unexpected cancellation: \(error)") }
    }
    @Test func diskCacheEvictsAndExpires() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let root = library.directory.appending(path: "images"), at = Date.now
        let client = ImageClient()
        let loader = ReaderImageLoader(directory: root, client: client)
        let url = URL(string: "https://synthetic.example/" + UUID().uuidString + ".png")!
        StubURLProtocol.register(.init(data: try png(width: 10, height: 10)), at: url)
        async let first = loader.image(url: url, at: at)
        async let shared = loader.image(url: url, at: at)
        let results = try await (first, shared)
        #expect(results.0 != nil)
        #expect(results.0 == results.1)
        #expect(await client.count == 1)
        _ = try await loader.image(url: url, at: at.addingTimeInterval(6 * 86_400)); #expect(await client.count == 1)
        _ = try await loader.image(url: url, at: at.addingTimeInterval(7 * 86_400)); #expect(await client.count == 2)
        let failed = url.appending(path: "failure")
        StubURLProtocol.register(.init(data: Data("bad".utf8)), at: failed)
        _ = try await loader.image(url: failed, at: at)
        _ = try await loader.image(url: failed, at: at.addingTimeInterval(599)); #expect(await client.count == 3)
        _ = try await loader.image(url: failed, at: at.addingTimeInterval(600)); #expect(await client.count == 4)
        let metadataURL = root.appending(path: AIPackageBuilder.hash(Data(url.absoluteString.utf8)) + ".json")
        let template = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: metadataURL)) as? [String: Any])
        for index in 0..<20 {
            let fake = "https://synthetic.example/cache-\(index).png", key = AIPackageBuilder.hash(Data(fake.utf8))
            var record = template; record["url"] = fake
            try JSONSerialization.data(withJSONObject: record).write(to: root.appending(path: key + ".json"))
            try Data(repeating: 1, count: 4 * 1024 * 1024).write(to: root.appending(path: key + ".png"))
        }
        let reopened = ReaderImageLoader(directory: root, client: client)
        try await reopened.prepare(at: at.addingTimeInterval(7 * 86_400))
        let bytes = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.fileSizeKey]).reduce(0) { sum, file in sum + (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) }
        #expect(bytes <= 64 * 1024 * 1024)
        try await reopened.prepare(at: at.addingTimeInterval(14 * 86_400))
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }
    @Test func concurrentRequestsAreBounded() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let client = ImageClient(delay: .milliseconds(100)), data = try png(width: 10, height: 10)
        let loader = ReaderImageLoader(directory: library.directory.appending(path: "images"), client: client)
        let prefix = UUID().uuidString
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<12 {
                let url = URL(string: "https://synthetic.example/\(prefix)/\(i).png")!
                StubURLProtocol.register(.init(data: data), at: url)
                group.addTask { _ = try await loader.image(url: url, at: .now) }
            }
            try await group.waitForAll()
        }
        #expect(await client.maximum <= 4)
        #expect(await client.count == 12)
    }
}
