import SwiftUI

/// "Stände & Jobs": one instance's plot, steered from the phone. Every action
/// is a command the script runs with the same moves it makes on its own; the
/// answer comes back on its next beat and shows as a toast.
@MainActor
struct PlotView: View {
    @EnvironmentObject var store: HubStore
    let agent: Agent

    enum Page: Hashable { case stands, jobs, items }

    @State private var page: Page = .stands
    @State private var report: PlotReport?
    @State private var loaded = false
    @State private var standSheet: PlotStand?
    @State private var jobSheet: PlotJob?
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                SegPicker(selection: $page, options: [(.stands, "Stände"), (.jobs, "Jobs"), (.items, "Items")])
                if let r = report {
                    summary(r)
                    switch page {
                    case .stands: stands(r)
                    case .jobs: jobs(r)
                    case .items: items(r)
                    }
                } else if loaded {
                    EmptyHint(icon: "square.grid.3x3", title: "Noch kein Bericht",
                              text: agent.online ? "Das Script schickt ihn spätestens in 30 Sekunden." : "Die Instanz ist offline.")
                } else {
                    ProgressView().padding(40)
                }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("Stände & Jobs")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reload() }
        .task {
            while !Task.isCancelled {
                await reload()
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
        .sheet(item: $standSheet) { stand in
            StandSheet(stand: stand, spare: report?.spare ?? [], food: report?.food ?? 0, smart: report?.smart ?? true) { cmd, args in
                await send(cmd, args)
            }
        }
        .sheet(item: $jobSheet) { job in
            JobSheet(job: job, spare: report?.spare ?? []) { cmd, args in
                await send(cmd, args)
            }
        }
    }

    // MARK: pages

    private func summary(_ r: PlotReport) -> some View {
        HStack(spacing: 10) {
            Tile(caption: "Einkommen", value: Format.number(r.income) + "/s")
            Tile(caption: "Futter", value: Format.number(r.food))
            Tile(caption: "Belegt", value: "\(r.occupied)/\(r.stands.count)")
        }
    }

    private func stands(_ r: PlotReport) -> some View {
        Card(title: "Stände", icon: "square.grid.3x3", trailing: r.age.map { "vor \(Format.duration(Double($0)))" }) {
            if !r.smart {
                note("Das Script platziert mit „The game's Equip Best“ – das hält sich nicht an „In Ruhe lassen“.")
            }
            ForEach(r.stands) { stand in
                Button { standSheet = stand } label: { StandRow(stand: stand) }
                    .buttonStyle(.plain)
                    .disabled(stand.locked && !stand.has)
                if stand.id != r.stands.last?.id { Divider().background(Theme.outline) }
            }
            if !r.placeNote.isEmpty { note("Platzierer: " + r.placeNote) }
        }
    }

    private func jobs(_ r: PlotReport) -> some View {
        Card(title: "Jobs", icon: "briefcase") {
            if r.jobs.isEmpty { note("Keine Jobs auf dem Plot gefunden.") }
            ForEach(r.jobs) { job in
                Button { jobSheet = job } label: { JobRow(job: job) }.buttonStyle(.plain)
                if job.id != r.jobs.last?.id { Divider().background(Theme.outline) }
            }
        }
    }

    @ViewBuilder
    private func items(_ r: PlotReport) -> some View {
        if r.items.isEmpty {
            EmptyHint(icon: "shippingbox", title: "Keine Items gemeldet", text: "Öffne den Rucksack im Spiel einmal, dann sieht das Script alles.")
        }
        if !r.items.boxes.isEmpty {
            Card(title: "Boxen", icon: "shippingbox.fill") {
                ForEach(r.items.boxes) { box in
                    ItemRow(item: box) {
                        HStack(spacing: 6) {
                            if box.count >= 5 { actionChip("5 öffnen") { await send("box.open", ["key": .string(box.id), "n": .number(5)]) } }
                            actionChip("1 öffnen") { await send("box.open", ["key": .string(box.id), "n": .number(1)]) }
                        }
                    }
                }
            }
        }
        if !r.items.potions.isEmpty {
            Card(title: "Tränke", icon: "drop.fill") {
                ForEach(r.items.potions) { potion in
                    ItemRow(item: potion) {
                        actionChip(potion.running ? "läuft · nochmal" : "benutzen") {
                            await send("potion.use", ["name": .string(potion.name)])
                        }
                    }
                }
            }
        }
        if !r.items.other.isEmpty {
            Card(title: "Sonstiges", icon: "bag") {
                ForEach(r.items.other) { item in ItemRow(item: item) { EmptyView() } }
            }
        }
        if !r.items.materials.isEmpty {
            Card(title: "Material", icon: "cube.fill") {
                ForEach(r.items.materials) { item in ItemRow(item: item) { EmptyView() } }
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.system(size: 12.5)).foregroundColor(Theme.faint)
    }

    private func actionChip(_ title: String, action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.accentSoft)
                .overlay(Capsule().stroke(Theme.accent.opacity(0.45), lineWidth: 1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    // MARK: talking to the script

    private func reload() async {
        if let fresh = try? await store.api.plot(agent: agent.id) { report = fresh }
        loaded = true
    }

    /// Sends one command, then waits up to half a minute for the script's answer.
    private func send(_ cmd: String, _ args: [String: JSONValue]) async {
        busy = true
        defer { busy = false }
        guard let sent = await store.call({ try await store.api.gameCommand(cmd, args: args, agent: agent.id) }) else { return }
        guard let id = sent else {
            store.say("Nicht angekommen – ist die Instanz online?")
            return
        }
        store.say("An das Script geschickt …")
        for _ in 0..<15 {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if let list = try? await store.api.outcomes(agent: agent.id), let mine = list.first(where: { $0.id == id }), mine.done {
                store.say((mine.ok ? "✓ " : "✗ ") + (mine.note.isEmpty ? (mine.ok ? "erledigt" : "ging nicht") : mine.note))
                await reload()
                return
            }
        }
        store.say("Noch keine Antwort – das Script ist vielleicht beschäftigt.")
        await reload()
    }
}

// MARK: rows

private struct StandRow: View {
    let stand: PlotStand

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(stand.has ? Theme.color(rarity: stand.rarity) : Theme.line2)
                .frame(width: 4, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(stand.has ? stand.name : (stand.locked ? "gesperrt" : "leer"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(stand.has ? Theme.text : Theme.faint)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(stand.label)
                    if stand.has { Text("· \(stand.rarity) · Lv \(stand.level)") }
                }
                .font(.system(size: 12)).foregroundColor(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 8)
            if stand.held { Image(systemName: "hand.raised.fill").foregroundColor(Theme.warn).font(.system(size: 13)) }
            else if stand.pinned { Image(systemName: "pin.fill").foregroundColor(Theme.accent).font(.system(size: 12)) }
            if stand.has {
                Text(Format.number(stand.cps) + "/s")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.text)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

private struct JobRow: View {
    let job: PlotJob

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.accent)
                .frame(width: 30, height: 30)
                .background(Theme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(job.name).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text)
                Text(job.busy ? (job.whoName.isEmpty ? "besetzt" : "\(job.whoName) · \(job.whoRarity)") : "frei")
                    .font(.system(size: 12)).foregroundColor(job.busy ? Theme.muted : Theme.warn)
            }
            Spacer()
            if job.held { Image(systemName: "hand.raised.fill").foregroundColor(Theme.warn).font(.system(size: 13)) }
            else if job.pinned { Image(systemName: "pin.fill").foregroundColor(Theme.accent).font(.system(size: 12)) }
            if job.busy && job.whoCps > 0 {
                Text(Format.number(job.whoCps) + "/s").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(Theme.text)
            }
        }
        .contentShape(Rectangle())
    }

    private var icon: String {
        switch job.kind {
        case "Gardens": return "leaf.fill"
        case "Lemon stand": return "cup.and.saucer.fill"
        case "Fishing dock": return "ferry.fill"
        default: return "briefcase.fill"
        }
    }
}

private struct ItemRow<Actions: View>: View {
    let item: ItemEntry
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.system(size: 15, weight: .medium)).foregroundColor(Theme.text)
                Text("×" + Format.number(item.count)).font(.system(size: 12)).foregroundColor(Theme.muted)
            }
            Spacer()
            actions
        }
    }
}

// MARK: sheets

/// One stand: level it, swap who stands there, take them off, leave it alone.
private struct StandSheet: View {
    let stand: PlotStand
    let spare: [SpareChar]
    let food: Double
    let smart: Bool
    let send: (String, [String: JSONValue]) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var held: Bool
    @State private var confirmPickup = false

    init(stand: PlotStand, spare: [SpareChar], food: Double, smart: Bool, send: @escaping (String, [String: JSONValue]) async -> Void) {
        self.stand = stand
        self.spare = spare
        self.food = food
        self.smart = smart
        self.send = send
        _held = State(initialValue: stand.held)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            if stand.has { RarityText(name: stand.rarity, size: 13) }
                            Text(stand.has ? stand.name : "Leerer Stand").font(.system(size: 20, weight: .bold)).foregroundColor(Theme.text)
                            Text(stand.has ? "Level \(stand.level) · \(Format.number(stand.cps))/s" : stand.label)
                                .font(.system(size: 13)).foregroundColor(Theme.muted)
                        }
                        Spacer()
                    }
                }
                .rowSurface()

                if stand.has && !stand.locked {
                    Section {
                        levelButton("+1 Level", n: .number(1), cost: stand.costOne)
                        levelButton("+5 Level", n: .number(5), cost: stand.costOne.map { $0 * 5.3 }, approx: true)
                        levelButton("+10 Level", n: .number(10), cost: stand.costTen)
                        levelButton("So weit das Futter reicht", n: .string("max"), cost: stand.costMax)
                    } header: { Text("Leveln") } footer: {
                        Text("Futter: \(Format.number(food)). Das Script läuft dafür kurz zum Stand.").foregroundColor(Theme.faint)
                    }
                    .rowSurface()
                }

                if !stand.locked {
                    Section {
                        NavigationLink {
                            SparePicker(spare: spare, title: stand.has ? "Wer kommt auf \(stand.label)?" : "Wer kommt drauf?") { char in
                                Task { await send("stand.swap", ["stand": .string(stand.id), "key": .string(char.id)]) }
                                dismiss()
                            }
                        } label: {
                            Label(stand.has ? "Tauschen …" : "Besetzen …", systemImage: "arrow.left.arrow.right")
                        }
                        if stand.has {
                            Button(role: .destructive) { confirmPickup = true } label: {
                                Label("Runternehmen", systemImage: "arrow.down.to.line")
                            }
                        }
                    } header: { Text("Wer steht hier") }
                    .rowSurface()

                    Section {
                        Toggle(isOn: Binding(get: { held }, set: { value in
                            held = value
                            Task { await send("stand.hold", ["stand": .string(stand.id), "on": .bool(value)]) }
                        })) {
                            Label("In Ruhe lassen", systemImage: "hand.raised")
                        }
                        if stand.pinned && !stand.held {
                            Button {
                                Task { await send("stand.unpin", ["stand": .string(stand.id)]) }
                                dismiss()
                            } label: { Label("Automatik darf wieder ran", systemImage: "pin.slash") }
                        }
                    } footer: {
                        Text(smart
                             ? "Der Platzierer tauscht diesen Stand dann nie – auch nach einem Neustart. Geleveled wird trotzdem. Was du hier tauschst, lässt er sowieso 6 Stunden stehen."
                             : "Achtung: das Script nutzt gerade das Equip Best des Spiels, das hält sich nicht daran.")
                            .foregroundColor(Theme.faint)
                    }
                    .tint(Theme.accent)
                    .rowSurface()
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(stand.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .confirmationDialog("\(stand.name) in den Rucksack nehmen?", isPresented: $confirmPickup, titleVisibility: .visible) {
                Button("Runternehmen", role: .destructive) {
                    Task { await send("stand.pickup", ["stand": .string(stand.id)]) }
                    dismiss()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func levelButton(_ title: String, n: JSONValue, cost: Double?, approx: Bool = false) -> some View {
        Button {
            Task { await send("stand.level", ["stand": .string(stand.id), "n": n]) }
            dismiss()
        } label: {
            HStack {
                Label(title, systemImage: "arrow.up.circle")
                Spacer()
                if let cost = cost {
                    Text((approx ? "≈ " : "") + Format.number(cost))
                        .foregroundColor(cost <= food ? Theme.muted : Theme.bad)
                }
            }
        }
        .disabled(cost == nil || (cost ?? 0) > food)
    }
}

/// One job: who works there, put someone else there, free it, leave it alone.
private struct JobSheet: View {
    let job: PlotJob
    let spare: [SpareChar]
    let send: (String, [String: JSONValue]) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var held: Bool

    init(job: PlotJob, spare: [SpareChar], send: @escaping (String, [String: JSONValue]) async -> Void) {
        self.job = job
        self.spare = spare
        self.send = send
        _held = State(initialValue: job.held)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(job.kind).font(.system(size: 13)).foregroundColor(Theme.muted)
                        Text(job.name).font(.system(size: 20, weight: .bold)).foregroundColor(Theme.text)
                        Text(job.busy ? (job.whoName.isEmpty ? "besetzt" : "\(job.whoName) · \(job.whoRarity) · Lv \(job.whoLevel)") : "frei")
                            .font(.system(size: 13)).foregroundColor(Theme.muted)
                    }
                }
                .rowSurface()

                Section {
                    NavigationLink {
                        SparePicker(spare: spare, title: "Wer arbeitet bei \(job.name)?") { char in
                            Task { await send("job.set", ["job": .string(job.id), "key": .string(char.id)]) }
                            dismiss()
                        }
                    } label: { Label(job.busy ? "Jemand anderes …" : "Besetzen …", systemImage: "arrow.left.arrow.right") }
                    if job.busy {
                        Button(role: .destructive) {
                            Task { await send("job.clear", ["job": .string(job.id)]) }
                            dismiss()
                        } label: { Label("Freimachen", systemImage: "person.crop.circle.badge.minus") }
                    }
                }
                .rowSurface()

                Section {
                    Toggle(isOn: Binding(get: { held }, set: { value in
                        held = value
                        Task { await send("job.hold", ["job": .string(job.id), "on": .bool(value)]) }
                    })) { Label("In Ruhe lassen", systemImage: "hand.raised") }
                    if job.pinned && !job.held {
                        Button {
                            Task { await send("job.unpin", ["job": .string(job.id)]) }
                            dismiss()
                        } label: { Label("Automatik darf wieder ran", systemImage: "pin.slash") }
                    }
                } footer: {
                    Text("Der Job-Verteiler fasst diesen Platz dann nie an – auch nach einem Neustart.").foregroundColor(Theme.faint)
                }
                .tint(Theme.accent)
                .rowSurface()
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(job.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}

/// The spare characters, sortable by what they earn now or what is in them.
private struct SparePicker: View {
    let spare: [SpareChar]
    let title: String
    let pick: (SpareChar) -> Void
    @State private var byPotential = false

    private var sorted: [SpareChar] {
        spare.sorted { byPotential ? $0.potential > $1.potential : $0.cps > $1.cps }
    }

    var body: some View {
        List {
            Section {
                SegPicker(selection: $byPotential, options: [(false, "Verdient jetzt"), (true, "Steckt am meisten drin")])
                    .listRowBackground(Color.clear)
            } footer: {
                Text("„Steckt am meisten drin“: Einkommen pro Level – ein starker Level-1 mit guter Mutation schlägt dann einen hoch gelevelten schwachen.")
                    .foregroundColor(Theme.faint)
            }
            Section {
                if spare.isEmpty { Text("Keine freien Charaktere gemeldet.").foregroundColor(Theme.muted) }
                ForEach(sorted) { char in
                    Button { pick(char) } label: {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 3).fill(Theme.color(rarity: char.rarity)).frame(width: 4, height: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(char.title).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text).lineLimit(1)
                                Text("\(char.rarity) · Lv \(char.level)" + (char.count > 1 ? " · ×\(char.count)" : ""))
                                    .font(.system(size: 12)).foregroundColor(Theme.muted)
                            }
                            Spacer()
                            Text(Format.number(char.cps) + "/s").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(Theme.text)
                        }
                    }
                }
            }
            .rowSurface()
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
