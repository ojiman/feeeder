import Foundation

/// Which folders of the sidebar are open. A folder that receives a subscription is opened, so the person sees where it went.
struct FolderExpansion {
    private var open: Set<String> = []

    func isExpanded(_ folder: String) -> Bool { open.contains(folder) }
    mutating func set(_ folder: String, expanded: Bool) {
        if expanded { open.insert(folder) } else { open.remove(folder) }
    }
    /// Opens the folder. The empty name is "unfiled", which has no folder row.
    mutating func reveal(_ folder: String) { if !folder.isEmpty { open.insert(folder) } }
    /// A renamed (or merged) folder keeps its state: it stays open if either of the two was open.
    mutating func rename(from old: String, to new: String) {
        guard open.remove(old) != nil else { return }
        if !new.isEmpty { open.insert(new) }
    }
}
