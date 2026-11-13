import Foundation

/// The script speaks English (its menu is English); the app speaks German.
/// What the script sends in its own words - the lines of its overlay, what it
/// is doing right now, the events - is put into German here, so no screen
/// mixes the two. Anything not known stays as it came.
enum Lingo {
    /// The labels of the script's overlay lines.
    static let labels: [String: String] = [
        "Runtime": "Laufzeit", "Cash/s": "Cash pro Sekunde", "Gems/min": "Gems pro Minute",
        "Casts/min": "Würfe pro Minute", "Catches": "Fänge", "Cash": "Cash", "Food": "Futter",
        "Rebirths": "Rebirths", "Next rebirth": "Nächster Rebirth", "Next rod": "Nächste Rute",
        "Fishing": "Angeln", "Feeding": "Leveln", "Collect": "Einsammeln", "Idle rejoin": "15-Minuten-Rejoin",
        "Executor": "Executor", "Rod": "Rute", "Session": "Sitzung",
    ]

    static func label(_ key: String) -> String { labels[key] ?? key }

    /// Words inside the values and the status line, longest first so a longer
    /// phrase wins over a word inside it.
    static let phrases: [(String, String)] = [
        ("line out - asking for the game's auto fish", "Leine draußen – übergibt an das Auto-Fish des Spiels"),
        ("waiting for the rod", "wartet auf die Rute"),
        ("all bought", "alle gekauft"),
        ("nobody in range", "niemand in Reichweite"),
        ("not seen yet", "noch nicht gesehen"),
        ("waiting · next feed in", "wartet · nächstes Leveln in"),
        ("unstuck", "freigemacht"),
        ("hooked", "am Haken"),
        ("casting", "wirft aus"),
        ("reeling", "holt ein"),
        ("feeding", "levelt"),
        ("waiting", "wartet"),
        ("blocked", "geblockt"),
        ("unknown", "unbekannt"),
        ("paused", "pausiert"),
        ("idle", "bereit"),
    ]

    /// A value or a status line: "34m 46s  (236Qi short)" -> "34m 46s (fehlen 236Qi)".
    static func value(_ text: String) -> String {
        var out = text
        // "(236Qi short)" -> "(fehlen 236Qi)"
        if let open = out.range(of: "("), let close = out.range(of: " short)", range: open.upperBound..<out.endIndex) {
            let amount = String(out[open.upperBound..<close.lowerBound])
            out.replaceSubrange(open.lowerBound..<close.upperBound, with: "(fehlen \(amount))")
        }
        if out == "off" { return "aus" }
        if out == "on" { return "an" }
        for (en, de) in phrases {
            out = out.replacingOccurrences(of: en, with: de)
        }
        while out.contains("  ") { out = out.replacingOccurrences(of: "  ", with: " ") }
        return out.replacingOccurrences(of: " - ", with: " – ")
    }

    /// An event title the script wrote.
    static func event(_ title: String) -> String {
        var t = title
        let starts: [(String, String)] = [
            ("Rejoined after: ", "Neu verbunden – "),
            ("Rejoined", "Neu verbunden"),
            ("Server hop", "Serverwechsel"),
        ]
        for (en, de) in starts where t.hasPrefix(en) {
            t = de + String(t.dropFirst(en.count))
            break
        }
        // "no catches for 10 min" -> "seit 10 min kein Fang"
        if t.hasPrefix("no catches for ") {
            let rest = String(t.dropFirst("no catches for ".count))
            t = "Seit " + rest + " kein Fang"
        }
        let words: [(String, String)] = [
            ("teleported by the game", "vom Spiel teleportiert"),
            ("disconnected", "getrennt"),
            ("kicked", "gekickt"),
            ("server hop from the dashboard", "Serverwechsel aus der App"),
            ("rejoin from the dashboard", "Rejoin aus der App"),
            ("the game's idle rejoin", "15-Minuten-Rejoin des Spiels"),
            ("test alert", "Test-Alarm"),
        ]
        for (en, de) in words { t = t.replacingOccurrences(of: en, with: de) }
        return t
    }

    /// The detail line of an event ("afk screen off, fps cap 60 · Potassium").
    static func detail(_ text: String) -> String {
        text.replacingOccurrences(of: "afk screen off", with: "AFK-Bild aus")
            .replacingOccurrences(of: "afk screen on", with: "AFK-Bild an")
            .replacingOccurrences(of: "fps cap", with: "FPS-Limit")
    }
}
