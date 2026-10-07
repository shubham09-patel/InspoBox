import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject var store: Store
    @State private var newTitle = ""

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                TextField("New reel / project name", text: $newTitle)
                    .textFieldStyle(.plain).padding(10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .onSubmit(add)
                Button("Add", action: add)
            }
            if store.projects.isEmpty {
                Spacer()
                Text("No projects yet. Add your first reel!").foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach($store.projects) { $p in
                            ProjectCard(project: $p) {
                                Notifier.cancel(p.id)
                                store.projects.removeAll { $0.id == p.id }
                            }
                        }
                    }
                }
            }
        }
    }

    func add() {
        let t = newTitle.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        var p = Project(title: t)
        p.set(.script)
        store.projects.insert(p, at: 0)
        newTitle = ""
    }
}

struct ProjectCard: View {
    @EnvironmentObject var store: Store
    @Binding var project: Project
    var onDelete: () -> Void

    var refs: [InspoItem] { store.refs(of: project) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(project.title).font(.headline)
                Spacer()
                Menu(project.phase.rawValue) {
                    ForEach(Phase.allCases) { ph in Button(ph.rawValue) { project.set(ph) } }
                }.fixedSize()
                Button(action: onDelete) { Image(systemName: "trash") }.buttonStyle(.plain)
            }
            HStack(spacing: 3) {
                ForEach(Phase.allCases) { ph in
                    Capsule().fill(ph.index <= project.phase.index ? Color.accentColor : Color.white.opacity(0.15))
                        .frame(height: 5)
                }
            }
            HStack {
                Text(statusText).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let d = deadlineInfo { Text(d.0).font(.caption.bold()).foregroundStyle(d.1) }
            }

            TextField("Notes…", text: $project.notes, axis: .vertical)
                .textFieldStyle(.plain).font(.callout).lineLimit(1...4)

            Divider().opacity(0.4)
            referencesSection
            Divider().opacity(0.4)
            deadlineSection

            HStack {
                if let n = project.phase.next {
                    Button("Next → \(n.rawValue)") { project.advance() }
                } else {
                    DatePicker("Upload date", selection: Binding(
                        get: { project.uploadDate ?? Date() },
                        set: { project.uploadDate = $0 }), displayedComponents: .date)
                        .font(.caption)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .onChange(of: project.deadline) { _, _ in Notifier.schedule(project) }
        .onChange(of: project.remind) { _, _ in Notifier.schedule(project) }
        .onChange(of: project.phase) { _, _ in Notifier.schedule(project) }
    }

    // MARK: References

    var referencesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("References · \(refs.count)", systemImage: "photo.stack").font(.caption.bold())
                Spacer()
                if !refs.isEmpty {
                    Button("View on board") { store.projectFilter = project.id; store.tab = 0 }
                        .buttonStyle(.link).font(.caption)
                }
                Button("Add / remove") { store.pickingFor = project.id }
                    .buttonStyle(.link).font(.caption)
            }
            if refs.isEmpty {
                Text("No refs linked yet — add some for this reel.").font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(refs) { item in
                            ThumbView(item: item, size: 70)
                                .onTapGesture { store.open(item) }
                                .help("\(item.name) · \(item.genre)")
                                .contextMenu {
                                    Button("Remove from project") { store.toggle(item, in: project.id) }
                                }
                        }
                    }
                }
            }
        }
    }

    // MARK: Deadline

    var deadlineSection: some View {
        HStack {
            Toggle("Deadline", isOn: Binding(
                get: { project.deadline != nil },
                set: { on in
                    project.deadline = on ? Calendar.current.date(byAdding: .day, value: 7, to: Date()) : nil
                    if !on { project.remind = false }
                }))
                .toggleStyle(.switch).controlSize(.small).font(.caption)
            if project.deadline != nil {
                DatePicker("", selection: Binding(
                    get: { project.deadline ?? Date() },
                    set: { project.deadline = $0 }), displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden().controlSize(.small)
                Spacer()
                Toggle(isOn: $project.remind) { Label("Remind", systemImage: "bell.fill").font(.caption) }
                    .toggleStyle(.switch).controlSize(.small)
            } else {
                Spacer()
            }
        }
    }

    var deadlineInfo: (String, Color)? {
        guard let d = project.deadline, project.phase != .uploaded else { return nil }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: d)).day ?? 0
        switch days {
        case ..<0: return ("Overdue by \(-days)d", .red)
        case 0: return ("Due today", .orange)
        case 1: return ("Due tomorrow", .orange)
        default: return ("\(days) days left", .green)
        }
    }

    var statusText: String {
        let d = project.phaseDates[project.phase.rawValue] ?? project.created
        let ds = d.formatted(date: .abbreviated, time: .omitted)
        return "Phase \(project.phase.index + 1) of \(Phase.allCases.count) · since \(ds)"
    }
}

// MARK: Shared thumbnail + reference picker

struct ThumbView: View {
    @EnvironmentObject var store: Store
    let item: InspoItem
    let size: CGFloat

    var body: some View {
        Group {
            if let img = store.image(for: item) {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Image(systemName: "link").foregroundStyle(.tint)
                }
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay { if item.kind == .video { Image(systemName: "play.circle.fill").foregroundStyle(.white.opacity(0.9)).shadow(radius: 2) } }
    }
}

struct RefPicker: View {
    @EnvironmentObject var store: Store
    let projectID: UUID
    @State private var query = ""

    var project: Project? { store.projects.first { $0.id == projectID } }
    var items: [InspoItem] {
        store.items.filter {
            query.isEmpty || [$0.name, $0.genre, $0.tags.joined(separator: " ")]
                .joined(separator: " ").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().onTapGesture { store.pickingFor = nil }
            VStack(spacing: 10) {
                HStack {
                    Text("References for “\(project?.title ?? "")”").font(.headline)
                    Spacer()
                    Button("Done") { store.pickingFor = nil }.keyboardShortcut(.defaultAction)
                }
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search…", text: $query).textFieldStyle(.plain)
                }
                .padding(8).background(.ultraThinMaterial, in: Capsule())

                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(items) { item in
                            let on = project?.refIDs.contains(item.id) == true
                            ThumbView(item: item, size: 108)
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(on ? Color.accentColor : .white.opacity(0.8))
                                        .padding(5).shadow(radius: 2)
                                }
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(on ? Color.accentColor : .clear, lineWidth: 2))
                                .onTapGesture { store.toggle(item, in: projectID) }
                        }
                    }
                }
            }
            .padding(16).frame(width: 500, height: 520)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(radius: 20)
        }
    }
}
