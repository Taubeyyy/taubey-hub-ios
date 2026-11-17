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

    /// Runs one call; a lost session sends you back to the sign-in, anything
    /// else lands in the banner.
    func call<T>(_ work: () async throws -> T) async -> T? {
        do {
            let value = try await work()
            error = nil
            return value
        } catch APIError.notSignedIn {
            signOut()
            return nil
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func refresh() async {
        guard signedIn else { return }
        let range = rarityRange
        if let o = await call({ try await api.overview(range: range) }) {
            overview = o
            if !o.who.isEmpty { who = o.who }
            lastUpdate = Date()
            await Notifier.shared.refreshCatchRule(api)
            Notifier.shared.check(events: o.events, agents: o.agents, ladder: o.ladder)
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
    /// a box ...) to one instance, then what it came to as a toast. The script
    /// answers on its next beat, usually within a few seconds.
    /// `patience`: how many two-second looks for the answer (pictures take a minute or two).
    @discardableResult
    func run(_ cmd: String, args: [String: JSONValue], agent: String, patience: Int = 15) async -> Bool {
        guard let sent = await call({ try await api.gameCommand(cmd, args: args, agent: agent) }) else {
            Haptics.failure()
            return false
        }
        guard let id = sent else {
            say("Nicht angekommen – ist die Instanz online?")
            Haptics.failure()
            return false
        }
        say("Ans Script geschickt …")
        for _ in 0..<patience {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if let list = try? await api.outcomes(agent: agent), let mine = list.first(where: { $0.id == id }), mine.done {
                say((mine.ok ? "✓ " : "✗ ") + (mine.note.isEmpty ? (mine.ok ? "Erledigt" : "Ging nicht") : mine.note))
                if mine.ok { Haptics.success() } else { Haptics.failure() }
                return mine.ok
            }
        }
        say("Noch keine Antwort – das Script ist gerade beschäftigt.")
        return false
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
