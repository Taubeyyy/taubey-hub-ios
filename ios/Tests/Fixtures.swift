import Foundation

// Answers as the hub API gives them, built from real database rows of
// 2026-11-08 (ids shortened, lists cut). New endpoint or new field: record a
// real answer first, add it here, then model it.
enum Fixtures {
    static let overview = #"""
    {"ok":true,"who":"Taubey","totals":{"online":1,"total":2,"cash":50430649109082735000,"gems":3009808,
     "cashPerSec":113170867251891070,"gemsPerMin":6785.821369069364,"catches":571,"catchesPerMin":277.2588890185344,
     "rebirths":193,"nextRebirth":{"account":"Taubeyyyy","cost":286791049603165450000,"short":236000000000000000000,"eta":2086}},
     "rarities":{"Ascended":47,"Supreme":1,"Rainbow":168,"Cosmic":154,"Divine":46,"Secret":155,"Halloween":"3"},
     "rarityRange":"session",
     "ladder":["Common","Uncommon","Rare","Epic","Legendary","Mythical","Cosmic","Secret","Rainbow","Ascended","Divine",
               "Supreme","Celestial","Ancient","God","Omniscient","Apex","Transcendent","Exclusive"],
     "groups":[{"name":"","online":1,"total":2}],
     "events":[{"id":91,"owner":"729","agent_id":"x","kind":"server","title":"Joined a server","detail":"Potassium b799",
                "at":1794093481,"account":"Taubeyyyy","game":"Fish an Anime RNG"},
               {"kind":"broken"}],
     "agents":[{"id":"100000000000000001|taubeyyyy|fish an anime rng","account":"Taubeyyyy","game":"Fish an Anime RNG",
       "placeId":123,"group":"","stats":{"note":"idle","Cash/s":"113Qa","Runtime":"2m","paused":false,"Next rebirth":"34m 46s  (236Qi short)"},
       "metrics":{"cashPerSec":113170867251891070,"rebirths":193,"rod":"Rod of the Heavens","paused":false,
                  "rarities":{"Secret":155},"ladder":["Common"]},
       "overrides":15,"pending":0,"configRev":4,"seenAt":"2026-11-07 23:19:48","age":12,"uptime":107,"online":true},
      {"id":"729|alt|adopt me!","account":"Alt","game":"Adopt Me!","stats":{},"metrics":{},"overrides":"0",
       "pending":0,"age":null,"uptime":null,"online":false}]}
    """#

    static let inventory = #"""
    {"ok":true,"ladder":["Common","Rare","Ascended","Divine"],"rows":[
     {"id":"a","account":"Taubeyyyy","game":"Fish an Anime RNG","group":"","online":true,"age":30,"items":[
       {"name":"Rubie Hoshi","level":1,"cps":2300000,"mutation":"Electric","count":76,"rarity":"Divine"},
       {"name":"Itsi Naka","level":1,"cps":1493958,"mutation":"Void","count":"14","rarity":"Ascended"},
       {"name":"","count":1}]},
     {"id":"b","account":"Alt","game":"Fish an Anime RNG","group":"","online":false,"age":900,"items":[
       {"name":"Rubie Hoshi","level":3,"cps":2400000,"mutation":"Electric","count":4,"rarity":"Divine"}]},
     {"id":"c","account":"New","game":"Fish an Anime RNG","group":"","online":true,"age":null,"items":null}]}
    """#

    static let schema = #"""
    {"ok":true,"schema":{"v":1,"sections":[
     {"tab":"Home","group":"Pause","items":[{"tip":"Stops every job","type":"Toggle","key":"Paused","label":"Pause everything"}]},
     {"tab":"Home","group":"Unattended","items":[{"min":0,"type":"Slider","key":"HubFpsCap","label":"Cap FPS at","max":240,
       "suffix":" fps","rounding":0}]},
     {"tab":"Bag","group":"Clear","items":[{"type":"Dropdown","key":"ClearRarities","label":"Sell these","values":["Common","Rare"],
       "multi":true},{"type":"Weird","key":"X"}]},
     {"tab":"Debug","group":"Dumps","items":[{"type":"Dropdown","key":"DumpWhat","label":"Dump","values":["State"],"multi":false}]}]}}
    """#

    static let agent = #"""
    {"ok":true,"id":"a","account":"Taubeyyyy","game":"Fish an Anime RNG","group":"",
     "current":{"HubFpsCap":129,"ClearRarities":{"Common":true,"Rare":false},"Paused":false},
     "overrides":{"Paused":true,"ClearRarities":[]},"defaults":{"HubFpsCap":60}}
    """#

    static let history = #"{"ok":true,"metric":"cash","points":[{"t":1794093481000,"v":12.5},{"t":1794093541000,"v":"8"}]}"#

    static let setCookie = "panel_session=eyJpZCI6IjcyOSJ9.c2ln%3D%3D; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=7776000"
}
