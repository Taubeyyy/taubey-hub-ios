import Foundation

/// Sample answers for the simulator tour in CI (launch argument `-uitest`):
/// the app runs against these instead of taubey.com, so every screen can be
/// photographed with something on it. Shapes match the real API.
enum Demo {
    static let now = Date().timeIntervalSince1970

    static func answer(_ path: String) -> JSONValue {
        let p = path.components(separatedBy: "?").first ?? path
        if p.hasPrefix("/api/overview") { return json(overview(path.contains("account=Alt"))) }
        if p.hasPrefix("/api/inventory") { return json(inventory) }
        if p.hasPrefix("/api/events") { return json("{\"ok\":true,\"rows\":\(events)}") }
        if p.hasPrefix("/api/history") { return history() }
        if p.hasSuffix("/schema") { return json(schema) }
        if p.hasSuffix("/config") && p.hasPrefix("/api/game/") { return json("{\"ok\":true,\"config\":{\"AutoFish\":true,\"HubFpsCap\":60}}") }
        if p.hasPrefix("/api/agent/") { return json(agentConfig) }
        if p.hasPrefix("/api/auth/me") { return json("{\"ok\":true,\"name\":\"Taubey\"}") }
        return json("{\"ok\":true,\"applied\":1,\"sent\":1}")
    }

    private static func json(_ text: String) -> JSONValue {
        (try? JSONValue.parse(Data(text.utf8))) ?? .null
    }

    static var events: String {
        let t = Int(now)
        return """
        [{"id":1,"kind":"catch","title":"Rubie Hoshi [Electric]","detail":"Divine","at":\(t - 40),"account":"Taubeyyyy","game":"Fish an Anime RNG"},
         {"id":2,"kind":"server","title":"Rejoined after: teleported by the game","detail":"afk screen off, fps cap 60 · Potassium","at":\(t - 600),"account":"Alt","game":"Fish an Anime RNG"},
         {"id":3,"kind":"catch","title":"Kaneko II [Void]","detail":"Celestial","at":\(t - 1500),"account":"Alt","game":"Fish an Anime RNG"},
         {"id":4,"kind":"trouble","title":"no catches for 10 min","detail":"","at":\(t - 5400),"account":"Alt","game":"Fish an Anime RNG"},
         {"id":5,"kind":"catch","title":"AI Hoshi","detail":"God","at":\(t - 9000),"account":"Taubeyyyy","game":"Fish an Anime RNG"}]
        """
    }

    static func overview(_ altOnly: Bool) -> String {
        let main = """
        {"id":"1|taubeyyyy|fish an anime rng","account":"Taubeyyyy","game":"Fish an Anime RNG","group":"",
         "stats":{"note":"hooked - Divine","Runtime":"6h 12m","Cash/s":"113Qa","Gems/min":"6.79K","Casts/min":"39.9","Catches":"8.2K",
                  "Cash":"206Qi","Food":"2.55B","Rebirths":"193","Next rebirth":"34m 46s  (236Qi short)","Next rod":"all bought","paused":false},
         "metrics":{"cashPerSec":113170867251891070,"catchesPerMin":277.2,"gemsPerMin":6785.8,"cash":206123101412664670000,
                    "gems":3415098,"rebirths":193,"catches":8213,"rod":"Rod of the Heavens","paused":false,"rebirthCost":286791049603165450000},
         "overrides":3,"pending":0,"age":4,"uptime":22320,"online":true}
        """
        let alt = """
        {"id":"1|alt|fish an anime rng","account":"Alt","game":"Fish an Anime RNG","group":"",
         "stats":{"note":"feeding","Runtime":"2d 3h","Cash/s":"1.2Qa","Catches":"41K","Rebirths":"88","paused":false},
         "metrics":{"cashPerSec":1200000000000000,"catchesPerMin":204.5,"gemsPerMin":3100,"cash":9800000000000000000,
                    "gems":120400,"rebirths":88,"catches":41022,"rod":"Rod of Hell","paused":false},
         "overrides":0,"pending":1,"age":9,"uptime":184000,"online":true}
        """
        let agents = altOnly ? "[\(alt)]" : "[\(main),\(alt)]"
        return """
        {"ok":true,"who":"Taubey","totals":{"online":\(altOnly ? 1 : 2),"total":\(altOnly ? 1 : 2),"cash":206123101412664670000,"gems":3535498,
          "cashPerSec":114370867251891070,"gemsPerMin":9885.8,"catches":49235,"catchesPerMin":481.7,"rebirths":281,
          "nextRebirth":{"account":"Taubeyyyy","cost":286791049603165450000,"short":80667948190500780000,"eta":713}},
         "rarities":{"Common":812,"Rare":640,"Epic":402,"Legendary":288,"Cosmic":154,"Secret":155,"Rainbow":168,"Ascended":47,
                     "Divine":46,"Supreme":9,"Celestial":3,"God":1},
         "rarityRange":"session",
         "ladder":["Common","Uncommon","Rare","Epic","Legendary","Mythical","Cosmic","Secret","Rainbow","Ascended","Divine",
                   "Supreme","Celestial","Ancient","God","Omniscient","Apex","Transcendent","Exclusive"],
         "groups":[{"name":"","online":2,"total":2}],
         "events":\(events),
         "agents":\(agents)}
        """
    }

    static let inventory = """
    {"ok":true,"ladder":["Common","Uncommon","Rare","Epic","Legendary","Mythical","Cosmic","Secret","Rainbow","Ascended","Divine",
                         "Supreme","Celestial","Ancient","God","Omniscient","Apex","Transcendent","Exclusive"],
     "rows":[{"id":"a","account":"Taubeyyyy","game":"Fish an Anime RNG","online":true,"age":30,"items":[
        {"name":"AI Hoshi","rarity":"God","mutation":"","count":1,"level":12,"cps":1200000000},
        {"name":"Kaneko II","rarity":"Celestial","mutation":"Void","count":3,"level":4,"cps":82000000},
        {"name":"Rubie Hoshi","rarity":"Divine","mutation":"Electric","count":76,"level":1,"cps":2300000},
        {"name":"Itsi Naka","rarity":"Ascended","mutation":"Void","count":14,"level":1,"cps":1493958},
        {"name":"Dantessa","rarity":"Rainbow","mutation":"Blood","count":307,"level":1,"cps":63334},
        {"name":"Nazira","rarity":"Secret","mutation":"","count":52,"level":2,"cps":41000},
        {"name":"Hatsuna Mika","rarity":"Cosmic","mutation":"","count":91,"level":1,"cps":20500}]},
      {"id":"b","account":"Alt","game":"Fish an Anime RNG","online":true,"age":60,"items":[
        {"name":"Rubie Hoshi","rarity":"Divine","mutation":"Electric","count":4,"level":3,"cps":2400000},
        {"name":"2V","rarity":"Ascended","mutation":"","count":22,"level":1,"cps":285714}]}]}
    """

    static let schema = """
    {"ok":true,"schema":{"v":1,"sections":[
     {"tab":"Home","group":"Pause","items":[{"type":"Toggle","key":"Paused","label":"Pause everything","tip":"Stops every job at once."}]},
     {"tab":"Home","group":"Unattended","items":[
        {"type":"Toggle","key":"HubAutoReconnect","label":"Rejoin after a disconnect"},
        {"type":"Slider","key":"HubFpsCap","label":"Cap FPS at","min":0,"max":240,"rounding":0,"suffix":" fps"}]},
     {"tab":"Fishing","group":"Auto fish","items":[
        {"type":"Toggle","key":"AutoFish","label":"Auto fish","tip":"Casts, waits for the hook and reels in."},
        {"type":"Dropdown","key":"FishWhen","label":"Fish","values":["Always","During any event","During luck events"],"multi":false},
        {"type":"Toggle","key":"AutoAbility","label":"Use the rod ability"}]},
     {"tab":"Bag","group":"Clear","items":[
        {"type":"Toggle","key":"AutoClear","label":"Sell by rarity"},
        {"type":"Dropdown","key":"ClearRarities","label":"Sell these","values":["Common","Uncommon","Rare","Epic"],"multi":true},
        {"type":"Slider","key":"ClearKeep","label":"Keep the best","min":0,"max":20,"rounding":0,"suffix":" of each rarity"}]},
     {"tab":"Settings","group":"Discord webhook","items":[{"type":"Input","key":"WebhookUrl","label":"Webhook URL"}]}]}}
    """

    static let agentConfig = """
    {"ok":true,"id":"1|taubeyyyy|fish an anime rng","account":"Taubeyyyy","game":"Fish an Anime RNG","group":"",
     "current":{"Paused":false,"HubAutoReconnect":true,"HubFpsCap":129,"AutoFish":true,"FishWhen":"Always","AutoAbility":true,
                "AutoClear":false,"ClearRarities":{"Common":true,"Rare":true},"ClearKeep":1,"WebhookUrl":""},
     "overrides":{"AutoFish":true,"HubFpsCap":60},"defaults":{}}
    """

    static func history() -> JSONValue {
        var points: [JSONValue] = []
        for i in 0..<48 {
            let wave = 1 + 0.25 * sin(Double(i) / 4) + 0.1 * cos(Double(i) / 1.7)
            points.append(.object(["t": .number((now - Double(48 - i) * 450) * 1000), "v": .number(4.1e20 * wave)]))
        }
        return .object(["ok": .bool(true), "points": .array(points)])
    }
}
