import Foundation

/// The theme chosen in Settings ▸ 「外観」 (specification 3.7). Sepia is a light look on a warm paper colour.
public enum ReaderTheme: String, CaseIterable, Sendable {
    case system, light, dark, sepia

    /// The `UserDefaults` key; kept across launches.
    public static let key = "appearance"

    /// A stored value the app does not know (an edited setting) follows the system.
    public init(stored: String?) { self = stored.flatMap(ReaderTheme.init(rawValue:)) ?? .system }

    /// Dark or light for the system's controls; nil follows macOS. Sepia is drawn light.
    public var isDark: Bool? {
        switch self {
        case .system: nil
        case .dark: true
        case .light, .sepia: false
        }
    }
}

/// Sepia's colours, as sRGB from 0 to 255, and the contrast they give (specification 3.7: body text at least 4.5:1).
public enum SepiaPalette {
    public struct RGB: Sendable, Equatable { public let red, green, blue: Double }
    /// The reading surfaces: the list, the article, the note and their bands.
    public static let paper = RGB(red: 244, green: 236, blue: 216)
    /// The sidebar: a little darker than the paper.
    public static let sidebar = RGB(red: 234, green: 223, blue: 199)

    /// `over` drawn at `alpha` on `under`, as the system's text colours (black with an alpha in the light look) are drawn.
    public static func blend(_ over: RGB, alpha: Double, on under: RGB) -> RGB {
        RGB(red: over.red * alpha + under.red * (1 - alpha), green: over.green * alpha + under.green * (1 - alpha),
            blue: over.blue * alpha + under.blue * (1 - alpha))
    }

    /// The WCAG contrast ratio of two colours.
    public static func contrast(_ a: RGB, _ b: RGB) -> Double {
        func channel(_ value: Double) -> Double {
            let c = value / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        func luminance(_ c: RGB) -> Double { 0.2126 * channel(c.red) + 0.7152 * channel(c.green) + 0.0722 * channel(c.blue) }
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}
