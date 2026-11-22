import SwiftUI
import Security

/// Where the session lives. The keychain first; an app signed with ldid for
/// TrollStore may not be allowed into it, and then UserDefaults takes it.
enum Vault {
    private static let service = "com.taubey.hub"
    private static let account = "panel_session"

    private static var base: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func read() -> String? {
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
           let data = out as? Data, let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }
        return UserDefaults.standard.string(forKey: account)
    }

    static func write(_ value: String?) {
        SecItemDelete(base as CFDictionary)
        UserDefaults.standard.removeObject(forKey: account)
        guard let value = value, !value.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        if SecItemAdd(add as CFDictionary, nil) != errSecSuccess {
            UserDefaults.standard.set(value, forKey: account)
        }
    }
}

@MainActor
final class HubStore: ObservableObject {
    @Published var session: String?
    @Published var who: String
    /// Every instance - the Instances tab, notifications.
    @Published var overview: Overview?
    /// The overview page narrowed to `account` (nil while that is "all").
    @Published var focus: Overview?
    @Published var account: String = UserDefaults.standard.string(forKey: "focus.account") ?? "" {
        didSet {
            UserDefaults.standard.set(account, forKey: "focus.account")
            if account.isEmpty { focus = nil }
        }
    }
    @Published var rarityRange = "session"
    @Published var error: String?
    @Published var lastUpdate: Date?
    @Published var toast: String?
    /// The cloud phone's watchdog (Instances tab): paused, listening, version.
    @Published var watchdog: WatchdogState?
    private var watchdogAt: Date?

    let api: HubAPI

    init() {
        let args = ProcessInfo.processInfo.arguments
        // the CI's simulator tour: signed in with sample data, or at the sign-in
        if args.contains("-uitest") {
            session = "demo"
            api = HubAPI(session: "demo")
            api.demo = true
            who = "Taubey"
            return
        }
        if args.contains("-uitest-signedout") {
            session = nil
            api = HubAPI(session: nil)
            who = ""
            return
        }
        let saved = Vault.read()
        session = saved
        api = HubAPI(session: saved)
        who = UserDefaults.standard.string(forKey: "who") ?? ""
    }

    var signedIn: Bool { session != nil }

    func signIn(code: String) async throws {
        let result = try await api.claim(code: code)
        api.session = result.session
        Vault.write(result.session)
        session = result.session
        who = result.name
        UserDefaults.standard.set(result.name, forKey: "who")
        await refresh()
    }

    func signOut() {
        Vault.write(nil)
        api.session = nil
        session = nil
        overview = nil
    }

    /// Calls in a row that failed on the way (no network, server busy). One
    /// slip is no news - a cloud phone, a train, a tunnel - so the banner only
    /// comes on the second, and the data from before stays on screen.
    private var failStreak = 0

    /// Runs one call; a lost session sends you back to the sign-in, a
    /// connection that is briefly gone waits for the next try, anything else
    /// lands in the banner.
    func call<T>(_ work: () async throws -> T) async -> T? {
        do {
            let value = try await work()
            error = nil
            failStreak = 0
            return value
        } catch APIError.notSignedIn {
            signOut()
            return nil
        } catch let e as APIError {
            if HubStore.passing(e) {
                failStreak += 1
                if failStreak >= 2 {
                    error = "Keine Verbindung zum Server – ich versuche es weiter"
                        + (lastUpdate.map { " · letzter Stand " + Format.ago($0) } ?? "")
                }
            } else {
                error = e.localizedDescription
            }
            return nil
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    /// Errors that are about the way there, not about what was asked.
    static func passing(_ e: APIError) -> Bool {
        switch e {
        case .offline: return true
        case .http(let code): return code == 0 || code == 408 || code == 429 || code >= 500
        default: return false
        }
    }

    /// The newest restart by the phone's watchdog for an account, from the
    /// events the overview carries.
    func lastWatchdog(_ account: String) -> HubEvent? {
        (overview?.events ?? [])
            .filter { $0.account == account && $0.title.hasPrefix("Watchdog") }
            .max { $0.at < $1.at }
    }

    func refresh() async {
        guard signedIn else { return }
        let range = rarityRange
        if let o = await call({ try await api.overview(range: range) }) {
            overview = o
            if !o.who.isEmpty { who = o.who }
            lastUpdate = Date()
        }
        let picked = account
        if !picked.isEmpty {
            // an account that no longer reports falls back to all
            if let all = overview, !all.agents.contains(where: { $0.account == picked }) {
                account = ""
            } else if let f = await call({ try await api.overview(range: range, account: picked) }), account == picked {
                focus = f
            }
        }
        await refreshWatchdog()
    }

    /// Every 20 s at most (the phone asks every 15-30 s anyway); quiet - a
    /// missing watchdog is no error banner.
    func refreshWatchdog(force: Bool = false) async {
        if !force, let at = watchdogAt, Date().timeIntervalSince(at) < 20 { return }
        watchdogAt = Date()
        if let w = try? await api.watchdogState() { watchdog = w }
    }

    /// Pause for `minutes` (0 = go on now). The phone picks it up within half a minute.
    func pauseWatchdog(minutes: Int) async {
        guard let w = await call({ try await api.pauseWatchdog(minutes: minutes) }) else {
            Haptics.failure()
            return
        }
        watchdog = w
        watchdogAt = Date()
        Haptics.success()
        if minutes == 0 {
            say("Watchdog läuft wieder – nach 3 min Schonfrist holt er Roblox zurück")
        } else {
            say("Watchdog pausiert bis \(WatchdogState.clock(w.pauseUntil ?? Date()))")
        }
    }

    /// Every account that reports, for the switch.
    var accounts: [String] {
        Array(Set((overview?.agents ?? []).map { $0.account })).sorted { $0.lowercased() < $1.lowercased() }
    }

    /// What the overview page shows.
    var shown: Overview? {
        account.isEmpty ? overview : (focus ?? nil)
    }

    func say(_ text: String) {
        toast = text
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if toast == text { toast = nil }
        }
    }

    func command(_ cmd: String, agents: [String]) async {
        guard !agents.isEmpty else { return }
        if let n = await call({ try await api.command(cmd, agents: agents) }) {
            let what = ["rejoin": "Rejoin", "hop": "Serverwechsel", "refresh": "Aktualisieren"][cmd] ?? cmd
            say("\(what) an \(n) Instanz\(n == 1 ? "" : "en") geschickt")
        }
    }

    /// Each mutation's multiplier as the game keeps it (the scripts report the
    /// table); empty until one has.
    var mutationBoosts: [String: Double] {
        for a in overview?.agents ?? [] {
            guard let table = a.metrics["mutations"]?.object, !table.isEmpty else { continue }
            var out: [String: Double] = [:]
            for (k, v) in table { if let n = v.double { out[k] = n } }
            return out
        }
        return [:]
    }

    /// One of the game's own commands (move a character, level a stand, open
    /// a box ...) to one instance, followed step by step: the server says the
    /// moment the script took it, started it and finished it, and the toast
    /// says so too. `patience`: roughly how many seconds/2 it may take to
    /// finish (pictures take a minute or two).
    @discardableResult
    func run(_ cmd: String, args: [String: JSONValue], agent: String, patience: Int = 15) async -> Bool {
        guard let sent = await call({ try await api.gameCommand(cmd, args: args, agent: agent) }) else {
            say("Nicht gesendet – keine Verbindung zum Server")
            Haptics.failure()
            return false
        }
        guard let id = sent else {
            say("Nicht angekommen – ist die Instanz online?")
            Haptics.failure()
            return false
        }
        // An instance that is offline right now - the phone's watchdog may be
        // restarting it - gets its command when it is back: the server keeps
        // it five minutes. One that is online has to take it within 12 s.
        let wasOnline = overview?.agents.first { $0.id == agent }?.online ?? true
        say(wasOnline ? "Gesendet …" : "Instanz ist offline – der Befehl wartet bis zu 5 min auf sie")
        let start = Date()
        let deadline = start.addingTimeInterval(wasOnline ? Double(patience) * 2 + 15 : 300 + Double(patience) * 2)
        var step = "queued"
        var misses = 0
        while Date() < deadline {
            guard let now = try? await api.commandState(id, after: step, wait: 12) else {
                // the way there failed, not the command: try again, a bit slower each time
                misses += 1
                try? await Task.sleep(nanoseconds: UInt64(min(misses, 5)) * 1_000_000_000)
                continue
            }
            misses = 0
            if now.state == step {
                // nothing moved: a script that is online and has not even taken it is not there
                if wasOnline && step == "queued" && Date().timeIntervalSince(start) > 12 {
                    say("Das Script nimmt nichts an – ist die Instanz online?")
                    Haptics.failure()
                    return false
                }
                continue
            }
            step = now.state
            switch step {
            case "delivered":
                say("Angekommen …")
            case "running":
                say("Läuft …")
            case "done", "failed":
                let ok = step == "done"
                say((ok ? "✓ " : "✗ ") + (now.note.isEmpty ? (ok ? "Erledigt" : "Ging nicht") : Lingo.value(now.note)))
                if ok { Haptics.success() } else { Haptics.failure() }
                lastCommandAt = Date()
                return ok
            default:
                break
            }
        }
        say(step == "running" ? "Läuft noch – das Ergebnis kommt in der Liste an."
            : (wasOnline ? "Keine Antwort vom Script." : "Instanz kam in 5 min nicht wieder – Befehl verfallen."))
        return false
    }

    /// When a command last finished - views that show its effect reload then.
    @Published var lastCommandAt: Date?

    // MARK: updates

    /// A newer build on GitHub than the one running, nil when there is none.
    @Published var update: AppRelease?
    @Published var updateCheckedAt: Date?

    /// The build that runs (CI writes the build number into CFBundleVersion).
    static var runningBuild: Int {
        Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "") ?? 0
    }

    /// Asks GitHub for the newest release - the repo is public, no login. At
    /// most every 20 minutes unless `force`.
    func checkUpdate(force: Bool = false) async {
        if !force, let last = updateCheckedAt, Date().timeIntervalSince(last) < 1200 { return }
        updateCheckedAt = Date()
        if api.demo {
            update = AppRelease(build: 999, ipa: URL(string: "https://github.com/Taubeyyy/taubey-hub-ios/releases")!, title: "Taubey Build 999")
            return
        }
        var request = URLRequest(url: AppRelease.latestURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("TaubeyHub-iOS", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONValue.parse(data),
              let release = AppRelease(json) else { return }
        update = release.isNewer(than: HubStore.runningBuild) ? release : nil
    }

    /// Hands the new build to TrollStore, which installs it over this app.
    func installUpdate() {
        guard let link = update?.installURL else { return }
        Haptics.tap()
        UIApplication.shared.open(link) { opened in
            if !opened {
                Task { @MainActor in self.say("TrollStore hat den Link nicht angenommen – in TrollStore die URL-Scheme-Option einschalten") }
            }
        }
    }

    func setPaused(_ paused: Bool, agent: Agent) async {
        if await call({
            try await api.apply(changes: ["Paused": .bool(paused)], agent: agent.id, game: agent.game, asDefault: false)
        }) != nil {
            say(paused ? "Pausiert - kommt in ein paar Sekunden an" : "Läuft weiter")
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await refresh()
        }
    }
}
