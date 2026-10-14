import Foundation

/// The width of the note panel beside the article. The person drags the panel's edge; the width is kept between launches
/// (decision 0019, S1b). Whatever is stored is clamped on the way in and on the way out, so a corrupt value never makes
/// the panel unusable. 640 pt at first, up to 1,280 pt (decision 0050).
public enum NotePanelWidth {
    public static let range: ClosedRange<Double> = 300...1_280
    public static let defaultWidth: Double = 640
    /// A new key, so that the width an earlier version saved (under `earlierKey`) is dropped once and everyone starts at 640 pt.
    public static let key = "notePanelWidth.0050"
    public static let earlierKey = "notePanelWidth"

    /// What a narrow window leaves for the other columns (specification 3.5): the article, and the list in the three-column layout.
    public static let articleMinimum: Double = 360
    public static let listMinimum: Double = 280

    /// The widest the panel can be in a window of this width: the article keeps its minimum, and so does the list in the three-column
    /// layout. Never below the panel's own minimum.
    public static func maximum(windowWidth: Double, listShown: Bool) -> Double {
        guard windowWidth.isFinite else { return range.upperBound }
        let room = windowWidth - articleMinimum - (listShown ? listMinimum : 0)
        return min(max(room, range.lowerBound), range.upperBound)
    }

    public static func clamped(_ value: Double?) -> Double {
        guard let value, value.isFinite else { return defaultWidth }
        return min(max(value, range.lowerBound), range.upperBound)
    }
    public static func load(from defaults: UserDefaults = .standard) -> Double {
        defaults.removeObject(forKey: earlierKey)
        return clamped(defaults.object(forKey: key) as? Double)
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
    /// Whether a measured width is one the person chose. The layout reports the first width it gave the panel and may squeeze it below
    /// the minimum in a small window; neither is a choice. A width counts when it is inside the range we offer, differs from the first
    /// one seen for this panel by more than 1 pt, and is not already saved.
    /// A width that is the window's limit (`maximum`) is the layout's, not a choice: a window that gave way must not change the width kept.
    public static func shouldSave(new: Double, saved: Double?, firstSeen: Double?, limit: Double = range.upperBound + 1) -> Bool {
        guard new.isFinite, range.contains(new), let firstSeen, firstSeen.isFinite, abs(new - firstSeen) > 1, abs(new - limit) > 1 else { return false }
        return needsSaving(new: new, saved: saved)
    }
}
