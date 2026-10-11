import Foundation

/// The width of the note panel beside the article. The person drags the panel's edge; the width is kept between launches
/// (decision 0019, S1b). Whatever is stored is clamped on the way in and on the way out, so a corrupt value never makes
/// the panel unusable.
public enum NotePanelWidth {
    public static let range: ClosedRange<Double> = 300...640
    public static let defaultWidth: Double = 380
    public static let key = "notePanelWidth"

    public static func clamped(_ value: Double?) -> Double {
        guard let value, value.isFinite else { return defaultWidth }
        return min(max(value, range.lowerBound), range.upperBound)
    }
    public static func load(from defaults: UserDefaults = .standard) -> Double {
        clamped(defaults.object(forKey: key) as? Double)
    }
    public static func save(_ width: Double, to defaults: UserDefaults = .standard) {
        guard width.isFinite else { return }
        defaults.set(clamped(width), forKey: key)
    }
    /// A drag reports many widths; one that differs from the saved one by 1 pt or less is not worth a write.
    public static func needsSaving(new: Double, saved: Double?) -> Bool {
        guard new.isFinite else { return false }
        guard let saved else { return true }
        return abs(clamped(new) - saved) > 1
    }
}
