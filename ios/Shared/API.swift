import Foundation

enum APIError: LocalizedError, Equatable {
    case notSignedIn
    case server(String)
    case http(Int)
    case offline(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Nicht angemeldet."
        case .server(let text): return text
        case .http(let code): return "Der Server antwortete mit \(code)."
        case .offline(let text): return "Keine Verbindung: \(text)"
        }
    }
}

enum Cookie {
    /// The `panel_session` value out of a Set-Cookie header. Foundation joins
    /// several Set-Cookie headers with ", "; the value itself is URL-encoded by
    /// the server, so it never holds a comma or a semicolon.
    static func panelSession(from header: String) -> String? {
        guard let range = header.range(of: "panel_session=") else { return nil }
        let rest = header[range.upperBound...]
        let value = rest.prefix { $0 != ";" && $0 != "," && $0 != " " }
        return value.isEmpty ? nil : String(value)
    }
}

/// The taubey.com hub API. Signed in with the same session cookie the web
/// dashboard uses - handed out by /api/phone/claim for a code from the
/// dashboard - kept by the app itself rather than a cookie jar, so it
/// survives exactly as long as the app wants it to.
final class HubAPI {
    static let base = URL(string: "https://taubey.com")!

    var session: String?
    private let http: URLSession

    init(session: String?) {
        self.session = session
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.timeoutIntervalForRequest = 20
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        http = URLSession(configuration: config)
    }

    static func url(_ path: String) -> URL {
        URL(string: path, relativeTo: base)!.absoluteURL
    }

    /// A character picture; public, no session needed.
    static func imageURL(game: String, name: String) -> URL? {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        guard let g = game.addingPercentEncoding(withAllowedCharacters: allowed),
              let n = name.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "/api/img/\(g)/\(n)", relativeTo: base)?.absoluteURL
    }

    private func request(_ path: String, method: String, body: JSONValue?) -> URLRequest {
        var r = URLRequest(url: HubAPI.url(path))
        r.httpMethod = method
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        r.setValue("TaubeyHub-iOS", forHTTPHeaderField: "User-Agent")
        if let session = session { r.setValue("panel_session=\(session)", forHTTPHeaderField: "Cookie") }
        if let body = body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = body.encoded()
        }
        return r
    }

    private func send(_ r: URLRequest) async throws -> (JSONValue, HTTPURLResponse) {
        let data: Data, response: URLResponse
        do {
            (data, response) = try await http.data(for: r)
        } catch {
            throw APIError.offline(error.localizedDescription)
        }
        guard let h = response as? HTTPURLResponse else { throw APIError.http(0) }
        let json = (try? JSONValue.parse(data)) ?? .null
        if h.statusCode == 401 { throw APIError.notSignedIn }
        if h.statusCode >= 400 || json["ok"].bool == false {
            if let text = json["error"].string { throw APIError.server(text) }
            throw APIError.http(h.statusCode)
        }
        return (json, h)
    }

    func get(_ path: String) async throws -> JSONValue {
        try await send(request(path, method: "GET", body: nil)).0
    }

    @discardableResult
    func post(_ path: String, _ body: JSONValue = .object([:])) async throws -> JSONValue {
        try await send(request(path, method: "POST", body: body)).0
    }

    @discardableResult
    func delete(_ path: String) async throws -> JSONValue {
        try await send(request(path, method: "DELETE", body: nil)).0
    }

    /// Trades a dashboard code for a session. Returns the session and the name
    /// it belongs to.
    func claim(code: String) async throws -> (session: String, name: String) {
        let clean = code.uppercased().filter { $0.isLetter || $0.isNumber }
        let (json, response) = try await send(request("/api/phone/claim", method: "POST",
                                                      body: .object(["code": .string(clean)])))
        let header = response.value(forHTTPHeaderField: "Set-Cookie") ?? ""
        guard let value = Cookie.panelSession(from: header) else {
            throw APIError.server("Der Server hat keine Sitzung mitgeschickt.")
        }
        return (value, json["name"].string ?? "")
    }

    // MARK: - calls the app makes

    /// `account` narrows everything to one Roblox account; empty = all.
    func overview(range: String, account: String = "") async throws -> Overview {
        Overview(try await get("/api/overview?range=\(range)" + HubAPI.accountQuery(account)))
    }

    static func accountQuery(_ account: String) -> String {
        guard !account.isEmpty, let a = account.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return "" }
        return "&account=\(a)"
    }

    func inventory() async throws -> Inventory {
        Inventory(try await get("/api/inventory"))
    }

    func events(kind: String) async throws -> [HubEvent] {
        let q = kind.isEmpty ? "" : "&kind=\(kind)"
        return (try await get("/api/events?limit=150\(q)")["rows"].array ?? []).compactMap(HubEvent.init)
    }

    func history(metric: String, hours: Int, account: String = "") async throws -> [HistoryPoint] {
        parseHistory(try await get("/api/history?metric=\(metric)&hours=\(hours)" + HubAPI.accountQuery(account)))
    }

    func schema(game: String) async throws -> Schema? {
        let g = game.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? game
        return Schema(try await get("/api/game/\(g)/schema")["schema"])
    }

    /// The default every instance of a game follows unless it overrides it.
    func gameDefaults(game: String) async throws -> [String: JSONValue] {
        let g = game.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? game
        return try await get("/api/game/\(g)/config")["config"].object ?? [:]
    }

    func config(agent: String) async throws -> AgentConfig {
        let id = agent.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? agent
        return AgentConfig(try await get("/api/agent/\(id)"))
    }

    /// Settings for one instance (its own override) or, with `asDefault`, the
    /// default every instance of that game follows.
    func apply(changes: [String: JSONValue], agent: String, game: String, asDefault: Bool) async throws -> Int {
        let body: JSONValue = .object([
            "changes": .object(changes),
            "targets": .array([.string(agent)]),
            "game": .string(game),
            "scope": .string(asDefault ? "default" : "override"),
        ])
        return try await post("/api/config/apply", body)["applied"].int ?? 0
    }

    func command(_ cmd: String, agents: [String]) async throws -> Int {
        try await post("/api/command", .object(["cmd": .string(cmd), "targets": .array(agents.map { .string($0) })]))["sent"].int ?? 0
    }

    func reset(agent: String) async throws {
        let id = agent.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? agent
        try await post("/api/agent/\(id)/reset")
    }

    func remove(agent: String) async throws {
        let id = agent.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? agent
        try await delete("/api/agent/\(id)")
    }

    func me() async throws -> String {
        try await get("/api/auth/me")["name"].string ?? ""
    }
}
