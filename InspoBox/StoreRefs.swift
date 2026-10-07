import AppKit

extension Store {
    func refs(of p: Project) -> [InspoItem] {
        p.refIDs.compactMap { id in items.first { $0.id == id } }
    }

    func toggle(_ item: InspoItem, in projectID: UUID) {
        guard let i = projects.firstIndex(where: { $0.id == projectID }) else { return }
        if let k = projects[i].refIDs.firstIndex(of: item.id) {
            projects[i].refIDs.remove(at: k)
        } else {
            projects[i].refIDs.append(item.id)
        }
    }

    func open(_ item: InspoItem) {
        if let u = fileURL(for: item) { NSWorkspace.shared.open(u) }
        else if let s = item.url, let u = URL(string: s) { NSWorkspace.shared.open(u) }
    }
}
