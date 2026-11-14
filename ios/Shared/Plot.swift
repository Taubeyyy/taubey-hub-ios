import Foundation

/// One instance's plot as its script reports it (GET /api/agent/:id/plot):
/// who stands where, the jobs, the spare characters worth placing, and the
/// items. The script sends it every 30 seconds when something changed, and
/// straight after every command.
struct PlotReport {
    let plot: String
    let food: Double
    let cash: Double
    let gems: Double
    let stands: [PlotStand]
    let jobs: [PlotJob]
    let spare: [SpareChar]
    let items: Items
    /// The placer's own last word.
    let placeNote: String
    /// Smart placing is on: pins and holds count only for it.
    let smart: Bool
    /// Seconds since the script sent it.
    let age: Int?

    /// Everything that is not a character: boxes, potions, other items, materials.
    struct Items: Hashable {
        var boxes: [ItemEntry] = []
        var potions: [ItemEntry] = []
        var other: [ItemEntry] = []
        var materials: [ItemEntry] = []
        var isEmpty: Bool { boxes.isEmpty && potions.isEmpty && other.isEmpty && materials.isEmpty }

        init() {}

        init(_ i: JSONValue) {
            boxes = (i["boxes"].array ?? []).compactMap(ItemEntry.init)
            potions = (i["potions"].array ?? []).compactMap(ItemEntry.init)
            other = (i["items"].array ?? []).compactMap(ItemEntry.init)
            materials = (i["materials"].array ?? []).compactMap(ItemEntry.init)
        }
    }

    /// nil when the script has not sent one yet.
    init?(_ answer: JSONValue) {
        let p = answer["plot"]
        guard p.object != nil else { return nil }
        plot = p["plot"].string ?? ""
        food = p["food"].double ?? 0
        cash = p["cash"].double ?? 0
        gems = p["gems"].double ?? 0
        stands = (p["stands"].array ?? []).compactMap(PlotStand.init)
        jobs = (p["jobs"].array ?? []).compactMap(PlotJob.init)
        spare = (p["spare"].array ?? []).compactMap(SpareChar.init)
        items = Items(p["items"])
        placeNote = p["place"].string ?? ""
        smart = p["smart"].bool ?? true
        age = answer["age"].int
    }

    var occupied: Int { stands.filter { $0.has }.count }
    var income: Double { stands.reduce(0) { $0 + ($1.has ? $1.cps : 0) } }
}

struct PlotStand: Identifiable, Equatable {
    let id: String
    let has: Bool
    let name: String
    let rarity: String
    let level: Int
    let cps: Double
    let locked: Bool
    /// Set from the app a little while ago: the placer leaves it for six hours.
    let pinned: Bool
    /// "Leave it alone" switched on: the placer never swaps it.
    let held: Bool
    let costOne: Double?
    let costTen: Double?
    let costMax: Double?

    init?(_ j: JSONValue) {
        guard let id = j["id"].string, !id.isEmpty else { return nil }
        self.id = id
        has = j["has"].bool ?? false
        name = j["name"].string ?? ""
        rarity = j["rarity"].string ?? ""
        level = j["level"].int ?? 0
        cps = j["cps"].double ?? 0
        locked = j["locked"].bool ?? false
        pinned = j["pinned"].bool ?? false
        held = j["held"].bool ?? false
        costOne = j["one"].double
        costTen = j["ten"].double
        costMax = j["max"].double
    }

    /// The stand's number, for putting them in order: "Purchases.17" -> 17.
    var number: Int {
        let last = id.components(separatedBy: ".").last ?? id
        return Int(last.filter { $0.isNumber }) ?? Int.max
    }

    /// "5" for the corner of a tile.
    var shortNumber: String { number == Int.max ? id : String(number) }

    /// "Purchases.5PAID" reads as "Stand 5 · bezahlt", "1" as "Stand 1".
    var label: String {
        var short = id.components(separatedBy: ".").last ?? id
        var paid = false
        if short.hasSuffix("PAID") {
            short = String(short.dropLast(4))
            paid = true
        }
        return "Stand " + short + (paid ? " · bezahlt" : "")
    }
}

struct PlotJob: Identifiable, Equatable {
    /// The script's kind of job, in German.
    static func kindName(_ kind: String) -> String {
        ["Gardens": "Garten", "Lemon stand": "Limonadenstand", "Fishing dock": "Angelsteg", "Other stands": "Stand"][kind] ?? kind
    }

    let id: String
    let name: String
    let kind: String
    let busy: Bool
    let pinned: Bool
    let held: Bool
    let whoName: String
    let whoRarity: String
    let whoCps: Double
    let whoLevel: Int

    init?(_ j: JSONValue) {
        guard let id = j["id"].string, !id.isEmpty else { return nil }
        self.id = id
        name = j["name"].string ?? id
        kind = j["kind"].string ?? ""
        busy = j["busy"].bool ?? false
        pinned = j["pinned"].bool ?? false
        held = j["held"].bool ?? false
        whoName = j["who"]["name"].string ?? ""
        whoRarity = j["who"]["rarity"].string ?? ""
        whoCps = j["who"]["cps"].double ?? 0
        whoLevel = j["who"]["level"].int ?? 0
    }
}

struct SpareChar: Identifiable, Equatable {
    /// The bag key (C|Name|Mutation or C|Name|Mutation|L297) - what the script moves.
    let id: String
    let name: String
    let rarity: String
    let mutation: String
    let level: Int
    let cps: Double
    let count: Int

    init?(_ j: JSONValue) {
        guard let key = j["key"].string, !key.isEmpty else { return nil }
        id = key
        name = j["name"].string ?? ""
        rarity = j["rarity"].string ?? ""
        mutation = j["mutation"].string ?? ""
        level = j["level"].int ?? 0
        cps = j["cps"].double ?? 0
        count = j["count"].int ?? 1
    }

    /// Income for its level: a strong level-1 against a levelled one
    /// (income climbs about in step with the level).
    var potential: Double { cps / (Double(level) + 1.6) }
    var title: String { mutation.isEmpty ? name : "\(name) [\(mutation)]" }
}

struct ItemEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let count: Double
    let running: Bool

    init?(_ j: JSONValue) {
        guard let name = j["name"].string, !name.isEmpty else { return nil }
        id = j["key"].string ?? name
        self.name = name
        count = j["count"].double ?? 0
        running = j["running"].bool ?? false
    }
}

/// What one command from the app came to (GET /api/agent/:id/commands).
struct CommandOutcome: Equatable {
    let id: Int
    let done: Bool
    let ok: Bool
    let note: String

    init?(_ j: JSONValue) {
        guard let id = j["id"].int else { return nil }
        self.id = id
        done = j["done"].bool ?? false
        ok = j["result"]["ok"].bool ?? false
        note = j["result"]["note"].string ?? ""
    }
}
