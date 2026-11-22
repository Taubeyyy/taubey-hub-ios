import Foundation

/// The watchdog on the cloud phone as the server sees it (`/api/watchdog/state`):
/// whether it is paused and until when, when it last asked the server, and
/// with which version. It asks every half minute; the pause runs out by
/// itself, so a forgotten one cannot hold the farm for days (12 h at most).
struct WatchdogState: Equatable {
    var pauseUntil: Date?
    /// seconds since the phone last asked; nil = not since the server started
    var seenAgo: Int?
    /// the version that asked; 0 = one from before version 7 (it does not say)
    var version: Int
    /// the version on the server - a newer one updates itself from 7 on
    var latest: Int
    /// what to run in Termux once when the phone's copy is too old to update itself
    var install: String

    init(_ j: JSONValue) {
        let until = j["pauseUntil"].double ?? 0
        pauseUntil = until > 0 ? Date(timeIntervalSince1970: until) : nil
        seenAgo = j["seenAgo"].int
        version = j["version"].int ?? 0
        latest = j["latest"].int ?? 0
        install = j["install"].string ?? ""
    }

    func paused(now: Date = Date()) -> Bool {
        guard let until = pauseUntil else { return false }
        return until > now
    }

    /// asked within the last two minutes (it asks every 15-30 s)
    var listening: Bool { (seenAgo ?? Int.max) < 120 }

    /// a copy from before the self-update: one command in Termux, then never again
    var needsInstall: Bool { listening && version < 7 && latest >= 7 }

    enum Mood { case running, paused, quiet, unknown }

    func mood(now: Date = Date()) -> Mood {
        if paused(now: now) { return .paused }
        if seenAgo == nil { return .unknown }
        return listening ? .running : .quiet
    }

    /// The line under the title.
    func detail(now: Date = Date()) -> String {
        switch mood(now: now) {
        case .paused:
            return "Pausiert bis \(WatchdogState.clock(pauseUntil ?? now)) – fasst Roblox nicht an, du kannst am Handy spielen"
        case .running:
            return "Startet Roblox neu, wenn es abstürzt oder hängt" + (version > 0 ? " · v\(version)" : "")
        case .quiet:
            return "Meldet sich nicht – letzte Anfrage vor \(Format.duration(Double(seenAgo ?? 0))). Handy aus oder Termux zu?"
        case .unknown:
            return "Noch keine Meldung vom Handy"
        }
    }

    /// The choices for a pause, in minutes.
    static let choices: [(String, Int)] = [("30 Minuten", 30), ("1 Stunde", 60), ("2 Stunden", 120), ("4 Stunden", 240), ("8 Stunden", 480)]

    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "EEE HH:mm"
        return f.string(from: date)
    }
}
