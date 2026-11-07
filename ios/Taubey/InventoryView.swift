import SwiftUI

struct InventoryView: View {
    @EnvironmentObject var store: HubStore
    @State private var inventory: Inventory?
    @State private var game = ""
    @State private var account = ""
    @State private var search = ""
    @State private var sort = "rarity"

    var body: some View {
        NavigationStack {
            List {
                if let error = store.error { ErrorBanner(text: error).listRowBackground(Color.clear) }
                if let inv = inventory {
                    filters(inv)
                    let items = shown(inv)
                    if items.isEmpty {
                        EmptyHint(icon: "shippingbox", title: "Nichts gefunden",
                                  text: noItemsText(inv))
                            .listRowBackground(Color.clear)
                    } else {
                        Section {
                            ForEach(items) { item in
                                ItemRow(item: item, game: game).listRowBackground(Theme.surface)
                            }
                        } header: {
                            Text("\(items.count) Sorten · \(Format.number(Double(items.reduce(0) { $0 + $1.count }))) Stück")
                                .foregroundColor(Theme.muted)
                        }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(40).listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .screenBackground()
            .searchable(text: $search, prompt: "Charakter oder Mutation")
            .refreshable { await load() }
            .navigationTitle("Inventar")
            .task { await load() }
        }
    }

    @MainActor
    private func load() async {
        if let inv = await store.call({ try await store.api.inventory() }) {
            inventory = inv
            if game.isEmpty || !inv.games.contains(game) {
                // the game with the most instances first
                let counts = Dictionary(grouping: inv.rows, by: { $0.game }).mapValues { $0.count }
                game = inv.games.max { (counts[$0] ?? 0) < (counts[$1] ?? 0) } ?? ""
            }
        }
    }

    private func accounts(_ inv: Inventory) -> [String] {
        Array(Set(inv.rows.filter { $0.game == game }.map { $0.account })).sorted()
    }

    private func filters(_ inv: Inventory) -> some View {
        Section {
            if inv.games.count > 1 {
                Picker("Spiel", selection: $game) {
                    ForEach(inv.games, id: \.self) { Text($0).tag($0) }
                }
            }
            Picker("Account", selection: $account) {
                Text("Alle zusammen").tag("")
                ForEach(accounts(inv), id: \.self) { Text($0).tag($0) }
            }
            Picker("Sortieren", selection: $sort) {
                Text("Seltenheit").tag("rarity")
                Text("Einkommen").tag("cps")
                Text("Anzahl").tag("count")
                Text("Name").tag("name")
            }
        }
        .listRowBackground(Theme.surface)
    }

    private func shown(_ inv: Inventory) -> [Item] {
        var list = inv.merged(game: game, account: account)
        if !search.isEmpty {
            let q = search.lowercased()
            list = list.filter { $0.name.lowercased().contains(q) || $0.mutation.lowercased().contains(q) || $0.rarity.lowercased().contains(q) }
        }
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

    private func noItemsText(_ inv: Inventory) -> String {
        let rows = inv.rows.filter { $0.game == game && (account.isEmpty || $0.account == account) }
        if !search.isEmpty { return "Nichts passt zu „\(search)“." }
        if rows.allSatisfy({ $0.items == nil }) {
            return "Diese Instanzen haben noch kein Inventar gemeldet. Einmal den Rucksack im Spiel öffnen hilft."
        }
        return "Der Rucksack ist leer."
    }
}

struct ItemRow: View {
    let item: Item
    let game: String

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: HubAPI.imageURL(game: game, name: item.name)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.fill").foregroundColor(Theme.muted)
                }
            }
            .frame(width: 44, height: 44)
            .background(Theme.raised)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.color(rarity: item.rarity).opacity(0.6), lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text).lineLimit(1)
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
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("×\(item.count)").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(Theme.text)
                Text(Format.number(item.cps) + "/s").font(.system(size: 12)).foregroundColor(Theme.muted)
            }
        }
        .padding(.vertical, 2)
    }
}
