import SwiftUI
import UserNotifications
import BackgroundTasks

/// Notifications for what happens on the farm. Real push comes from the
/// server through Apple (Push.swift); while that is not working, the app
/// looks for news itself and posts local notifications - never both, so
/// nothing arrives twice. Settings live in UserDefaults; the marker of the
/// last event looked at too, so a restart does not announce old news.
@MainActor
final class Notifier: ObservableObject {
    static let shared = Notifier()
    static let refreshTask = "com.taubey.hub.refresh"

    @AppStorage("notify.catch") var catches = true
    @AppStorage("notify.trouble") var trouble = true
    @AppStorage("notify.server") var server = false
    @AppStorage("notify.offline") var offline = true
    @Published var allowed: Bool?
    /// Pushes from the server really arrive: then the app's own look-ups stay quiet.
    @Published var pushActive = UserDefaults.standard.bool(forKey: "push.active") {
        didSet { UserDefaults.standard.set(pushActive, forKey: "push.active") }
    }
    /// What there is to say about real push, for the settings.
    @Published var pushNote = ""
    /// A tapped notification asks for this tab.
    @Published var openTab: Int?

    private let defaults = UserDefaults.standard
    private let sinceKey = "notify.since"
    private let onlineKey = "notify.online"
    /// The catch rule from the server's Alerts settings, kept for the
    /// background look; read again at most every five minutes.
    private let floorKey = "notify.catchFloor"
    private let namesKey = "notify.catchNames"
    private var rulesAt: Date?

    func rememberCatchRule(_ s: AlertSettings) {
        defaults.set(s.catches, forKey: floorKey)
        defaults.set(s.catchNames, forKey: namesKey)
        rulesAt = Date()
    }

    func refreshCatchRule(_ api: HubAPI) async {
        if let at = rulesAt, Date().timeIntervalSince(at) < 300 { return }
        if let answer = try? await api.get("/api/alerts") { rememberCatchRule(AlertSettings(answer)) }
    }

    var kinds: Set<String> {
        var out = Set<String>()
        if catches { out.insert("catch") }
        if trouble { out.insert("trouble") }
        if server { out.insert("server") }
        return out
    }

    func checkPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    func requestPermission() async {
        let ok = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        allowed = ok
    }

    // MARK: real push

    private var sampleRun: Bool { ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-uitest") } }

    /// Asks iOS for the device token, on every start - it can change.
    func registerForPush() {
        guard !sampleRun else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// iOS handed over a token: the server keeps it and says whether pushes go through.
    func registered(token: Data) async {
        guard let session = Vault.read() else { return }
        do {
            let answer = try await HubAPI(session: session).post("/api/apns/device", .object([
                "token": .string(PushLogic.hex(token)),
                "env": .string("production"),
                "name": .string(UIDevice.current.name),
            ]))
            pushActive = PushLogic.working(answer)
            if !(answer["configured"].bool ?? false) {
                pushNote = "iOS hat ein Push-Token gegeben – dem Server fehlt noch der Apple-Schlüssel."
            } else if let refused = answer["lastError"].string {
                pushNote = "Apple hat den letzten Push abgelehnt: \(refused)"
            } else if answer["lastOk"].string == nil {
                pushNote = "Bereit – schick einen Test-Push, um es zu prüfen."
            } else {
                pushNote = "Kommt vom Server über Apple, auch wenn die App zu ist."
            }
        } catch {
            pushNote = "Das Token kam nicht beim Server an: \(error.localizedDescription)"
        }
    }

    func pushFailed(_ why: String) {
        pushActive = false
        pushNote = "iOS gibt kein Push-Token: \(why)"
    }

    /// A test push went through.
    func confirmPush() {
        pushActive = true
        pushNote = "Kommt vom Server über Apple, auch wenn die App zu ist."
    }

    /// One look: new events since the last one, and instances that dropped
    /// off. The first look ever only sets the markers.
    func check(events: [HubEvent], agents: [Agent]?, ladder: [String] = []) {
        let first = defaults.object(forKey: sinceKey) == nil
        let since = Date(timeIntervalSince1970: defaults.double(forKey: sinceKey))
        // with real push the server has said it already; the markers still move
        let quiet = first || pushActive
        if !quiet {
            let floor = defaults.string(forKey: floorKey) ?? ""
            let names = defaults.stringArray(forKey: namesKey) ?? []
            let wanted = events.filter { AlertLogic.wanted($0, floor: floor, names: names, ladder: ladder) }
            for e in AlertLogic.fresh(wanted, since: since, kinds: kinds) {
                let t = AlertLogic.text(for: e)
                post(id: "ev-\(e.id)", title: t.title, body: t.body, urgent: e.kind == "trouble")
            }
        }
        let newest = AlertLogic.newest(events, after: first ? Date() : since)
        defaults.set(newest.timeIntervalSince1970, forKey: sinceKey)

        if let agents = agents {
            let previous = Set(defaults.stringArray(forKey: onlineKey) ?? [])
            if offline && !quiet {
                for a in AlertLogic.wentOffline(previous: previous, agents: agents) {
                    post(id: "off-\(a.id)-\(Int(Date().timeIntervalSince1970))", title: "🔌 \(a.account) ist offline",
                         body: "\(a.game) meldet sich nicht mehr.", urgent: true)
                }
            }
            defaults.set(Array(AlertLogic.onlineIds(agents)), forKey: onlineKey)
        }
    }

    private func post(id: String, title: String, body: String, urgent: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if urgent { content.interruptionLevel = .timeSensitive }
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    /// Asks iOS for the next background look. iOS decides when - usually
    /// every 15 minutes to a few hours, depending on how often the app is used.
    func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Notifier.refreshTask)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// The background look itself: a fresh event list and the instance list.
    func backgroundCheck() async {
        scheduleRefresh()
        guard let session = Vault.read() else { return }
        let api = HubAPI(session: session)
        await refreshCatchRule(api)
        let events = (try? await api.events(kind: "")) ?? []
        let overview = try? await api.overview(range: "session")
        check(events: events, agents: overview?.agents, ladder: overview?.ladder ?? [])
    }
}

/// Shows notifications as banners while the app is open too.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in await Notifier.shared.registered(token: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        let why = error.localizedDescription
        Task { @MainActor in Notifier.shared.pushFailed(why) }
    }

    /// A tap on a notification opens the tab it is about.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let view = response.notification.request.content.userInfo["view"] as? String ?? ""
        Task { @MainActor in Notifier.shared.openTab = PushLogic.tab(for: view) }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}
