import Foundation

// Logic tests, run on the CI runner with plain swiftc before the Xcode build:
//   swiftc Shared/*.swift Tests/*.swift -o /tmp/logic && /tmp/logic
// Everything that can be checked without a screen belongs here - a decoding
// mistake otherwise only shows up as an empty screen on the phone.

var failures = 0
var passed = 0

func check(_ ok: Bool, _ what: String, line: Int = #line) {
    if ok {
        passed += 1
    } else {
        failures += 1
        print("✗ FAIL line \(line): \(what)")
    }
}

func json(_ text: String) -> JSONValue {
    do { return try JSONValue.parse(Data(text.utf8)) } catch {
        print("✗ FAIL fixture does not parse: \(error)")
        failures += 1
        return .null
    }
}

// MARK: numbers
check(Format.number(0) == "0", "0")
check(Format.number(999) == "999", "999")
check(Format.number(1500) == "1.5K", "1.5K got \(Format.number(1500))")
check(Format.number(12_300_000) == "12.3M", "12.3M got \(Format.number(12_300_000))")
check(Format.number(123_000_000_000) == "123B", "123B")
check(Format.number(113170867251891070) == "113Qa", "113Qa got \(Format.number(113170867251891070))")
check(Format.number(50430649109082735000) == "50.4Qi", "50.4Qi (what the script itself shows) got \(Format.number(50430649109082735000))")
check(Format.number(-2000) == "-2K", "-2K")
check(Format.number(.infinity) == "–", "infinity")
check(Format.duration(2086) == "34m 46s", "duration got \(Format.duration(2086))")
check(Format.duration(nil) == "–", "nil duration")
check(Format.slider(129.4, rounding: 0) == "129", "slider rounding")

// MARK: cookie
check(Cookie.panelSession(from: Fixtures.setCookie) == "eyJpZCI6IjcyOSJ9.c2ln%3D%3D", "cookie value")
check(Cookie.panelSession(from: "a=b; Path=/, " + Fixtures.setCookie) == "eyJpZCI6IjcyOSJ9.c2ln%3D%3D", "joined headers")
check(Cookie.panelSession(from: "other=1") == nil, "no cookie")

// MARK: overview
let ov = Overview(json(Fixtures.overview))
check(ov.who == "Taubey", "who")
check(ov.online == 1 && ov.total == 2, "online/total")
check(ov.rebirths == 193, "rebirths")
check(ov.nextRebirth?.eta == 2086, "next rebirth eta")
check(ov.nextRebirth?.account == "Taubeyyyy", "next rebirth account")
check(ov.events.count == 1, "a broken event costs only itself, got \(ov.events.count)")
check(ov.agents.count == 2, "two agents")
check(ov.agents.first?.online == true, "online agent")
check(ov.agents.last?.overrides == 0, "overrides as text")
check(ov.agents.last?.uptime == nil, "null uptime")
check(ov.agents.first?.note == "idle", "note")
check(ov.agents.first?.statLines.first?.0 == "Runtime", "stat order")
let best = ov.raritiesBestFirst
check(best.first?.name == "Supreme", "best first got \(String(describing: best.first))")
check(best.last?.name == "Halloween" && best.last?.count == 3, "unknown rarity goes last, count from text")

// MARK: inventory
let inv = Inventory(json(Fixtures.inventory))
check(inv.rows.count == 3, "rows")
check(inv.rows[2].items == nil, "never reported is nil, not empty")
check(inv.rows[0].items?.count == 2, "broken item dropped")
let all = inv.merged(game: "Fish an Anime RNG", account: "")
let rubie = all.first { $0.name == "Rubie Hoshi" }
check(rubie?.count == 80, "merged count got \(String(describing: rubie?.count))")
check(rubie?.accounts.count == 2, "merged accounts")
check(inv.merged(game: "Fish an Anime RNG", account: "Alt").count == 1, "one account")
check(inv.rank("Divine") > inv.rank("Ascended"), "ladder rank")
check(all.first { $0.name == "Itsi Naka" }?.count == 14, "count from text")

// MARK: schema + config
let schema = Schema(json(Fixtures.schema)["schema"])
check(schema != nil, "schema parses")
check(schema?.tabs == ["Home", "Bag"], "tabs without Debug got \(String(describing: schema?.tabs))")
check(schema?.sections.first { $0.group == "Clear" }?.items.count == 1, "unknown control dropped")
let slider = schema?.sections.first { $0.group == "Unattended" }?.items.first
check(slider?.kind == .slider && slider?.max == 240 && slider?.suffix == " fps", "slider fields")
check(Schema(.null) == nil, "no schema yet")

let cfg = AgentConfig(json(Fixtures.agent))
check(cfg.value("Paused").bool == true, "override wins")
check(cfg.value("HubFpsCap").double == 60, "the game default is what the instance is set to, before its last report")
check(AgentConfig(current: ["X": .number(1)], overrides: [:], defaults: [:]).value("X").double == 1, "last report when nothing is set")
check(cfg.value("ClearRarities").selection.isEmpty, "empty Lua list is an empty selection")
check(JSONValue.object(["Common": .bool(true), "Rare": .bool(false)]).selection == ["Common"], "selection")
check(cfg.value("Missing").isNull, "missing")

// MARK: history
let hist = parseHistory(json(Fixtures.history))
check(hist.count == 2 && hist[1].value == 8, "history")
check(abs(hist[0].date.timeIntervalSince1970 - 1794093481) < 1, "history ms to s")

// MARK: encoding round trip
let body: JSONValue = .object(["changes": .object(["Paused": .bool(true), "HubFpsCap": .number(60)])])
let back = try? JSONValue.parse(body.encoded())
check(back == body, "encode round trip")
check(JSONValue.string("3").int == 3, "int from text")
check(JSONValue.number(100000000000000001).string != nil, "big id as text")

// MARK: notifications
func ev(_ kind: String, _ at: Double, _ title: String = "t", _ detail: String = "") -> HubEvent {
    HubEvent(.object(["kind": .string(kind), "at": .number(at), "title": .string(title), "detail": .string(detail),
                      "account": .string("Taubeyyyy"), "game": .string("Fish an Anime RNG")]))!
}
let evs = (0..<10).map { ev($0 % 2 == 0 ? "catch" : "server", 1000 + Double($0)) } + [ev("trouble", 2000)]
let since = Date(timeIntervalSince1970: 1003)
let picked = AlertLogic.fresh(evs, since: since, kinds: ["catch", "trouble"], limit: 5)
check(picked.count == 4, "catch 1004,1006,1008 + trouble got \(picked.count)")
check(picked.first?.at == Date(timeIntervalSince1970: 1004) && picked.last?.kind == "trouble", "oldest first")
check(AlertLogic.fresh(evs, since: Date(timeIntervalSince1970: 0), kinds: ["catch"], limit: 2).count == 2, "limit")
check(AlertLogic.fresh(evs, since: since, kinds: []).isEmpty, "nothing wanted")
check(AlertLogic.newest(evs, after: since) == Date(timeIntervalSince1970: 2000), "newest")
check(AlertLogic.newest([], after: since) == since, "newest of none")
let catchText = AlertLogic.text(for: ev("catch", 1, "Rubie Hoshi [Electric]", "Divine"))
check(catchText.title.contains("Divine: Rubie Hoshi"), "catch title got \(catchText.title)")
check(catchText.body == "Taubeyyyy · Fish an Anime RNG", "catch body")
let agentsNow = ov.agents
check(AlertLogic.onlineIds(agentsNow) == ["100000000000000001|taubeyyyy|fish an anime rng"], "online ids")
check(AlertLogic.wentOffline(previous: ["729|alt|adopt me!"], agents: agentsNow).map { $0.account } == ["Alt"], "went offline")
check(AlertLogic.wentOffline(previous: [], agents: agentsNow).isEmpty, "nothing was online")

// the simulator tour's sample data has to parse like the real thing
let demoOverview = Overview(Demo.answer("/api/overview?range=session"))
check(demoOverview.agents.count == 2 && demoOverview.events.count == 5, "demo overview got \(demoOverview.agents.count)/\(demoOverview.events.count)")
check(Overview(Demo.answer("/api/overview?range=session&account=Alt")).agents.count == 1, "demo account filter")
// nothing the script reports is dropped: gems and food in the totals, every
// metric either in the script's own lines or in the extra ones, never twice
check(demoOverview.food > 0 && demoOverview.gemsEarned > 0, "totals carry food and earned gems")
if let c = demoOverview.chances {
    check(c.ordered(ladder: demoOverview.ladder).first?.name == "Apex", "chances best first")
    check(abs((c.minutes(225000) ?? 0) - 225000 / 277.2) < 0.01, "minutes at the pace")
} else {
    check(false, "demo chances read")
}
if let main = demoOverview.agents.first(where: { $0.account == "Taubeyyyy" }) {
    let extra = main.extraLines.map { $0.0 }
    check(main.statLines.contains { $0.0 == "Gems" }, "gems line")
    check(extra.contains("Cash insgesamt verdient") && extra.contains("Rute") && extra.contains("Würfe"), "extra lines: \(extra)")
    check(!extra.contains("Cash") && !extra.contains("Gems"), "no value twice: \(extra)")
    check(main.rarityCounts.first?.name == "God", "rarities best first")
} else {
    check(false, "demo main agent")
}
check(Inventory(Demo.answer("/api/inventory")).rows.count == 2, "demo inventory")
check(Schema(Demo.answer("/api/game/x/schema")["schema"])?.tabs.count == 4, "demo schema")
check(parseHistory(Demo.answer("/api/history?metric=cash")).count == 48, "demo history")

check(HubAPI.imagePath(game: "Fish an Anime RNG", name: "Mari Kita II") == "/api/img/Fish%20an%20Anime%20RNG/Mari%20Kita%20II",
      "picture path got \(String(describing: HubAPI.imagePath(game: "Fish an Anime RNG", name: "Mari Kita II")))")
check(HubAPI.imageURL(game: "Fish an Anime RNG", name: "Kafka")?.absoluteString == "https://taubey.com/api/img/Fish%20an%20Anime%20RNG/Kafka",
      "picture url")

check(HubAPI.accountQuery("") == "", "no account, no filter")
check(HubAPI.accountQuery("Taubey yyy") == "&account=Taubey%20yyy", "account encoded got \(HubAPI.accountQuery("Taubey yyy"))")

// MARK: push
check(PushLogic.hex(Data([0x00, 0xab, 0x10, 0xff])) == "00ab10ff", "token hex got \(PushLogic.hex(Data([0x00, 0xab, 0x10, 0xff])))")
check(PushLogic.tab(for: "sessions") == 1 && PushLogic.tab(for: "accounts") == 1, "push opens the instances")
check(PushLogic.tab(for: "overview") == 0 && PushLogic.tab(for: "") == 0, "push opens the overview")
check(PushLogic.working(json("{\"ok\":true,\"configured\":true,\"lastOk\":\"2026-11-13 20:00:00\",\"lastError\":null}")), "push working")
check(!PushLogic.working(json("{\"ok\":true,\"configured\":true,\"lastOk\":null,\"lastError\":null}")), "no push through yet")
check(!PushLogic.working(json("{\"ok\":true,\"configured\":false,\"lastOk\":\"x\",\"lastError\":null}")), "no key on the server")
check(!PushLogic.working(json("{\"ok\":true,\"configured\":true,\"lastOk\":\"x\",\"lastError\":\"400 BadDeviceToken\"}")), "refused since")
let alertSettings = AlertSettings(json("{\"ok\":true,\"alerts\":{\"trouble\":false,\"silent\":true,\"back\":false,\"summary\":true,\"catches\":\"God\"},\"apns\":{\"available\":true,\"devices\":2}}"))
check(!alertSettings.trouble && alertSettings.silent && !alertSettings.back && alertSettings.catches == "God", "alert settings read")
check(alertSettings.appPush && alertSettings.appDevices == 2, "apns state read")
check(AlertSettings(Demo.answer("/api/alerts")).appPush, "demo alerts")
check(AlertSettings(json("{\"alerts\":{\"catches\":\"\",\"catchNames\":[\"AI Hoshi\"]}}")).catchNames == ["AI Hoshi"], "catch names read")

// a catch is announced by the server's rule: the floor set under Alerts, or a watched name
let tiers = ["Common", "Rare", "Divine", "God", "Apex"]
func catchEvent(_ title: String, _ rarity: String) -> HubEvent {
    HubEvent(json("{\"at\":1763200000,\"kind\":\"catch\",\"title\":\"\(title)\",\"detail\":\"\(rarity)\"}"))!
}
check(!AlertLogic.wanted(catchEvent("Rubie Hoshi [Electric]", "Divine"), floor: "God", names: [], ladder: tiers), "divine below a god floor")
check(AlertLogic.wanted(catchEvent("AI Hoshi", "God"), floor: "God", names: [], ladder: tiers), "god at a god floor")
check(AlertLogic.wanted(catchEvent("Kaito", "Apex"), floor: "God", names: [], ladder: tiers), "apex above a god floor")
check(AlertLogic.wanted(catchEvent("Aquella [Slime]", "Rare"), floor: "God", names: ["aquella"], ladder: tiers), "watched name, any mutation")
check(!AlertLogic.wanted(catchEvent("AI Hoshi", "God"), floor: "", names: [], ladder: tiers), "nothing set, nothing said")
check(AlertLogic.wanted(HubEvent(json("{\"at\":1763200000,\"kind\":\"trouble\",\"title\":\"x\"}"))!, floor: "", names: [], ladder: tiers), "trouble always")

// MARK: German for what the script says
check(Lingo.label("Next rebirth") == "Nächster Rebirth" && Lingo.label("Whatever") == "Whatever", "labels")
check(Lingo.value("34m 46s  (236Qi short)") == "34m 46s (fehlen 236Qi)", "short got \(Lingo.value("34m 46s  (236Qi short)"))")
check(Lingo.value("all bought") == "alle gekauft", "all bought")
check(Lingo.value("hooked - Divine") == "am Haken – Divine", "status got \(Lingo.value("hooked - Divine"))")
check(Lingo.value("off") == "aus" && Lingo.value("Rod of the Heavens") == "Rod of the Heavens", "names stay")
check(Lingo.event("Rejoined after: teleported by the game") == "Neu verbunden – vom Spiel teleportiert",
      "rejoin event got \(Lingo.event("Rejoined after: teleported by the game"))")
check(Lingo.event("no catches for 10 min") == "Seit 10 min kein Fang", "stall event got \(Lingo.event("no catches for 10 min"))")
check(Lingo.event("Rubie Hoshi [Electric]") == "Rubie Hoshi [Electric]", "a catch stays")
check(Lingo.detail("afk screen off, fps cap 60 · Potassium") == "AFK-Bild aus, FPS-Limit 60 · Potassium", "detail")

// MARK: what is new, and the items
let demoInv = Inventory(Demo.answer("/api/inventory"))
let fresh = demoInv.fresh(game: "Fish an Anime RNG", account: "")
check(fresh.count == 2 && fresh[0].item.name == "Kaneko II" && fresh[1].item.name == "AI Hoshi", "fresh newest first got \(fresh.map { $0.item.name })")
check(demoInv.fresh(game: "Fish an Anime RNG", account: "Alt").isEmpty, "nothing new on the alt")
check(demoInv.things(game: "Fish an Anime RNG", account: "").count == 1, "items from one instance")
check(demoInv.things(game: "Fish an Anime RNG", account: "").first?.things?.boxes.first?.count == 21, "boxes in the inventory")

// MARK: plot (remote control)
if let report = PlotReport(Demo.answer("/api/agent/1%7Calt/plot")) {
    check(report.stands.count == 7 && report.occupied == 6, "stands read got \(report.stands.count)/\(report.occupied)")
    check(report.stands[0].held && !report.stands[0].pinned && report.stands[0].costTen == 460000000, "stand flags and prices")
    check(report.stands[2].costTen == nil && report.stands[6].locked, "missing price stays nil, locked stand")
    check(report.stands[3].label == "Stand 5 · bezahlt" && report.stands[0].label == "Stand 1", "stand label got \(report.stands[3].label)")
    check(report.stands[3].number == 5 && report.stands[4].number == 17 && report.stands[0].number == 1, "stand numbers")
    check(report.jobs.count == 3 && report.jobs[1].whoName == "Kafka" && report.jobs[1].held, "jobs read")
    check(!report.jobs[2].busy && report.jobs[2].whoName.isEmpty, "free job")
    check(report.spare.count == 3 && report.spare[0].id == "C|Almira Eye|Gold|L353", "spare read")
    check(report.spare[1].potential > report.spare[0].potential, "a strong level-1 has more in it than a levelled one")
    check(report.spare[1].title == "Miki [Slime]" && report.spare[2].title == "Orihira", "spare titles")
    check(report.items.boxes.first?.count == 21 && report.items.potions[1].running && report.items.materials.count == 3, "items read")
    check(report.age == 12 && report.smart, "age and placer mode")
} else {
    check(false, "demo plot does not parse")
}
check(PlotReport(json("{\"ok\":true,\"plot\":null,\"age\":null}")) == nil, "no report yet")
let outcome = CommandOutcome(json("{\"id\":7,\"cmd\":\"stand.swap\",\"done\":true,\"result\":{\"ok\":false,\"note\":\"not in the bag\"}}"))
check(outcome?.done == true && outcome?.ok == false && outcome?.note == "not in the bag", "command outcome")
check(CommandOutcome(json("{\"id\":8,\"done\":false,\"result\":null}"))?.done == false, "command still out")
check(HubAPI.agentPath("1|alt|fish an anime rng") == "1%7Calt%7Cfish%20an%20anime%20rng", "agent path got \(HubAPI.agentPath("1|alt|fish an anime rng"))")

print("\(passed) passed, \(failures) failed")
if failures > 0 { exit(1) }
