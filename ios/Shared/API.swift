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
    /// The simulator tour: answers come from Demo, nothing goes out.
    var demo = false
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
        guard let path = imagePath(game: game, name: name) else { return nil }
        return URL(string: path, relativeTo: base)?.absoluteURL
    }

    /// A potion's or case's picture, read in the game by the script
    /// (Debug > "Item pictures to the dashboard"); public, 404 until then.
    static func itemURL(name: String, look: String = "fish-anime") -> URL? {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
        guard let n = name.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "/api/item/\(look)/\(n)", relativeTo: base)?.absoluteURL
    }

    /// The picture's path, percent-encoded (URL.path would decode it again).
    static func imagePath(game: String, name: String) -> String? {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
        guard let g = game.addingPercentEncoding(withAllowedCharacters: allowed),
              let n = name.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return "/api/img/\(g)/\(n)"
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
        if demo { return Demo.answer(path) }
        return try await send(request(path, method: "GET", body: nil)).0
    }

    @discardableResult
    func post(_ path: String, _ body: JSONValue = .object([:])) async throws -> JSONValue {
        if demo { return Demo.answer(path) }
        return try await send(request(path, method: "POST", body: body)).0
    }

    @discardableResult
    func delete(_ path: String) async throws -> JSONValue {
        if demo { return Demo.answer(path) }
        return try await send(request(path, method: "DELETE", body: nil)).0
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

    /// An account's Roblox head (taubey.com/api/head/<name>, the session's own
    /// accounts only); nil when there is none or nothing could be fetched.
    func headImage(account: String) async -> Data? {
        if demo { return nil }
        guard account.range(of: "^[A-Za-z0-9_]{3,20}$", options: .regularExpression) != nil else { return nil }
        var r = URLRequest(url: HubAPI.url("/api/head/" + account))
        r.setValue("TaubeyHub-iOS", forHTTPHeaderField: "User-Agent")
        if let session = session { r.setValue("panel_session=\(session)", forHTTPHeaderField: "Cookie") }
        guard let (data, response) = try? await http.data(for: r), let h = response as? HTTPURLResponse,
              h.statusCode == 200, (h.value(forHTTPHeaderField: "Content-Type") ?? "").hasPrefix("image/") else { return nil }
        return data
    }

    // MARK: - feedback for Claude on the server

    /// Where a note for Claude goes: the hub on the Dopa server, project
    /// Taubey. It shows up in Edwin's Claude app; Claude only works on what
    /// is picked there.
    static let feedbackURL = URL(string: "https://dopa.taubey.com/api/hub/feedback/taubey")!

    /// Sends a note (what bothers, what is missing). `screen`: where it came from.
    func sendFeedback(_ text: String, screen: String) async throws {
        if demo { return }
        var r = URLRequest(url: HubAPI.feedbackURL)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("TaubeyHub-iOS", forHTTPHeaderField: "User-Agent")
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        r.httpBody = JSONValue.object([
            "text": .string(text), "screen": .string(screen), "build": .string(build), "device": .string("iPhone"),
        ]).encoded()
        let data: Data, response: URLResponse
        do {
            (data, response) = try await http.data(for: r)
        } catch {
            throw APIError.offline(error.localizedDescription)
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code >= 200 && code < 300 { return }
        let json = (try? JSONValue.parse(data)) ?? .null
        if let text = json["error"].string { throw APIError.server(text) }
        throw APIError.http(code)
    }

    // MARK: - calls the app makes

    /// The cloud phone's watchdog: paused, listening, which version.
    func watchdogState() async throws -> WatchdogState {
        WatchdogState(try await get("/api/watchdog/state"))
    }

    /// Pauses the watchdog for `minutes` (0 = go on now); answers the new state.
    func pauseWatchdog(minutes: Int) async throws -> WatchdogState {
        WatchdogState(try await post("/api/watchdog/pause", .object(["minutes": .number(Double(minutes))])))
    }

    /// The characters of this owner that no picture answers for yet.
    func missingPictures() async throws -> [MissingPicture] {
        (try await get("/api/pictures/missing")["rows"].array ?? []).compactMap(MissingPicture.init)
    }

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

    // MARK: remote control - the plot of one instance

    static func agentPath(_ agent: String) -> String {
        agent.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? agent
    }

    func plot(agent: String) async throws -> PlotReport? {
        PlotReport(try await get("/api/agent/\(HubAPI.agentPath(agent))/plot"))
    }

    /// One of the game's own commands (stand.swap, job.set, box.open ...) to
    /// one instance. Returns the command's id, to ask after its outcome.
    func gameCommand(_ cmd: String, args: [String: JSONValue], agent: String) async throws -> Int? {
        let answer = try await post("/api/command", .object([
            "cmd": .string(cmd), "args": .object(args), "targets": .array([.string(agent)]),
        ]))
        return answer["ids"][0].int
    }

    /// One command's step on its way: queued, delivered, running, done or
    /// failed. With `after` the server answers once it has moved past that
    /// step, or after `wait` seconds with the step unchanged.
    func commandState(_ id: Int, after: String = "", wait: Int = 15) async throws -> (state: String, note: String) {
        if demo { return ("done", "Erledigt") }
        let query = after.isEmpty ? "" : "?after=\(after)&wait=\(wait)"
        let j = try await get("/api/command/\(id)" + query)
        return (j["state"].string ?? "", j["note"].string ?? "")
    }

    func outcomes(agent: String) async throws -> [CommandOutcome] {
        (try await get("/api/agent/\(HubAPI.agentPath(agent))/commands")["rows"].array ?? []).compactMap(CommandOutcome.init)
    }

    func reset(agent: String) async throws {
        let id = agent.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? agent
        try await post("/api/agent/\(id)/reset")
    }

    func remove(agent: String) async throws {
        let id = agent.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? agent
        try await delete("/api/agent/\(id)")
    }

    /// A character's own picture, for the ones the wiki has none of
    /// (admins only on the server). `png` is the finished square image.
    func uploadPicture(game: String, name: String, png: Data) async throws {
        guard let path = HubAPI.imagePath(game: game, name: name) else { throw APIError.server("Ungültiger Name") }
        try await post(path, .object(["data": .string("data:image/png;base64," + png.base64EncodedString())]))
    }

    /// Back to the wiki's picture, or none.
    func removePicture(game: String, name: String) async throws {
        guard let path = HubAPI.imagePath(game: game, name: name) else { return }
        try await delete(path)
    }

    func me() async throws -> String {
        try await get("/api/auth/me")["name"].string ?? ""
    }
}
