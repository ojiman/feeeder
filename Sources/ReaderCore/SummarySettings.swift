import Foundation
import CoreFoundation

public enum SummaryLength: Int, CaseIterable, Sendable { case one = 1, three = 3, five = 5 }
public enum SummaryFormat: String, CaseIterable, Sendable { case prose, bullets }

public struct SummarySettings: Equatable, Sendable {
    public static let lengthKey = "summaryLength"
    public static let formatKey = "summaryFormat"
    public static let instructionKey = "summaryExtraInstruction"
    public let length: SummaryLength
    public let format: SummaryFormat
    public let extraInstruction: String

    public init(length: SummaryLength = .three, format: SummaryFormat = .prose, extraInstruction: String = "") {
        self.length = length; self.format = format
        self.extraInstruction = String(extraInstruction.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.joined(separator: " ").prefix(200))
    }
    public static func load(from defaults: UserDefaults = .standard) -> SummarySettings {
        let storedLength = defaults.object(forKey: lengthKey)
        let length = (storedLength as? NSNumber).flatMap { number -> SummaryLength? in
            guard CFGetTypeID(number) != CFBooleanGetTypeID(), String(cString: number.objCType) != "d", String(cString: number.objCType) != "f" else { return nil }
            return (storedLength as? Int).flatMap(SummaryLength.init(rawValue:))
        }
        return SummarySettings(length: length ?? .three,
                        format: (defaults.object(forKey: formatKey) as? String).flatMap(SummaryFormat.init(rawValue:)) ?? .prose,
                        extraInstruction: defaults.object(forKey: instructionKey) as? String ?? "")
    }
}
