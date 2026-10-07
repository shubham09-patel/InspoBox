import Foundation

enum ItemKind: String, Codable { case image, link, video }

struct InspoItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: ItemKind
    var name: String
    var genre: String
    var tags: [String]
    var fileName: String? = nil
    var url: String? = nil
    var width: Double? = nil
    var height: Double? = nil
    var thumbName: String? = nil   // thumbnail for videos
    var added = Date()

    var aspect: Double {
        guard let w = width, let h = height, w > 0 else { return 0.55 }
        return min(max(h / w, 0.4), 2.2)
    }
}

enum Phase: String, Codable, CaseIterable, Identifiable {
    case script = "Script"
    case assets = "Asset Collection"
    case rough = "Rough Sketching"
    case sketching = "Sketching"
    case colouring = "Colouring"
    case detailing = "Detailing"
    case uploaded = "Uploaded"

    var id: String { rawValue }
    var index: Int { Phase.allCases.firstIndex(of: self)! }
    var next: Phase? { index + 1 < Phase.allCases.count ? Phase.allCases[index + 1] : nil }
}

struct Project: Identifiable, Codable {
    var id = UUID()
    var title: String
    var phase: Phase = .script
    var notes = ""
    var created = Date()
    var phaseDates: [String: Date] = [:]
    var uploadDate: Date? = nil
    var refIDs: [UUID] = []        // linked reference images/links
    var deadline: Date? = nil
    var remind = false

    enum CodingKeys: String, CodingKey {
        case id, title, phase, notes, created, phaseDates, uploadDate, refIDs, deadline, remind
    }

    init(title: String) { self.title = title }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        phase = try c.decodeIfPresent(Phase.self, forKey: .phase) ?? .script
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        phaseDates = try c.decodeIfPresent([String: Date].self, forKey: .phaseDates) ?? [:]
        uploadDate = try c.decodeIfPresent(Date.self, forKey: .uploadDate)
        refIDs = try c.decodeIfPresent([UUID].self, forKey: .refIDs) ?? []
        deadline = try c.decodeIfPresent(Date.self, forKey: .deadline)
        remind = try c.decodeIfPresent(Bool.self, forKey: .remind) ?? false
    }

    mutating func set(_ p: Phase) {
        phase = p
        phaseDates[p.rawValue] = Date()
        if p == .uploaded && uploadDate == nil { uploadDate = Date() }
    }
    mutating func advance() { if let n = phase.next { set(n) } }
}

struct Pending: Identifiable {
    let id = UUID()
    var data: Data?      // image bytes (nil = link only)
    var url: URL?        // source url
    var videoFile: URL?  // local video file waiting to be saved
}
