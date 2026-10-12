import Foundation

/// One subscription in an OPML file.
public struct OPMLFeed: Equatable, Sendable {
    public let title: String
    public let url: URL
    public let siteURL: URL?
    /// One level only, as in the app; empty is unfiled.
    public let folder: String
    public init(title: String, url: URL, siteURL: URL?, folder: String) {
        self.title = title; self.url = url; self.siteURL = siteURL; self.folder = folder
    }
}

public struct OPMLDocument: Sendable {
    public let feeds: [OPMLFeed]
    /// Outlines that name a feed with an address that cannot be used (not `http(s)`, or with a user name or password, or empty).
    public let skipped: Int
    /// Feeds that appear more than once in the file; the first one is kept.
    public let repeated: Int
}

public enum OPMLError: LocalizedError, Equatable {
    case notOPML, invalidXML, tooLarge, entities, tooMany
    public var errorDescription: String? {
        switch self {
        case .notOPML: "OPMLファイルではありません。"
        case .invalidXML: "OPMLファイルのXMLに誤りがあり、読めませんでした。"
        case .tooLarge: "ファイルが大きすぎます（5MBまで）。"
        case .entities: "独自エンティティを含むファイルは取り込めません。"
        case .tooMany: "購読が多すぎます（\(OPMLParser.maximumFeeds)件まで）。ファイルを分けてください。"
        }
    }
}

/// Reads the subscriptions of an OPML 1.0 / 2.0 file (decision 0039): every `<outline>` with an `xmlUrl` is a feed; an outline
/// without one that holds feeds is a folder. Nothing is fetched. Like the feed parser, it never resolves a DTD or an entity.
public enum OPMLParser {
    public static let maximumBytes = 5 * 1024 * 1024
    public static let maximumFeeds = 2_000
    static let maximumDepth = 64

    public static func parse(_ data: Data) throws -> OPMLDocument {
        guard data.count <= maximumBytes else { throw OPMLError.tooLarge }
        guard !data.isEmpty else { throw OPMLError.notOPML }
        // A DOCTYPE alone is harmless (the parser never loads it); an entity could expand without limit.
        let scan = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\0", with: "")
        guard !scan.contains("<!ENTITY") else { throw OPMLError.entities }
        let reader = OPMLReader()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never
        parser.delegate = reader
        let finished = parser.parse()
        if let failure = reader.failure { throw failure }
        guard finished else { throw OPMLError.invalidXML }
        guard reader.sawOPML else { throw OPMLError.notOPML }
        return OPMLDocument(feeds: reader.feeds, skipped: reader.skipped, repeated: reader.repeated)
    }
}

private final class OPMLReader: NSObject, XMLParserDelegate {
    var feeds: [OPMLFeed] = []
    var skipped = 0
    var repeated = 0
    var sawOPML = false
    var failure: OPMLError?
    private var depth = 0
    private var inBody = false
    private var seen = Set<String>()
    /// For each open outline, the folder its children belong to: the top-level folder's name, inherited all the way down.
    private var folders: [String] = []

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        depth += 1
        guard depth <= OPMLParser.maximumDepth else { fail(.tooLarge, parser); return }
        let name = name.lowercased()
        if depth == 1 {
            guard name == "opml" else { fail(.notOPML, parser); return }
            sawOPML = true
        } else if name == "body", depth == 2 { inBody = true }
        guard inBody, name == "outline" else { return }
        let attributes = Dictionary(attributes.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { first, _ in first })
        if let address = attributes["xmlurl"] {
            add(address, attributes: attributes, folder: folders.last ?? "", parser: parser)
            folders.append(folders.last ?? "")
        } else {
            folders.append(folders.last ?? Self.folderName(attributes))
        }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if inBody, name.lowercased() == "outline", !folders.isEmpty { folders.removeLast() }
        if name.lowercased() == "body", depth == 2 { inBody = false }
        depth -= 1
    }

    private func add(_ address: String, attributes: [String: String], folder: String, parser: XMLParser) {
        guard let url = ArticleURL.validated(address) else { skipped += 1; return }
        guard seen.insert(url.absoluteString).inserted else { repeated += 1; return }
        guard feeds.count < OPMLParser.maximumFeeds else { fail(.tooMany, parser); return }
        let name = SingleLineText.name(attributes["title"] ?? "")
        let text = SingleLineText.name(attributes["text"] ?? "")
        feeds.append(OPMLFeed(title: !name.isEmpty ? name : !text.isEmpty ? text : url.host ?? "フィード", url: url,
                              siteURL: attributes["htmlurl"].flatMap { ArticleURL.validated($0) }, folder: folder))
    }

    /// The name of a folder outline: empty (unfiled) when it has none or is called 「未分類」, which is no folder.
    private static func folderName(_ attributes: [String: String]) -> String {
        let name = SingleLineText.name(attributes["text"] ?? attributes["title"] ?? "")
        return name == "未分類" ? "" : name
    }

    private func fail(_ error: OPMLError, _ parser: XMLParser) {
        if failure == nil { failure = error }
        parser.abortParsing()
    }
}
