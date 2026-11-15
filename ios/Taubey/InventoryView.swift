import SwiftUI

/// Everything the accounts hold, three ways: the characters, what is new,
/// and the items (boxes, potions, materials) - all of them together or one
/// account at a time.
@MainActor
struct InventoryView: View {
    @EnvironmentObject var store: HubStore
    @State private var inventory: Inventory?
    @State private var game = ""
    @State private var account = ""
    @State private var search = ""
    @State private var sort = "rarity"
    @State private var page: Page = .characters
    @State private var editing: Item?
    /// bumped after a picture changed, so every row asks again
    @State private var pictures = 0
    @State private var busy = false

    enum Page: Hashable { case characters, fresh, items }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        if let inv = inventory, accounts(inv).count > 1 {
                            AccountChips(selection: $account, accounts: accounts(inv)) { name in
                                inv.rows.contains { $0.account == name && $0.online }
                            }
                        }
                        SegPicker(selection: $page, options: [(.characters, "Charaktere"), (.fresh, "Neu"), (.items, "Items")])
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 6, trailing: 0))
                }
                if let error = store.error { ErrorBanner(text: error).listRowBackground(Color.clear) }
                if let inv = inventory {
                    switch page {
                    case .characters: characters(inv)
                    case .fresh: fresh(inv)
                    case .items: items(inv)
                    }
                } else {
                    Section { ForEach(0..<7, id: \.self) { _ in SkeletonRow().rowSurface() } }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .screenBackground()
            .searchable(text: $search, prompt: "Charakter, Mutation oder Item")
            .refreshable { await load() }
            .navigationTitle("Inventar")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { sortMenu } }
            .task { await load() }
            .sheet(item: $editing) { item in
                CharacterSheet(item: item, game: game, agent: agentId, account: account) { pictures += 1 }
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func load() async {
        if let inv = await store.call({ try await store.api.inventory() }) {
            inventory = inv
            if game.isEmpty || !inv.games.contains(game) {
                // the game with the most instances first
                let counts = Dictionary(grouping: inv.rows, by: { $0.game }).mapValues { $0.count }
                game = inv.games.max { (counts[$0] ?? 0) < (counts[$1] ?? 0) } ?? ""
            }
            if !account.isEmpty && !accounts(inv).contains(account) { account = "" }
        }
    }

    /// The instance of the account picked at the top - where moves go.
    private var agentId: String? {
        guard !account.isEmpty else { return nil }
        return inventory?.rows.first { $0.game == game && $0.account == account }?.id
    }

    private func accounts(_ inv: Inventory) -> [String] {
        Array(Set(inv.rows.filter { $0.game == game }.map { $0.account })).sorted { $0.lowercased() < $1.lowercased() }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sortieren", selection: $sort) {
                Label("Seltenheit", systemImage: "sparkles").tag("rarity")
                Label("Einkommen", systemImage: "dollarsign.circle").tag("cps")
                Label("Anzahl", systemImage: "number").tag("count")
                Label("Name", systemImage: "textformat").tag("name")
            }
            if let inv = inventory, inv.games.count > 1 {
                Picker("Spiel", selection: $game) {
                    ForEach(inv.games, id: \.self) { Text($0).tag($0) }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Theme.text)
        }
        .accessibilityLabel("Sortieren")
    }

    private func matches(_ text: String...) -> Bool {
        guard !search.isEmpty else { return true }
        let q = search.lowercased()
        return text.contains { $0.lowercased().contains(q) }
    }

    // MARK: characters

    private func sorted(_ inv: Inventory) -> [Item] {
        var list = inv.merged(game: game, account: account).filter { matches($0.name, $0.mutation, $0.rarity) }
        switch sort {
        case "cps": list.sort { $0.cps > $1.cps }
        case "count": list.sort { $0.count > $1.count }
        case "name": list.sort { $0.name.lowercased() < $1.name.lowercased() }
        default:
            list.sort {
                let a = inv.rank($0.rarity), b = inv.rank($1.rarity)
                if a != b { return a > b }
                return $0.cps > $1.cps
            }
        }
        return list
    }

    @ViewBuilder
    private func characters(_ inv: Inventory) -> some View {
        let list = sorted(inv)
        if list.isEmpty {
            EmptyHint(icon: "person.3", title: "Nichts gefunden", text: emptyText(inv)).listRowBackground(Color.clear)
        } else {
            Section {
                ForEach(list) { item in
                    Button { editing = item } label: { ItemRow(item: item, game: game, bust: pictures) }
                        .buttonStyle(PressStyle(scale: 0.985))
                        .rowSurface()
                }
            } header: {
                Text("\(list.count) Sorten · \(Format.number(Double(list.reduce(0) { $0 + $1.count }))) Stück")
                    .foregroundColor(Theme.muted)
            }
        }
    }

    private func emptyText(_ inv: Inventory) -> String {
        let rows = inv.rows.filter { $0.game == game && (account.isEmpty || $0.account == account) }
        if !search.isEmpty { return "Nichts passt zu „\(search)“." }
        if rows.allSatisfy({ $0.items == nil }) {
            return "Diese Instanzen haben noch kein Inventar gemeldet. Einmal den Rucksack im Spiel öffnen hilft."
        }
        return "Der Rucksack ist leer."
    }

    // MARK: what is new

    @ViewBuilder
    private func fresh(_ inv: Inventory) -> some View {
        let list = inv.fresh(game: game, account: account).filter { matches($0.item.name, $0.item.mutation, $0.item.rarity) }
        if list.isEmpty {
            EmptyHint(icon: "sparkle", title: "Nichts Neues",
                      text: "Charaktere, die ein Account noch nie hatte, stehen hier zwei Tage lang.")
                .listRowBackground(Color.clear)
        } else {
            Section {
                ForEach(list) { entry in
                    Button { editing = entry.item } label: {
                        ItemRow(item: entry.item, game: game, bust: pictures, note: Format.ago(entry.at))
                    }
                    .buttonStyle(PressStyle(scale: 0.985))
                    .rowSurface()
                }
            } header: {
                Text("\(list.count) neu in den letzten 48 Stunden").foregroundColor(Theme.muted)
            }
        }
    }

    // MARK: items

    @ViewBuilder
    private func items(_ inv: Inventory) -> some View {
        let rows = inv.things(game: game, account: account)
        if rows.isEmpty {
            EmptyHint(icon: "shippingbox", title: "Noch keine Items",
                      text: "Das Script meldet Boxen, Tränke und Material mit seinem nächsten Bericht – spätestens in einer Minute.")
                .listRowBackground(Color.clear)
        }
        ForEach(rows) { row in
            let things = row.things ?? PlotReport.Items()
            let title = rows.count > 1 ? row.account + " · " : ""
            if !things.boxes.isEmpty {
                Section {
                    ForEach(things.boxes.filter { matches($0.name) }) { box in
                        ThingRow(entry: box, icon: "shippingbox.fill", tint: Theme.warn) {
                            if box.count >= 5 {
                                chip("5 öffnen") { _ = await store.run("box.open", args: ["key": .string(box.id), "n": .number(5)], agent: row.id) }
                            }
                            chip("1 öffnen") { _ = await store.run("box.open", args: ["key": .string(box.id), "n": .number(1)], agent: row.id) }
                        }
                        .rowSurface()
                    }
                } header: { Text(title + "Boxen").foregroundColor(Theme.muted) }
            }
            if !things.potions.isEmpty {
                Section {
                    ForEach(things.potions.filter { matches($0.name) }) { potion in
                        ThingRow(entry: potion, icon: "drop.fill", tint: Theme.accent, note: potion.running ? "läuft gerade" : nil) {
                            chip("Benutzen") { _ = await store.run("potion.use", args: ["name": .string(potion.name)], agent: row.id) }
                        }
                        .rowSurface()
                    }
                } header: { Text(title + "Tränke").foregroundColor(Theme.muted) }
            }
            if !things.other.isEmpty {
                Section {
                    ForEach(things.other.filter { matches($0.name) }) { item in
                        ThingRow(entry: item, icon: "bag.fill", tint: Theme.muted) { EmptyView() }.rowSurface()
                    }
                } header: { Text(title + "Sonstiges").foregroundColor(Theme.muted) }
            }
            if !things.materials.isEmpty {
                Section {
                    ForEach(things.materials.filter { matches($0.name) }) { item in
                        ThingRow(entry: item, icon: "cube.fill", tint: Theme.good) { EmptyView() }.rowSurface()
                    }
                } header: { Text(title + "Material").foregroundColor(Theme.muted) }
            }
        }
    }

    private func chip(_ title: String, action: @escaping () async -> Void) -> some View {
        Button {
            guard !busy else { return }
            Haptics.tap()
            Task {
                busy = true
                await action()
                busy = false
                await load()
            }
        } label: {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(Theme.text)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Theme.accentSoft)
                .overlay(Capsule().stroke(Theme.accent.opacity(0.45), lineWidth: 1))
                .clipShape(Capsule())
                .opacity(busy ? 0.5 : 1)
        }
        .buttonStyle(.borderless)
    }
}

/// One kind of character: picture, name, rarity and mutation, how many, and
/// what it earns - or, when given, a note in its place (when it showed up).
struct ItemRow: View {
    private var pictureURL: URL? {
        guard let url = HubAPI.imageURL(game: game, name: item.name) else { return nil }
        return bust == 0 ? url : URL(string: url.absoluteString + "?v=\(bust)")
    }

    let item: Item
    let game: String
    var bust: Int = 0
    var note: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: pictureURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.fill").foregroundColor(Theme.faint)
                }
            }
            .frame(width: 44, height: 44)
            .background(Theme.raised)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.color(rarity: item.rarity).opacity(0.65), lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(item.name).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text).lineLimit(1)
                    if item.locked { Image(systemName: "lock.fill").font(.system(size: 10)).foregroundColor(Theme.muted) }
                }
                HStack(spacing: 6) {
                    RarityText(name: item.rarity, size: 12)
                    if !item.mutation.isEmpty {
                        Text(item.mutation)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.text)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.accentSoft)
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text("×\(item.count)").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(Theme.text)
                if let note = note {
                    Text(note).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.accent)
                } else {
                    Text(Format.number(item.cps) + "/s").font(.system(size: 12)).foregroundColor(Theme.muted)
                }
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}

/// One item that is not a character, with what can be done with it.
struct ThingRow<Actions: View>: View {
    let entry: ItemEntry
    let icon: String
    let tint: Color
    var note: String? = nil
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(spacing: 12) {
            // the game's own picture once the script has sent it, the icon until then
            AsyncImage(url: HubAPI.itemURL(name: entry.name)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit().padding(3)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(tint)
                }
            }
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text).lineLimit(1)
                HStack(spacing: 6) {
                    Text("×" + Format.number(entry.count)).font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.muted)
                    if let note = note {
                        Text(note).font(.system(size: 11.5, weight: .semibold)).foregroundColor(Theme.good)
                    }
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) { actions }
        }
        .padding(.vertical, 2)
    }
}
