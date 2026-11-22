import Foundation

// Trading, live (2026-11-23). The script in the game posts its trade to the
// server on every change - a request waiting, both sides, fees, who accepted,
// its items, the players in its server - and the app follows it on
// /api/agent/:id/trade. Taps go back as commands (trade.offer, trade.accept …).

/// One line on either side of a trade: "C|Madoki Kaneme|Sinister|L440" x1.
struct TradeOffer: Identifiable, Equatable {
    var id: String { gk }
    let gk: String
    let count: Int
    let kind: String
    let name: String
    let mutation: String
    let level: Int
    let rarity: String

    init?(_ j: JSONValue) {
        guard let gk = j["gk"].string, !gk.isEmpty else { return nil }
        self.gk = gk
        count = j["n"].int ?? 1
        kind = j["kind"].string ?? "char"
        name = j["name"].string ?? gk
        mutation = j["mut"].string ?? ""
        level = j["level"].int ?? 1
        rarity = j["rarity"].string ?? ""
    }
}

/// Someone in the script's server.
struct TradePlayer: Identifiable, Equatable {
    let id: Int
    let name: String
    let display: String
    let trusted: Bool

    init?(_ j: JSONValue) {
        guard let name = j["name"].string, !name.isEmpty else { return nil }
        self.name = name
        id = j["id"].int ?? 0
        display = j["display"].string ?? ""
        trusted = j["trusted"].bool ?? false
    }

    /// "Taubey" or "Tau (@Taubey)"
    var title: String { (display.isEmpty || display == name) ? name : "\(display) (@\(name))" }
}

/// A request that waits for an answer - the game gives 20 seconds.
struct TradeRequest: Equatable {
    let id: Int
    let name: String
    let trusted: Bool
    let expires: Date

    func left(now: Date = Date()) -> Int { max(0, Int(expires.timeIntervalSince(now).rounded(.up))) }
}

/// One thing you could put in.
struct TradeItem: Identifiable, Equatable {
    var id: String { gk }
    let gk: String
    let kind: String
    let name: String
    let rarity: String
    let mutation: String
    let level: Int
    let count: Int
    let cps: Double
    let locked: Bool
    let placed: Bool

    init?(_ j: JSONValue) {
        guard let gk = j["gk"].string, !gk.isEmpty else { return nil }
        self.gk = gk
        kind = j["k"].string ?? "char"
        name = j["n"].string ?? gk
        rarity = j["r"].string ?? ""
        mutation = j["m"].string ?? ""
        level = j["l"].int ?? 0
        count = j["q"].int ?? 1
        cps = j["c"].double ?? 0
        locked = j["lk"].bool ?? false
        placed = j["pl"].bool ?? false
    }

    var isCharacter: Bool { kind == "char" }
    var isMaterial: Bool { kind == "mat" }
}

/// The Trade tab's switches in the script, as it last said.
struct TradeSettings: Equatable {
    var take = true
    var confirm = true
    var onlyReceive = true
    var maxFee = "1M"
    var ask = true
    var declineOthers = false
    var push = true
    var window = false

    init() {}
    init(_ j: JSONValue) {
        take = j["take"].bool ?? true
        confirm = j["confirm"].bool ?? true
        onlyReceive = j["onlyReceive"].bool ?? true
        maxFee = j["maxFee"].string ?? "1M"
        ask = j["ask"].bool ?? true
        declineOthers = j["declineOthers"].bool ?? false
        push = j["push"].bool ?? true
        window = j["window"].bool ?? false
    }
}

/// Everything the app shows about trading for one instance.
struct TradeLive: Equatable {
    var open: Bool
    var partner: String
    var partnerTrusted: Bool
    var mine: [TradeOffer]
    var theirs: [TradeOffer]
    var selfAccepted: Bool
    var otherAccepted: Bool
    var selfFee: Double
    var otherFee: Double
    var countdown: Int?
    var why: String
    var request: TradeRequest?
    var players: [TradePlayer]
    var trusted: [TradePlayer]
    var log: [String]
    var settings: TradeSettings
    /// nil = not sent yet (only while a trade is open)
    var items: [TradeItem]?

    init(_ j: JSONValue, now: Date = Date()) {
        open = j["open"].bool ?? false
        partner = j["partner"]["name"].string ?? ""
        partnerTrusted = j["partner"]["trusted"].bool ?? false
        mine = (j["self"].array ?? []).compactMap(TradeOffer.init)
        theirs = (j["other"].array ?? []).compactMap(TradeOffer.init)
        selfAccepted = j["selfAccepted"].bool ?? false
        otherAccepted = j["otherAccepted"].bool ?? false
        selfFee = j["selfFee"].double ?? 0
        otherFee = j["otherFee"].double ?? 0
        countdown = j["countdown"].int
        why = j["why"].string ?? ""
        if let name = j["request"]["name"].string, !name.isEmpty {
            request = TradeRequest(id: j["request"]["id"].int ?? 0, name: name, trusted: j["request"]["trusted"].bool ?? false,
                                   expires: now.addingTimeInterval(Double(j["request"]["left"].int ?? 20)))
        } else {
            request = nil
        }
        players = (j["players"].array ?? []).compactMap(TradePlayer.init)
            .sorted { $0.title.lowercased() < $1.title.lowercased() }
        trusted = (j["trusted"].array ?? []).compactMap(TradePlayer.init)
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
        log = (j["log"].array ?? []).compactMap { $0.string }
        settings = TradeSettings(j["settings"])
        items = j["items"].array.map { $0.compactMap(TradeItem.init) }
    }

    var partnerLabel: String { partner.isEmpty ? "jemand" : partner }

    /// how much of each thing is in already, by key
    var offered: [String: Int] {
        Dictionary(mine.map { ($0.gk, $0.count) }, uniquingKeysWith: +)
    }

    /// One line under the title: who accepted, the countdown, why it waits.
    var status: String {
        if selfAccepted && otherAccepted, let c = countdown { return "Beide angenommen – Trade in \(c) s" }
        if selfAccepted { return "Du hast angenommen – warte auf \(partnerLabel)" }
        if otherAccepted { return "\(partnerLabel) hat angenommen – jetzt du" }
        return why.isEmpty ? "Tippe deine Items an, um sie reinzulegen" : TradeLogic.german(why)
    }
}

enum TradeLogic {
    /// The ladder, worst first - for sorting when the report has no ranks.
    static let ladder = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Cosmic", "Secret", "Rainbow", "Ascended",
                         "Divine", "Supreme", "Celestial", "Ancient", "God", "Omniscient", "Apex", "Transcendent", "Exclusive"]

    static func rank(_ rarity: String) -> Int { ladder.firstIndex(of: rarity) ?? -1 }

    /// How many a tap puts in: the step (nil = all), never more than is free.
    static func amount(step: Int?, free: Int) -> Int {
        guard free > 0 else { return 0 }
        guard let step = step else { return free }
        return min(step, free)
    }

    enum Filter: String, CaseIterable, Hashable { case all = "Alle", characters = "Charaktere", materials = "Materialien", other = "Andere" }

    /// What the grid shows: the filter, the search, best first.
    static func shown(_ items: [TradeItem], filter: Filter, search: String) -> [TradeItem] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return items.filter { item in
            let kindOk: Bool
            switch filter {
            case .all: kindOk = true
            case .characters: kindOk = item.isCharacter
            case .materials: kindOk = item.isMaterial
            case .other: kindOk = !item.isCharacter && !item.isMaterial
            }
            guard kindOk else { return false }
            if q.isEmpty { return true }
            return "\(item.name) \(item.mutation) \(item.rarity)".lowercased().contains(q)
        }
        .sorted { a, b in
            let ra = rank(a.rarity), rb = rank(b.rarity)
            if ra != rb { return ra > rb }
            if a.cps != b.cps { return a.cps > b.cps }
            if a.count != b.count { return a.count > b.count }
            return a.name < b.name
        }
    }

    /// The script's own words for why it waits, in German.
    static func german(_ why: String) -> String {
        if why.hasPrefix("waiting for") { return "Warte, bis \(why.dropFirst("waiting for ".count).replacingOccurrences(of: " to put something in", with: "")) etwas reinlegt" }
        if why.hasPrefix("you give something") { return "Du gibst etwas – bestätige selbst" }
        if why.hasPrefix("fee") { return "Gebühr über deinem Limit – bestätige selbst" }
        if why.hasPrefix("confirming") { return "Bestätige gleich für dich …" }
        return why
    }
}
