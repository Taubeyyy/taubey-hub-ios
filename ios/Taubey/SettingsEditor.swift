import SwiftUI

/// The script's own menu, rebuilt from the schema it reports: the same tabs,
/// the same boxes, the same controls. Changes are collected and sent in one
/// go - either for this instance only, or as the default every instance of
/// the game follows.
struct SettingsEditor: View {
    @EnvironmentObject var store: HubStore
    let agent: Agent

    @State private var schema: Schema?
    @State private var config: AgentConfig?
    @State private var loaded = false
    @State private var tab = ""
    @State private var changes: [String: JSONValue] = [:]
    @State private var search = ""
    @State private var sending = false
    @State private var asDefault = false

    var body: some View {
        Group {
            if !loaded {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let schema = schema, let config = config {
                editor(schema, config)
            } else {
                EmptyHint(icon: "slider.horizontal.3", title: "Noch kein Menü gemeldet",
                          text: "Das Script schickt seine Einstellungen beim ersten Beat. Lass es kurz laufen und versuch es nochmal.")
            }
        }
        .screenBackground()
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @MainActor
    private func load() async {
        let game = agent.game, id = agent.id
        // one after the other: both run on the main actor anyway, and an
        // `async let` here would read the store off it
        let schemaResult = await store.call({ try await store.api.schema(game: game) })
        let configResult = await store.call({ try await store.api.config(agent: id) })
        schema = schemaResult ?? nil
        config = configResult
        if tab.isEmpty { tab = schema?.tabs.first ?? "" }
        loaded = true
    }

    private func editor(_ schema: Schema, _ config: AgentConfig) -> some View {
        VStack(spacing: 0) {
            if search.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(schema.tabs, id: \.self) { name in
                            Button { tab = name } label: {
                                Text(name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(tab == name ? Theme.accent : Theme.surface)
                                    .foregroundColor(tab == name ? .white : Theme.text)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }
            }

            List {
                ForEach(visibleSections(schema)) { section in
                    Section {
                        ForEach(section.items.filter(matches)) { item in
                            ControlRow(item: item,
                                       value: changes[item.key] ?? config.value(item.key),
                                       own: config.overrides[item.key] != nil,
                                       changed: changes[item.key] != nil) { newValue in
                                changes[item.key] = newValue
                            }
                            .rowSurface()
                        }
                    } header: {
                        Text(search.isEmpty ? section.group : "\(section.tab) · \(section.group)").foregroundColor(Theme.muted)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .searchable(text: $search, prompt: "Einstellung suchen")

            if !changes.isEmpty { sendBar }
        }
    }

    private func visibleSections(_ schema: Schema) -> [SchemaSection] {
        if !search.isEmpty {
            return schema.sections.filter { $0.tab != "Debug" && $0.items.contains(where: matches) }
        }
        return schema.sections.filter { $0.tab == tab }
    }

    private func matches(_ item: SchemaItem) -> Bool {
        if search.isEmpty { return true }
        let q = search.lowercased()
        return item.label.lowercased().contains(q) || item.key.lowercased().contains(q) || item.tip.lowercased().contains(q)
    }

    private var sendBar: some View {
        VStack(spacing: 10) {
            SegPicker(selection: $asDefault, options: [(false, "Nur diese Instanz"), (true, "Standard fürs Spiel")])
            HStack(spacing: 10) {
                Button("Verwerfen") { changes = [:] }
                    .foregroundColor(Theme.muted)
                    .padding(.horizontal, 12)
                Button {
                    Task { await send() }
                } label: {
                    HStack {
                        Spacer()
                        if sending { ProgressView().tint(.white) } else {
                            Text("\(changes.count) Änderung\(changes.count == 1 ? "" : "en") senden").font(.system(size: 16, weight: .semibold))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 13)
                    .background(Theme.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                }
                .disabled(sending)
            }
        }
        .padding(14)
        .background(Theme.surface.ignoresSafeArea(edges: .bottom))
        .overlay(Rectangle().fill(Theme.outline).frame(height: 1), alignment: .top)
    }

    @MainActor
    private func send() async {
        sending = true
        let pending = changes, id = agent.id, game = agent.game, everyone = asDefault
        if await store.call({ try await store.api.apply(changes: pending, agent: id, game: game, asDefault: everyone) }) != nil {
            store.say(everyone ? "Als Standard gespeichert" : "Gesendet - kommt in ein paar Sekunden an")
            changes = [:]
            if let c = await store.call({ try await store.api.config(agent: id) }) { config = c }
        }
        sending = false
    }
}

/// One control from the schema.
struct ControlRow: View {
    let item: SchemaItem
    let value: JSONValue
    let own: Bool
    let changed: Bool
    let set: (JSONValue) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            control
            if !item.tip.isEmpty {
                Text(item.tip).font(.system(size: 12)).foregroundColor(Theme.muted).lineLimit(3)
            }
        }
        .padding(.vertical, 3)
    }

    private var title: some View {
        HStack(spacing: 6) {
            Text(item.label).font(.system(size: 15)).foregroundColor(Theme.text)
            if changed {
                Circle().fill(Theme.accent).frame(width: 7, height: 7)
            } else if own {
                Text("eigen").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.accent)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Theme.accentSoft).clipShape(Capsule())
            }
        }
    }

    @ViewBuilder
    private var control: some View {
        switch item.kind {
        case .toggle:
            Toggle(isOn: Binding(get: { value.bool ?? false }, set: { set(.bool($0)) })) { title }
                .tint(Theme.accent)
        case .slider:
            SliderControl(item: item, value: value.double ?? item.min, title: AnyView(title), set: set)
        case .dropdown:
            if item.multi {
                NavigationLink {
                    MultiPicker(item: item, selected: value.selection, set: set)
                } label: {
                    HStack {
                        title
                        Spacer()
                        Text(summary(value.selection)).font(.system(size: 14)).foregroundColor(Theme.muted).lineLimit(1)
                    }
                }
            } else {
                Picker(selection: Binding(get: { value.string ?? "" }, set: { set(.string($0)) })) {
                    if !item.values.contains(value.string ?? "") { Text("–").tag("") }
                    ForEach(item.values, id: \.self) { Text($0).tag($0) }
                } label: { title }
                .pickerStyle(.menu)
            }
        case .input:
            InputControl(value: value.string ?? "", title: AnyView(title), secret: item.key.lowercased().contains("webhook"), set: set)
        }
    }

    private func summary(_ chosen: Set<String>) -> String {
        if chosen.isEmpty { return "keine" }
        let known = item.values.filter { chosen.contains($0) }
        if known.count == 1 { return known[0] }
        return "\(chosen.count) gewählt"
    }
}

/// Moves freely while dragging and reports only when let go.
struct SliderControl: View {
    let item: SchemaItem
    let title: AnyView
    let set: (JSONValue) -> Void
    @State private var current: Double

    init(item: SchemaItem, value: Double, title: AnyView, set: @escaping (JSONValue) -> Void) {
        self.item = item
        self.title = title
        self.set = set
        _current = State(initialValue: min(max(value, item.min), item.max))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                title
                Spacer()
                Text(Format.slider(current, rounding: item.rounding) + item.suffix)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.accent)
            }
            Slider(value: $current, in: item.min...max(item.max, item.min + 0.0001)) { editing in
                if !editing { set(.number(Format.round(current, to: item.rounding))) }
            }
            .tint(Theme.accent)
        }
    }
}

struct InputControl: View {
    let title: AnyView
    let secret: Bool
    let set: (JSONValue) -> Void
    @State private var text: String

    init(value: String, title: AnyView, secret: Bool, set: @escaping (JSONValue) -> Void) {
        self.title = title
        self.secret = secret
        self.set = set
        _text = State(initialValue: value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            title
            Group {
                if secret { SecureField("leer", text: $text) } else { TextField("leer", text: $text) }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .font(.system(size: 14, design: .monospaced))
            .padding(10)
            .background(Theme.raised)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onSubmit { set(.string(text)) }
            .onChange(of: text) { set(.string($0)) }
        }
    }
}

struct MultiPicker: View {
    let item: SchemaItem
    let set: (JSONValue) -> Void
    @State private var chosen: Set<String>
    @State private var search = ""

    init(item: SchemaItem, selected: Set<String>, set: @escaping (JSONValue) -> Void) {
        self.item = item
        self.set = set
        _chosen = State(initialValue: selected)
    }

    private var shown: [String] {
        search.isEmpty ? item.values : item.values.filter { $0.lowercased().contains(search.lowercased()) }
    }

    var body: some View {
        List {
            Section {
                ForEach(shown, id: \.self) { value in
                    Button {
                        if chosen.contains(value) { chosen.remove(value) } else { chosen.insert(value) }
                        commit()
                    } label: {
                        HStack {
                            Text(value).foregroundColor(Theme.text)
                            Spacer()
                            if chosen.contains(value) { Image(systemName: "checkmark").foregroundColor(Theme.accent) }
                        }
                    }
                    .rowSurface()
                }
            } footer: {
                Text("\(chosen.count) von \(item.values.count) gewählt").foregroundColor(Theme.muted)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .searchable(text: $search)
        .navigationTitle(item.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Alle") { chosen = Set(item.values); commit() }
                    Button("Keine") { chosen = []; commit() }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
    }

    private func commit() {
        var out: [String: JSONValue] = [:]
        for value in chosen { out[value] = .bool(true) }
        set(.object(out))
    }
}
