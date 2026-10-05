import Foundation

public enum RobotsPolicy {
    private struct Group { var agents: [String] = []; var rules: [(String, Bool)] = [] }
    public static func permits(url: URL, robotsText: String, userAgent: String) -> Bool {
        var groups: [Group] = [], current = Group(), sawRule = false
        for raw in robotsText.split(whereSeparator: \.isNewline) {
            let line = raw.split(separator: "#", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !line.isEmpty else { continue }
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { return false }
            let field = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            if field == "user-agent" {
                if sawRule { groups.append(current); current = Group(); sawRule = false }
                guard !value.isEmpty else { return false }
                current.agents.append(value.lowercased())
            } else if field == "allow" || field == "disallow" {
                guard !current.agents.isEmpty else { return false }
                sawRule = true
                if !value.isEmpty {
                    guard value.hasPrefix("/") else { return false }
                    current.rules.append((value, field == "allow"))
                }
            } else if field != "sitemap" && field != "crawl-delay" && field != "host" { return false }
        }
        if !current.agents.isEmpty { groups.append(current) }
        let agent = userAgent.lowercased()
        func specificity(_ group: Group) -> Int {
            group.agents.map { $0 == "*" ? 0 : (agent.contains($0) ? $0.count : -1) }.max() ?? -1
        }
        let score = groups.map(specificity).max() ?? -1
        guard score >= 0 else { return true }
        let parts = URLComponents(url: url, resolvingAgainstBaseURL: true)
        guard let path = normalized((parts?.percentEncodedPath ?? url.path) + (parts?.percentEncodedQuery.map { "?" + $0 } ?? ""), rule: false) else { return false }
        var winner: (length: Int, allow: Bool)?
        for group in groups where specificity(group) == score {
            for (pattern, allow) in group.rules {
                guard let pattern = normalized(pattern, rule: true) else { return false }
                let anchored = pattern.hasSuffix("$")
                let value = anchored ? String(pattern.dropLast()) : pattern
                let regex = "^" + value.components(separatedBy: "*").map(NSRegularExpression.escapedPattern).joined(separator: ".*") + (anchored ? "$" : "")
                guard path.range(of: regex, options: .regularExpression) != nil else { continue }
                let length = value.utf8.count
                if winner == nil || length > winner!.length || (length == winner!.length && allow) { winner = (length, allow) }
            }
        }
        return winner?.allow ?? true
    }
    // Compare UTF-8 octets consistently: escape Unicode, decode escaped unreserved
    // ASCII, and retain reserved escapes. Rule wildcards stay distinct from URL literals.
    private static func normalized(_ text: String, rule: Bool) -> String? {
        let bytes = Array(text.utf8)
        var output = "", index = 0
        func hex(_ byte: UInt8) -> UInt8? {
            switch byte {
            case 48...57: byte - 48
            case 65...70: byte - 55
            case 97...102: byte - 87
            default: nil
            }
        }
        func unreserved(_ byte: UInt8) -> Bool {
            (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte) || [45, 46, 95, 126].contains(byte)
        }
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 37 {
                guard index + 2 < bytes.count, let high = hex(bytes[index + 1]), let low = hex(bytes[index + 2]) else { return nil }
                let decoded = high * 16 + low
                output += unreserved(decoded) ? String(UnicodeScalar(decoded)) : String(format: "%%%02X", decoded)
                index += 3
            } else {
                output += byte >= 128 || byte <= 32 || byte == 127 || (!rule && (byte == 42 || byte == 36))
                    ? String(format: "%%%02X", byte) : String(UnicodeScalar(byte))
                index += 1
            }
        }
        return output
    }
}
