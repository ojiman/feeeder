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
    /// Feeds whose `http://` address was changed to `https://` (the app cannot fetch plain `http://`).
    public let upgraded: Int
}

public enum OPMLError: LocalizedError, Equatable {
    case notOPML, invalidXML, tooLarge, tooDeep, entities, tooMany, unreadable
    public var errorDescription: String? {
        switch self {
        case .notOPML: "OPMLファイルではありません。"
        case .invalidXML: "OPMLファイルのXMLに誤りがあり、読めませんでした。"
        case .tooLarge: "ファイルが大きすぎます（5MBまで）。"
        case .tooDeep: "階層が深すぎます（\(OPMLParser.maximumDepth)段まで）。"
        case .unreadable: "ファイルを開けませんでした。"
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
    public static let maximumDepth = 64
    /// A feed or folder name is cut to this many characters, so one odd file cannot store a huge name.
    public static let maximumNameLength = 200

    public static func parse(_ data: Data) throws -> OPMLDocument {
        guard data.count <= maximumBytes else { throw OPMLError.tooLarge }
        guard !data.isEmpty else { throw OPMLError.notOPML }
        // A DOCTYPE alone is harmless (the parser never loads it). An entity declaration is refused when the parser meets it
        // (see `OPMLReader`), so an encoding that hides the text (such as UTF-7) does not get past it.
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
        return OPMLDocument(feeds: reader.feeds, skipped: reader.skipped, repeated: reader.repeated, upgraded: reader.upgraded)
    }
}

private final class OPMLReader: NSObject, XMLParserDelegate {
    var feeds: [OPMLFeed] = []
    var skipped = 0
    var repeated = 0
    var upgraded = 0
    var sawOPML = false
    var failure: OPMLError?
    private var depth = 0
    private var inBody = false
    private var seen = Set<String>()
    /// For each open outline, the folder its children belong to: the top-level folder's name, inherited all the way down.
    private var folders: [String] = []

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        depth += 1
        guard depth <= OPMLParser.maximumDepth else { fail(.tooDeep, parser); return }
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
        guard let found = ArticleURL.validated(address) else { skipped += 1; return }
        let url = Self.secure(found)
        guard seen.insert(url.absoluteString).inserted else { repeated += 1; return }
        if url != found { upgraded += 1 }
        guard feeds.count < OPMLParser.maximumFeeds else { fail(.tooMany, parser); return }
        let name = Self.firstName(attributes, keys: ["title", "text"]) ?? url.host ?? "フィード"
        feeds.append(OPMLFeed(title: name, url: url,
                              siteURL: attributes["htmlurl"].flatMap { ArticleURL.validated($0) }.map(Self.secure), folder: folder))
    }

    /// `http://` becomes `https://`: the system does not let the app fetch plain `http://`, so a feed kept at that address would
    /// never update, and most sites answer on https as well. An address with its own port is left as it is (the port is for http).
    private static func secure(_ url: URL) -> URL {
        guard url.scheme == "http", url.port == nil, var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        parts.scheme = "https"
        return parts.url ?? url
    }

    /// The first of the attributes that holds a name, cut to the length limit.
    private static func firstName(_ attributes: [String: String], keys: [String]) -> String? {
        for key in keys {
            let name = SingleLineText.name(attributes[key] ?? "")
            if !name.isEmpty { return String(name.prefix(OPMLParser.maximumNameLength)) }
        }
        return nil
    }

    /// The name of a folder outline: empty (unfiled) when it has none or is called 「未分類」, which is no folder.
    private static func folderName(_ attributes: [String: String]) -> String {
        let name = firstName(attributes, keys: ["text", "title"]) ?? ""
        return name == "未分類" ? "" : name
    }

    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) { fail(.entities, parser) }
    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) { fail(.entities, parser) }
    func parser(_ parser: XMLParser, foundUnparsedEntityDeclarationWithName name: String, publicID: String?, systemID: String?, notationName: String?) { fail(.entities, parser) }

    private func fail(_ error: OPMLError, _ parser: XMLParser) {
        if failure == nil { failure = error }
        parser.abortParsing()
    }
}
