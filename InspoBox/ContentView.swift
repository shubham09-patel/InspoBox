import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @Environment(\.openWindow) private var openWindow
    @State private var query = ""
    @State private var genre: String?
    @State private var targeted = false

    var filtered: [InspoItem] {
        store.items.filter { i in
            (genre == nil || i.genre == genre) &&
            (store.projectFilter == nil || store.projects.first(where: { $0.id == store.projectFilter })?.refIDs.contains(i.id) == true) &&
            (query.isEmpty || [i.name, i.genre, i.url ?? "", i.tags.joined(separator: " ")]
                .joined(separator: " ").localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        ZStack {
            VisualEffect().ignoresSafeArea()
            VStack(spacing: 10) {
                header
                if store.tab == 0 { inspiration } else { ProjectsView() }
            }
            .padding(14)

            if targeted {
                RoundedRectangle(cornerRadius: 18).strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundStyle(.tint).padding(6)
                    .overlay(Text("Drop image or link").font(.title3.bold()))
                    .allowsHitTesting(false)
            }
            if store.busy { ProgressView().controlSize(.large).padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)) }
            if let pid = store.pickingFor { RefPicker(projectID: pid) }
            if let p = store.pending { SaveSheet(pending: p).id(p.id) }
        }
        .onDrop(of: [.fileURL, .url, .image], isTargeted: $targeted) { store.ingest($0) }
    }

    var header: some View {
        HStack {
            Picker("", selection: $store.tab) {
                Text("Inspiration").tag(0)
                Text("Projects").tag(1)
            }.pickerStyle(.segmented).labelsHidden().frame(width: 220)
            Spacer()
            Button { store.pasteFromClipboard() } label: { Label("Paste", systemImage: "doc.on.clipboard") }
            Button {
                openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true)
            } label: { Image(systemName: "macwindow") }.help("Open as window (drag & drop works here)")
        }
    }

    var inspiration: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search name, tag, genre…", text: $query).textFieldStyle(.plain)
            }
            .padding(10).background(.ultraThinMaterial, in: Capsule())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if !store.projects.isEmpty {
                        Menu {
                            Button("All projects") { store.projectFilter = nil }
                            ForEach(store.projects) { p in Button(p.title) { store.projectFilter = p.id } }
                        } label: {
                            Label(store.projects.first(where: { $0.id == store.projectFilter })?.title ?? "Project",
                                  systemImage: "film")
                                .font(.caption.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 5)
                                .background(store.projectFilter == nil ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.accentColor), in: Capsule())
                        }
                        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    }
                    chip("All", genre == nil) { genre = nil }
                    ForEach(store.usedGenres, id: \.self) { g in chip(g, genre == g) { genre = g } }
                }
            }

            if filtered.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 40)).foregroundStyle(.secondary)
                    Text("Copy an image or link, then hit Paste").foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView(showsIndicators: false) { Masonry(items: filtered, columns: 3) }
            }
        }
    }

    func chip(_ t: String, _ on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.caption.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 5)
                .background(on ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.ultraThinMaterial), in: Capsule())
        }.buttonStyle(.plain)
    }
}

// MARK: Masonry

struct Masonry: View {
    let items: [InspoItem]
    let columns: Int

    var body: some View {
        let cols = split()
        HStack(alignment: .top, spacing: 8) {
            ForEach(0..<columns, id: \.self) { c in
                LazyVStack(spacing: 8) { ForEach(cols[c]) { ItemCard(item: $0) } }
            }
        }
    }

    func split() -> [[InspoItem]] {
        var out = Array(repeating: [InspoItem](), count: columns)
        var h = Array(repeating: 0.0, count: columns)
        for i in items {
            let k = h.firstIndex(of: h.min()!)!
            out[k].append(i); h[k] += i.aspect + 0.1
        }
        return out
    }
}

struct ItemCard: View {
    @EnvironmentObject var store: Store
    let item: InspoItem
    @State private var hover = false

    var body: some View {
        ZStack {
            content
            if hover { overlay }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.15)))
        .onHover { hover = $0 }
        .onTapGesture { open() }
        .contextMenu {
            if item.kind == .image, let img = store.image(for: item) {
                Button("Copy Image") { NSPasteboard.general.clearContents(); NSPasteboard.general.writeObjects([img]) }
            }
            if item.url != nil { Button("Open Source Link") { openLink() } }
            if let u = store.fileURL(for: item) {
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([u]) }
            }
            if !store.projects.isEmpty {
                Menu("Add to Project") {
                    ForEach(store.projects) { p in
                        Button { store.toggle(item, in: p.id) } label: {
                            if p.refIDs.contains(item.id) { Label(p.title, systemImage: "checkmark") } else { Text(p.title) }
                        }
                    }
                }
            }
            Divider()
            Button("Delete (move to Bin)", role: .destructive) { store.delete(item) }
        }
    }

    @ViewBuilder var content: some View {
        if let img = store.image(for: item) {
            Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
                .overlay { if item.kind == .video { playBadge } }
        } else {
            VStack(spacing: 6) {
                Image(systemName: item.kind == .video ? "film.fill" : "link.circle.fill").font(.system(size: 28)).foregroundStyle(.tint)
                Text(item.kind == .video ? "video" : (URL(string: item.url ?? "")?.host ?? "link")).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .background(.ultraThinMaterial)
        }
    }

    var playBadge: some View {
        Image(systemName: "play.circle.fill").font(.system(size: 34))
            .foregroundStyle(.white.opacity(0.9)).shadow(radius: 4)
    }

    var overlay: some View {
        VStack {
            HStack {
                Spacer()
                Button { store.delete(item) } label: {
                    Image(systemName: "trash.fill").padding(6).background(.black.opacity(0.55), in: Circle())
                }.buttonStyle(.plain).foregroundStyle(.white)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(.caption.bold()).lineLimit(1)
                Text(item.genre).font(.caption2).opacity(0.8)
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.65)], startPoint: .top, endPoint: .bottom))
    }

    func open() {
        if let u = store.fileURL(for: item) { NSWorkspace.shared.open(u) } else { openLink() }
    }
    func openLink() {
        if let s = item.url, let u = URL(string: s) { NSWorkspace.shared.open(u) }
    }
}

// MARK: Save form

struct SaveSheet: View {
    @EnvironmentObject var store: Store
    let pending: Pending
    @State private var name = ""
    @State private var genre = "Random"
    @State private var custom = ""
    @State private var tags = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().onTapGesture { store.pending = nil }
            VStack(spacing: 10) {
                if let d = pending.data, let img = NSImage(data: d) {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 160).clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay { if pending.videoFile != nil { Image(systemName: "play.circle.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.9)) } }
                } else {
                    Label(pending.videoFile?.lastPathComponent ?? pending.url?.absoluteString ?? "Link",
                          systemImage: pending.videoFile != nil ? "film" : "link").lineLimit(2).font(.caption)
                }
                TextField("1. Reference name", text: $name).textFieldStyle(.roundedBorder)
                HStack {
                    Picker("2. Genre", selection: $genre) { ForEach(store.allGenres, id: \.self) { Text($0) } }
                    TextField("or new genre", text: $custom).textFieldStyle(.roundedBorder)
                }
                TextField("3. Tags (comma separated)", text: $tags).textFieldStyle(.roundedBorder)
                HStack {
                    Button("Cancel") { store.pending = nil }
                    Spacer()
                    Button("Save") {
                        let g = custom.trimmingCharacters(in: .whitespaces)
                        store.commit(pending, name: name, genre: g.isEmpty ? genre : g, tags: tags)
                    }.keyboardShortcut(.defaultAction)
                }
            }
            .padding(16).frame(width: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(radius: 20)
        }
        .onAppear { name = pending.url?.host?.replacingOccurrences(of: "www.", with: "") ?? "" }
    }
}
