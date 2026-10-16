import Foundation

/// The article's text size in Settings (specification 3.7): five steps for the body. The title and the source and date lines follow it by
/// the same ratio, so the article keeps its shape.
public enum ArticleTextSize {
    public static let steps: [Double] = [14, 16, 18, 20, 22]
    public static let standard: Double = 16
    /// The `UserDefaults` key; kept across launches.
    public static let key = "articleTextSize"

    /// A stored value that is not a step (an edited or a damaged setting) becomes the nearest step.
    public static func step(_ value: Double) -> Double {
        guard value.isFinite else { return standard }
        return steps.min { abs($0 - value) < abs($1 - value) } ?? standard
    }

    /// The ratio of the size to the standard one, for every size in the article.
    public static func scale(_ value: Double) -> Double { step(value) / standard }
}
