import Foundation

/// Which folders of the sidebar are open. A folder that receives a subscription is opened, so the person sees where it went.
/// The open folders are kept in `UserDefaults` and come back at the next launch (specification 3.1.4); a first launch has none open.
struct FolderExpansion {
    /// The `UserDefaults` key: a list of folder names.
    static let key = "openSidebarFolders"

    private var open: Set<String>
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        open = Set(defaults.stringArray(forKey: Self.key) ?? [])
    }

    func isExpanded(_ folder: String) -> Bool { open.contains(folder) }
    mutating func set(_ folder: String, expanded: Bool) {
        if expanded { open.insert(folder) } else { open.remove(folder) }
        save()
    }
    /// Opens the folder. The empty name is "unfiled", which has no folder row.
    mutating func reveal(_ folder: String) {
        guard !folder.isEmpty else { return }
        open.insert(folder)
        save()
    }
    /// A renamed (or merged) folder keeps its state: it stays open if either of the two was open.
    mutating func rename(from old: String, to new: String) {
        guard open.remove(old) != nil else { return }
        if !new.isEmpty { open.insert(new) }
        save()
    }
    /// Forgets folders that no longer exist (their last subscription left), so a new folder of the same name starts closed.
    mutating func forget(_ folders: some Collection<String>) {
        guard !open.isDisjoint(with: folders) else { return }
        open.subtract(folders)
        save()
    }

    private func save() { defaults.set(open.sorted(), forKey: Self.key) }
}
