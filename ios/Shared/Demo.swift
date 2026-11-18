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
        if p.hasSuffix("/plot") && p.hasPrefix("/api/agent/") { return json(plot) }
        if p.hasSuffix("/commands") && p.hasPrefix("/api/agent/") {
            return json("{\"ok\":true,\"rows\":[{\"id\":7,\"cmd\":\"stand.swap\",\"done\":true,\"result\":{\"ok\":true,\"note\":\"placed Lula (Ancient) instead of Froza\"}}]}")
        }
        if p.hasPrefix("/api/agent/") { return json(agentConfig) }
        if p.hasPrefix("/api/auth/me") { return json("{\"ok\":true,\"name\":\"Taubey\"}") }
        if p.hasPrefix("/api/command") { return json("{\"ok\":true,\"sent\":1,\"ids\":[7]}") }
        if p.hasPrefix("/api/alerts/test") { return json("{\"ok\":true,\"apns\":1,\"apnsErrors\":[]}") }
        if p.hasPrefix("/api/alerts") {
            return json("{\"ok\":true,\"alerts\":{\"trouble\":true,\"silent\":true,\"back\":true,\"summary\":true,\"catches\":\"God\"},\"apns\":{\"available\":true,\"devices\":1}}")
        }
        return json("{\"ok\":true,\"applied\":1,\"sent\":1}")
    }

    private static func json(_ text: String) -> JSONValue {
        (try? JSONValue.parse(Data(text.utf8))) ?? .null
    }

    /// A plot like the main's on 2026-11-13 (full dump), shortened.
    static let plot = """
    {"ok":true,"age":12,"plot":{"plot":"Plot5","food":4293362807,"cash":4646418648103119000,"gems":5408552,"smart":true,
     "place":"placed Lula (Ancient) instead of Froza",
     "stands":[
      {"id":"1","has":true,"name":"Rimura Tempesta","rarity":"God","level":326,"cps":2040000000000,"locked":false,"pinned":false,"held":true,"one":41000000,"ten":460000000,"max":4200000000},
      {"id":"2","has":true,"name":"Angelia","rarity":"God","level":334,"cps":1670000000000,"locked":false,"pinned":false,"held":false,"one":50000000,"ten":560000000},
      {"id":"3","has":true,"name":"Froza","rarity":"God","level":332,"cps":954000000000,"locked":false,"pinned":true,"held":false,"one":48000000},
      {"id":"Purchases.5PAID","has":true,"name":"Lula","rarity":"Ancient","level":360,"cps":196000000000,"locked":false,"pinned":false,"held":false,"one":40000000},
      {"id":"Purchases.17","has":true,"name":"Nazira II","rarity":"Celestial","level":468,"cps":30300000000,"locked":false,"pinned":false,"held":false,"one":190000000},
      {"id":"Purchases.40PAID","has":true,"name":"Elfaria","rarity":"Ancient","level":359,"cps":17500000000,"locked":false,"pinned":false,"held":false,"one":39000000},
      {"id":"Purchases.41","has":false,"name":"","rarity":"","level":0,"cps":0,"locked":true,"pinned":false,"held":false}],
     "jobs":[
      {"id":"garden1","name":"Garden1","kind":"Gardens","busy":true,"pinned":false,"held":false,"who":{"name":"Astra","rarity":"Ancient","cps":145000000,"level":1}},
      {"id":"lemonstand","name":"Lemon Stand","kind":"Lemon stand","busy":true,"pinned":false,"held":true,"who":{"name":"Kafka","rarity":"Ancient","cps":580000000,"level":1}},
      {"id":"fishingdock","name":"Fishing Dock","kind":"Fishing dock","busy":false,"pinned":false,"held":false}],
     "spare":[
      {"key":"C|Almira Eye|Gold|L353","name":"Almira Eye","rarity":"Ancient","mutation":"Gold","level":353,"cps":21500000000,"count":1},
      {"key":"C|Miki|Slime","name":"Miki","rarity":"Ancient","mutation":"Slime","level":1,"cps":290000000,"count":1},
      {"key":"C|Orihira|","name":"Orihira","rarity":"Ancient","mutation":"","level":1,"cps":145000000,"count":5}],
     "items":{"boxes":[{"key":"LegendaryCase","name":"Legendary Box","count":21},{"key":"CosmicCase","name":"Cosmic Box","count":3}],
      "potions":[{"name":"Sinister Potion","count":4,"running":false},{"name":"Luck Potion","count":2,"running":true}],
      "items":[{"name":"Bat","count":1}],
      "materials":[{"name":"Amnetic Coin","count":343},{"name":"Lucrative Shard","count":203},{"name":"Heavenly Feather","count":97}]}}}
    """

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
                  "Cash":"206Qi","Gems":"3.42M","Food":"2.55B","Rebirths":"193","Next rebirth":"34m 46s  (236Qi short)","Next rod":"all bought","paused":false},
         "metrics":{"cashPerSec":113170867251891070,"catchesPerMin":277.2,"gemsPerMin":6785.8,"cash":206123101412664670000,
                    "gems":3415098,"rebirths":193,"catches":8213,"rod":"Rod of the Heavens","paused":false,"rebirthCost":286791049603165450000,
                    "food":2550000000,"casts":8950,"cashEarned":912000000000000000000,"gemsEarned":48200000,"runtime":22320,
                    "rarities":{"Common":512,"Rare":388,"Epic":240,"Legendary":170,"Divine":31,"God":1},
                    "ladder":["Common","Uncommon","Rare","Epic","Legendary","Mythical","Cosmic","Secret","Rainbow","Ascended",
                              "Divine","Supreme","Celestial","Ancient","God","Omniscient","Apex","Transcendent","Exclusive"],
                    "mutations":{"Void":6,"Electric":3,"Blood":4,"Slime":2,"Golden":2.5}},
         "overrides":3,"pending":0,"age":4,"uptime":22320,"online":true}
        """
        let alt = """
        {"id":"1|alt|fish an anime rng","account":"Alt","game":"Fish an Anime RNG","group":"",
         "stats":{"note":"feeding","Runtime":"2d 3h","Cash/s":"1.2Qa","Catches":"41K","Rebirths":"88","paused":false},
         "metrics":{"cashPerSec":1200000000000000,"catchesPerMin":204.5,"gemsPerMin":3100,"cash":9800000000000000000,
                    "gems":120400,"rebirths":88,"catches":41022,"rod":"Rod of Hell","paused":false,"food":96000000,"casts":44100},
         "overrides":0,"pending":1,"age":9,"uptime":184000,"online":true}
        """
        let agents = altOnly ? "[\(alt)]" : "[\(main),\(alt)]"
        let totals = altOnly
            ? """
              {"online":1,"total":1,"cash":9800000000000000000,"gems":120400,"cashPerSec":1200000000000000,"gemsPerMin":3100,
               "catches":41022,"catchesPerMin":204.5,"rebirths":88,"food":96000000,"casts":44100,"nextRebirth":null}
              """
            : """
              {"online":2,"total":2,"cash":206123101412664670000,"gems":3535498,
               "cashPerSec":114370867251891070,"gemsPerMin":9885.8,"catches":49235,"catchesPerMin":481.7,"rebirths":281,"food":2646000000,"casts":53050,
               "castsPerMin":521.3,
               "cashEarned":912000000000000000000,"gemsEarned":48200000,
               "nextRebirth":{"account":"Taubeyyyy","cost":286791049603165450000,"short":80667948190500780000,"eta":713}}
              """
        return """
        {"ok":true,"who":"Taubey","totals":\(totals),
         "rarities":{"Common":812,"Rare":640,"Epic":402,"Legendary":288,"Cosmic":154,"Secret":155,"Rainbow":168,"Ascended":47,
                     "Divine":46,"Supreme":9,"Celestial":3,"God":1},
         "rarityRange":"session",
         "chances":{"account":"Taubeyyyy","catchesPerMin":277.2,"total":10.2,
                    "rarity":{"Divine":1900,"Supreme":9400,"Celestial":31000,"Ancient":88000,"God":225000,"Omniscient":1400000,"Apex":5600000}},
         "ladder":["Common","Uncommon","Rare","Epic","Legendary","Mythical","Cosmic","Secret","Rainbow","Ascended","Divine",
                   "Supreme","Celestial","Ancient","God","Omniscient","Apex","Transcendent","Exclusive"],
         "groups":[{"name":"","online":2,"total":2}],
         "events":\(events),
         "agents":\(agents)}
        """
    }

    static var inventory: String {
        let t = Int(now)
        return """
    {"ok":true,"ladder":["Common","Uncommon","Rare","Epic","Legendary","Mythical","Cosmic","Secret","Rainbow","Ascended","Divine",
                         "Supreme","Celestial","Ancient","God","Omniscient","Apex","Transcendent","Exclusive"],
     "rows":[{"id":"a","account":"Taubeyyyy","game":"Fish an Anime RNG","online":true,"age":30,
        "fresh":{"Kaneko II|Void":\(t - 1500),"AI Hoshi|":\(t - 9000)},
        "things":{"boxes":[{"key":"LegendaryCase","name":"Legendary Box","count":21},{"key":"CosmicCase","name":"Cosmic Box","count":3}],
          "potions":[{"name":"Sinister Potion","count":4,"running":false},{"name":"Luck Potion","count":2,"running":true}],
          "items":[{"name":"Bat","count":1}],
          "materials":[{"name":"Amnetic Coin","count":343},{"name":"Lucrative Shard","count":203},{"name":"Heavenly Feather","count":97}]},
        "items":[
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
    }

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
