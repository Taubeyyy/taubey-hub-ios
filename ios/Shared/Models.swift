import Foundation

// Every model is built from a JSONValue by hand. Shapes come from
// taubey-hub/api/agents.js and real rows of its database (2026-11-08); see
// Tests/Fixtures.swift for the recorded answers.

struct Agent: Identifiable, Hashable {
    let id: String
    let account: String
    let game: String
    let group: String
    let stats: [String: JSONValue]
    let metrics: [String: JSONValue]
    let overrides: Int
    let pending: Int
    let age: Int?
    let uptime: Int?
    let online: Bool

    init?(_ j: JSONValue) {
        guard let id = j["id"].string, !id.isEmpty else { return nil }
        self.id = id
        account = j["account"].string ?? "?"
        game = j["game"].string ?? "?"
        group = j["group"].string ?? ""
        stats = j["stats"].object ?? [:]
        metrics = j["metrics"].object ?? [:]
        overrides = j["overrides"].int ?? 0
        pending = j["pending"].int ?? 0
        age = j["age"].int
        uptime = j["uptime"].int
        online = j["online"].bool ?? false
    }

    func metric(_ key: String) -> Double { metrics[key]?.double ?? 0 }
    func stat(_ key: String) -> String? { stats[key]?.string }

    var paused: Bool { metrics["paused"]?.bool ?? stats["paused"]?.bool ?? false }

    /// What the script says it is doing right now.
    var note: String {
        if paused { return "Pausiert" }
        return stat("note") ?? metrics["fishing"]?.string ?? ""
    }

    /// The readable lines the script sends, in the order its overlay uses.
    var statLines: [(String, String)] {
        let order = ["Runtime", "Cash/s", "Gems/min", "Casts/min", "Catches", "Cash", "Food", "Rebirths",
                     "Next rebirth", "Next rod", "Fishing", "Feeding"]
        var out: [(String, String)] = []
        var used = Set<String>(["note", "paused"])
        for key in order {
            if let v = stats[key]?.string { out.append((key, v)); used.insert(key) }
        }
        for key in stats.keys.sorted() where !used.contains(key) {
            if let v = stats[key]?.string { out.append((key, v)) }
        }
        return out
    }
}

struct NextRebirth: Hashable {
    let account: String
    let cost: Double
    let short: Double
    let eta: Double?

    init?(_ j: JSONValue) {
        guard j.object != nil, let cost = j["cost"].double else { return nil }
        account = j["account"].string ?? "?"
        self.cost = cost
        short = j["short"].double ?? 0
        eta = j["eta"].double
    }
}

struct HubEvent: Identifiable, Hashable {
    let id: String
    let kind: String
    let title: String
    let detail: String
    let account: String
    let game: String
    let at: Date

    init?(_ j: JSONValue) {
        guard let at = j["at"].double else { return nil }
        // seconds from the api; a millisecond value would be far in the future
        let seconds = at > 1e11 ? at / 1000 : at
        self.at = Date(timeIntervalSince1970: seconds)
        kind = j["kind"].string ?? ""
        title = j["title"].string ?? ""
        detail = j["detail"].string ?? ""
        account = j["account"].string ?? ""
        game = j["game"].string ?? ""
        id = j["id"].string ?? "\(seconds)-\(kind)-\(title)"
    }
}

struct AgentGroup: Hashable {
    let name: String
    let online: Int
    let total: Int
}

struct Overview {
    let who: String
    let online: Int
    let total: Int
    let cash: Double
    let gems: Double
    let cashPerSec: Double
    let gemsPerMin: Double
    let catches: Double
    let catchesPerMin: Double
    let rebirths: Double
    let nextRebirth: NextRebirth?
    let rarities: [String: Double]
    let ladder: [String]
    let groups: [AgentGroup]
    let events: [HubEvent]
    let agents: [Agent]

    init(_ j: JSONValue) {
        let t = j["totals"]
        who = j["who"].string ?? ""
        online = t["online"].int ?? 0
        total = t["total"].int ?? 0
        cash = t["cash"].double ?? 0
        gems = t["gems"].double ?? 0
        cashPerSec = t["cashPerSec"].double ?? 0
        gemsPerMin = t["gemsPerMin"].double ?? 0
        catches = t["catches"].double ?? 0
        catchesPerMin = t["catchesPerMin"].double ?? 0
        rebirths = t["rebirths"].double ?? 0
        nextRebirth = NextRebirth(t["nextRebirth"])
        var r: [String: Double] = [:]
        for (k, v) in j["rarities"].object ?? [:] { if let n = v.double { r[k] = n } }
        rarities = r
        ladder = j["ladder"].strings
        groups = (j["groups"].array ?? []).map {
            AgentGroup(name: $0["name"].string ?? "", online: $0["online"].int ?? 0, total: $0["total"].int ?? 0)
        }
        events = (j["events"].array ?? []).compactMap(HubEvent.init)
        agents = (j["agents"].array ?? []).compactMap(Agent.init)
    }

    /// Rarities best first: the ladder reversed, then anything it does not know.
    var raritiesBestFirst: [RarityCount] {
        var out: [RarityCount] = []
        for name in ladder.reversed() { if let n = rarities[name], n > 0 { out.append(RarityCount(name: name, count: n)) } }
        for (name, n) in rarities.sorted(by: { $0.key < $1.key }) where !ladder.contains(name) && n > 0 {
            out.append(RarityCount(name: name, count: n))
        }
        return out
    }
}

struct RarityCount: Identifiable, Hashable {
    let name: String
    let count: Double
    var id: String { name }
}

struct Item: Identifiable, Hashable {
    let name: String
    let rarity: String
    let mutation: String
    var count: Int
    let level: Int
    let cps: Double
    var accounts: Set<String>

    var id: String { name + "|" + mutation }

    init?(_ j: JSONValue, account: String) {
        guard let name = j["name"].string, !name.isEmpty else { return nil }
        self.name = name
        rarity = j["rarity"].string ?? "Unknown"
        mutation = j["mutation"].string ?? ""
        count = max(1, j["count"].int ?? 1)
        level = j["level"].int ?? 0
        cps = j["cps"].double ?? 0
        accounts = [account]
    }
}

struct InventoryRow: Identifiable, Hashable {
    let id: String
    let account: String
    let game: String
    let online: Bool
    let age: Int?
    /// nil = this instance never reported a bag, which is not the same as empty
    let items: [Item]?
    /// Kinds new in the last two days (name|mutation -> when they showed up).
    let fresh: [String: Date]
    /// Boxes, potions, other items, materials - from the plot report.
    let things: PlotReport.Items?

    init?(_ j: JSONValue) {
        guard let id = j["id"].string else { return nil }
        self.id = id
        account = j["account"].string ?? "?"
        game = j["game"].string ?? "?"
        online = j["online"].bool ?? false
        age = j["age"].int
        let acc = account
        items = j["items"].array.map { $0.compactMap { Item($0, account: acc) } }
        var f: [String: Date] = [:]
        for (key, value) in j["fresh"].object ?? [:] {
            if let at = value.double, at > 0 { f[key] = Date(timeIntervalSince1970: at) }
        }
        fresh = f
        things = j["things"].object != nil ? PlotReport.Items(j["things"]) : nil
    }
}

/// A kind of character that showed up recently, and when.
struct FreshItem: Identifiable, Hashable {
    let item: Item
    let at: Date
    var id: String { item.id }
}

struct Inventory {
    let rows: [InventoryRow]
    let ladder: [String]

    init(_ j: JSONValue) {
        rows = (j["rows"].array ?? []).compactMap(InventoryRow.init)
        ladder = j["ladder"].strings
    }

    var games: [String] { Array(Set(rows.map { $0.game })).sorted() }

    /// One list for the picked game and account ("" = every account), the same
    /// character with the same mutation added up across accounts.
    func merged(game: String, account: String) -> [Item] {
        var byId: [String: Item] = [:]
        for row in rows where row.game == game && (account.isEmpty || row.account == account) {
            for item in row.items ?? [] {
                if var have = byId[item.id] {
                    have.count += item.count
                    have.accounts.formUnion(item.accounts)
                    byId[item.id] = have
                } else {
                    byId[item.id] = item
                }
            }
        }
        return Array(byId.values)
    }

    func rank(_ rarity: String) -> Int { ladder.firstIndex(of: rarity) ?? -1 }

    /// What is new in the picked game and account, newest first: kinds that
    /// were not in the bag before (the server keeps when each first showed up).
    func fresh(game: String, account: String) -> [FreshItem] {
        var when: [String: Date] = [:]
        for row in rows where row.game == game && (account.isEmpty || row.account == account) {
            for (key, at) in row.fresh where when[key].map({ at > $0 }) ?? true { when[key] = at }
        }
        return merged(game: game, account: account)
            .compactMap { item in when[item.id].map { FreshItem(item: item, at: $0) } }
            .sorted { $0.at > $1.at }
    }

    /// The instances of the picked game and account that sent their items.
    func things(game: String, account: String) -> [InventoryRow] {
        rows.filter { $0.game == game && (account.isEmpty || $0.account == account) && $0.things != nil }
    }
}

// MARK: - settings schema

enum ControlKind: String {
    case toggle = "Toggle", slider = "Slider", dropdown = "Dropdown", input = "Input"
}

struct SchemaItem: Identifiable, Hashable {
    let key: String
    let kind: ControlKind
    let label: String
    let tip: String
    let min: Double
    let max: Double
    let rounding: Int
    let suffix: String
    let values: [String]
    let multi: Bool

    var id: String { key }

    init?(_ j: JSONValue) {
        guard let key = j["key"].string, let kind = ControlKind(rawValue: j["type"].string ?? "") else { return nil }
        self.key = key
        self.kind = kind
        label = j["label"].string ?? key
        tip = j["tip"].string ?? ""
        min = j["min"].double ?? 0
        max = Swift.max(j["max"].double ?? 100, j["min"].double ?? 0)
        rounding = j["rounding"].int ?? 0
        suffix = j["suffix"].string ?? ""
        values = j["values"].strings
        multi = j["multi"].bool ?? false
    }
}

struct SchemaSection: Identifiable, Hashable {
    let tab: String
    let group: String
    let items: [SchemaItem]
    var id: String { tab + "|" + group }
}

struct Schema {
    let sections: [SchemaSection]

    init?(_ j: JSONValue) {
        guard let list = j["sections"].array else { return nil }
        sections = list.compactMap { s in
            let items = (s["items"].array ?? []).compactMap(SchemaItem.init)
            if items.isEmpty { return nil }
            return SchemaSection(tab: s["tab"].string ?? "Other", group: s["group"].string ?? "", items: items)
        }
    }

    /// Tabs in the order the menu has them. Debug is for the menu only.
    var tabs: [String] {
        var seen = Set<String>(), out: [String] = []
        for s in sections where s.tab != "Debug" && !seen.contains(s.tab) {
            seen.insert(s.tab)
            out.append(s.tab)
        }
        return out
    }
}

struct AgentConfig {
    let current: [String: JSONValue]
    let overrides: [String: JSONValue]
    let defaults: [String: JSONValue]

    init(_ j: JSONValue) {
        current = j["current"].object ?? [:]
        overrides = j["overrides"].object ?? [:]
        defaults = j["defaults"].object ?? [:]
    }

    init(current: [String: JSONValue], overrides: [String: JSONValue], defaults: [String: JSONValue]) {
        self.current = current
        self.overrides = overrides
        self.defaults = defaults
    }

    /// What the instance is set to run with: its own setting, else the game
    /// default (which the server sends to it), else what it last reported.
    func value(_ key: String) -> JSONValue {
        overrides[key] ?? defaults[key] ?? current[key] ?? .null
    }
}

struct HistoryPoint: Identifiable, Hashable {
    let date: Date
    let value: Double
    var id: Double { date.timeIntervalSince1970 }
}

func parseHistory(_ j: JSONValue) -> [HistoryPoint] {
    (j["points"].array ?? []).compactMap { p in
        guard let t = p["t"].double, let v = p["v"].double else { return nil }
        return HistoryPoint(date: Date(timeIntervalSince1970: t > 1e11 ? t / 1000 : t), value: v)
    }
}
