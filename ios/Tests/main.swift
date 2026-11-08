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

check(HubAPI.accountQuery("") == "", "no account, no filter")
check(HubAPI.accountQuery("Taubey yyy") == "&account=Taubey%20yyy", "account encoded got \(HubAPI.accountQuery("Taubey yyy"))")

print("\(passed) passed, \(failures) failed")
if failures > 0 { exit(1) }
