import SwiftUI
import AppKit
import Combine
import AVFoundation
import CoreMedia

extension NSImage {
    var pngData: Data? {
        guard let t = tiffRepresentation, let r = NSBitmapImageRep(data: t) else { return nil }
        return r.representation(using: .png, properties: [:])
    }
}

@MainActor
final class Store: ObservableObject {
    static let defaultGenres = ["Comedy", "Funny", "Sad", "Random", "Action", "Romance", "Horror",
                                "Fantasy", "Sci-Fi", "Slice of Life", "Shonen", "Mecha", "Isekai",
                                "Character Design", "Background", "Colour Palette", "Pose", "FX", "Lighting"]

    @Published var items: [InspoItem] = [] { didSet { save() } }
    @Published var projects: [Project] = [] { didSet { save() } }
    @Published var pending: Pending?
    @Published var busy = false
    @Published var pickingFor: UUID?      // project id whose reference picker is open
    @Published var projectFilter: UUID?   // show only this project's refs on the board
    @Published var tab = 0                // 0 = Inspiration, 1 = Projects

    let root: URL
    let imagesDir: URL
    private var loading = true
    private let cache = NSCache<NSString, NSImage>()
    private struct DB: Codable { var items: [InspoItem]; var projects: [Project] }

    var allGenres: [String] {
        Array(Set(Self.defaultGenres + items.map(\.genre))).sorted()
    }
    var usedGenres: [String] { Array(Set(items.map(\.genre))).sorted() }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        root = base.appendingPathComponent("InspoBox")
        imagesDir = root.appendingPathComponent("Images")
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        if let d = try? Data(contentsOf: root.appendingPathComponent("library.json")),
           let db = try? JSONDecoder().decode(DB.self, from: d) {
            items = db.items; projects = db.projects
        }
        loading = false
        Notifier.setup()
        for p in projects { Notifier.schedule(p) }
    }

    private func save() {
        guard !loading else { return }
        let db = DB(items: items, projects: projects)
        if let d = try? JSONEncoder().encode(db) {
            try? d.write(to: root.appendingPathComponent("library.json"), options: .atomic)
        }
    }

    func image(for item: InspoItem) -> NSImage? {
        guard let f = item.thumbName ?? item.fileName else { return nil }
        if let c = cache.object(forKey: f as NSString) { return c }
        guard let img = NSImage(contentsOf: imagesDir.appendingPathComponent(f)) else { return nil }
        cache.setObject(img, forKey: f as NSString)
        return img
    }

    func fileURL(for item: InspoItem) -> URL? {
        item.fileName.map { imagesDir.appendingPathComponent($0) }
    }

    // MARK: Add / delete

    func commit(_ p: Pending, name: String, genre: String, tags: String) {
        let tagList = tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        var item = InspoItem(kind: .link, name: name.isEmpty ? "Untitled" : name,
                             genre: genre, tags: tagList, url: p.url?.absoluteString)
        if let v = p.videoFile {
            let file = UUID().uuidString + "." + (v.pathExtension.isEmpty ? "mp4" : v.pathExtension.lowercased())
            do { try FileManager.default.copyItem(at: v, to: imagesDir.appendingPathComponent(file)) } catch { return }
            if v.deletingLastPathComponent().standardizedFileURL == FileManager.default.temporaryDirectory.standardizedFileURL {
                try? FileManager.default.removeItem(at: v)
            }
            item.kind = .video
            item.fileName = file
            if let d = p.data, let img = NSImage(data: d) {
                let tn = UUID().uuidString + "-thumb.png"
                try? d.write(to: imagesDir.appendingPathComponent(tn))
                item.thumbName = tn
                let rep = img.representations.first
                item.width = Double(rep?.pixelsWide ?? Int(img.size.width))
                item.height = Double(rep?.pixelsHigh ?? Int(img.size.height))
            }
        } else if let d = p.data, let img = NSImage(data: d) {
            let file = UUID().uuidString + "." + Self.ext(d)
            do { try d.write(to: imagesDir.appendingPathComponent(file)) } catch { return }
            item.kind = .image
            item.fileName = file
            let rep = img.representations.first
            item.width = Double(rep?.pixelsWide ?? Int(img.size.width))
            item.height = Double(rep?.pixelsHigh ?? Int(img.size.height))
        }
        items.insert(item, at: 0)
        pending = nil
    }

    func delete(_ item: InspoItem) {
        if let u = fileURL(for: item) {
            try? FileManager.default.trashItem(at: u, resultingItemURL: nil) // goes to Bin
        }
        if let t = item.thumbName { try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(t)) }
        items.removeAll { $0.id == item.id }
        for i in projects.indices { projects[i].refIDs.removeAll { $0 == item.id } }
    }

    private static func ext(_ d: Data) -> String {
        let b = [UInt8](d.prefix(4))
        if b.starts(with: [0xFF, 0xD8]) { return "jpg" }
        if b.starts(with: [0x89, 0x50]) { return "png" }
        if b.starts(with: [0x47, 0x49]) { return "gif" }
        if b.starts(with: [0x52, 0x49]) { return "webp" }
        return "png"
    }

    // MARK: Ingest (paste / drop)

    func pasteFromClipboard() {
        let pb = NSPasteboard.general
        if let url = (pb.readObjects(forClasses: [NSURL.self]) as? [URL])?.first { handle(url: url); return }
        if let s = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: s), url.scheme?.hasPrefix("http") == true { handle(url: url); return }
        if let img = (pb.readObjects(forClasses: [NSImage.self]) as? [NSImage])?.first,
           let d = img.pngData { pending = Pending(data: d, url: nil) }
    }

    func ingest(_ providers: [NSItemProvider]) -> Bool {
        guard let p = providers.first else { return false }
        if p.canLoadObject(ofClass: NSURL.self) {
            _ = p.loadObject(ofClass: NSURL.self) { obj, _ in
                if let url = obj as? URL { Task { @MainActor in self.handle(url: url) } }
            }
            return true
        }
        if p.canLoadObject(ofClass: NSImage.self) {
            _ = p.loadObject(ofClass: NSImage.self) { obj, _ in
                if let d = (obj as? NSImage)?.pngData { Task { @MainActor in self.pending = Pending(data: d, url: nil) } }
            }
            return true
        }
        return false
    }

    static let videoExts: Set<String> = ["mp4", "mov", "m4v", "webm", "mkv", "avi"]
    nonisolated static func isVideo(_ u: URL) -> Bool { videoExts.contains(u.pathExtension.lowercased()) }

    func handle(url: URL) {
        if url.isFileURL {
            if Self.isVideo(url) { Task { await prepareVideo(url, source: nil) }; return }
            if let d = try? Data(contentsOf: url), NSImage(data: d) != nil { pending = Pending(data: d, url: nil) }
            return
        }
        let host = url.host ?? ""
        let socials = ["instagram.com", "youtube.com", "youtu.be", "tiktok.com", "twitter.com", "x.com"]
        if socials.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
            pending = Pending(data: nil, url: url); return
        }
        if Self.isVideo(url) {                                   // direct video link
            Task {
                busy = true
                defer { busy = false }
                if let local = await Self.download(url) { await prepareVideo(local, source: url) }
                else { pending = Pending(data: nil, url: url) }
            }
            return
        }
        Task {
            busy = true
            defer { busy = false }
            if let d = await Self.fetch(url) {
                if NSImage(data: d) != nil { pending = Pending(data: d, url: url); return }   // direct image
                if let html = String(data: d, encoding: .utf8) {
                    if let v = Self.ogMeta("og:video", in: html, base: url), Self.isVideo(v),
                       let local = await Self.download(v) {                                   // page with mp4
                        await prepareVideo(local, source: url); return
                    }
                    if let og = Self.ogMeta("og:image", in: html, base: url),
                       let img = await Self.fetch(og), NSImage(data: img) != nil {            // pin page
                        pending = Pending(data: img, url: url); return
                    }
                }
            }
            pending = Pending(data: nil, url: url)                                          // fallback: link
        }
    }

    func prepareVideo(_ file: URL, source: URL?) async {
        busy = true
        defer { busy = false }
        let thumb = await Self.thumbnail(for: file)
        pending = Pending(data: thumb, url: source, videoFile: file)
    }

    nonisolated private static func thumbnail(for file: URL) async -> Data? {
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: file))
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 1200, height: 1200)
        for t in [0.5, 0.0] {
            if let r = try? await gen.image(at: CMTime(seconds: t, preferredTimescale: 600)) {
                return NSBitmapImageRep(cgImage: r.image).representation(using: .png, properties: [:])
            }
        }
        return nil
    }

    nonisolated private static func download(_ url: URL) async -> URL? {
        var req = URLRequest(url: url, timeoutInterval: 180)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 Safari/605.1.15",
                     forHTTPHeaderField: "User-Agent")
        guard let (tmp, _) = try? await URLSession.shared.download(for: req) else { return nil }
        let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
        do { try FileManager.default.moveItem(at: tmp, to: dest) } catch { return nil }
        return dest
    }

    nonisolated private static func fetch(_ url: URL) async -> Data? {
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 Safari/605.1.15",
                     forHTTPHeaderField: "User-Agent")
        return try? await URLSession.shared.data(for: req).0
    }

    nonisolated private static func ogMeta(_ prop: String, in html: String, base: URL) -> URL? {
        let patterns = [
            "<meta[^>]+property=[\"']\(prop)[\"'][^>]+content=[\"']([^\"']+)[\"']",
            "<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+property=[\"']\(prop)[\"']"
        ]
        for p in patterns {
            if let re = try? NSRegularExpression(pattern: p, options: .caseInsensitive),
               let m = re.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let r = Range(m.range(at: 1), in: html) {
                let s = String(html[r]).replacingOccurrences(of: "&amp;", with: "&")
                return URL(string: s, relativeTo: base)?.absoluteURL
            }
        }
        return nil
    }
}
