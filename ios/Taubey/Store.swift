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
    @Published var overview: Overview?
    @Published var rarityRange = "session"
    @Published var error: String?
    @Published var lastUpdate: Date?
    @Published var toast: String?

    let api: HubAPI

    init() {
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
            Notifier.shared.check(events: o.events, agents: o.agents)
        }
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
