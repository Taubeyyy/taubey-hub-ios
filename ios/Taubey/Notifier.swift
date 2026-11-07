import SwiftUI
import UserNotifications
import BackgroundTasks

/// Local notifications for what happens on the farm - see AlertLogic for why
/// there is no server push. Settings live in UserDefaults; the marker of the
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

    private let defaults = UserDefaults.standard
    private let sinceKey = "notify.since"
    private let onlineKey = "notify.online"

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

    /// One look: new events since the last one, and instances that dropped
    /// off. The first look ever only sets the markers.
    func check(events: [HubEvent], agents: [Agent]?) {
        let first = defaults.object(forKey: sinceKey) == nil
        let since = Date(timeIntervalSince1970: defaults.double(forKey: sinceKey))
        if !first {
            for e in AlertLogic.fresh(events, since: since, kinds: kinds) {
                let t = AlertLogic.text(for: e)
                post(id: "ev-\(e.id)", title: t.title, body: t.body, urgent: e.kind == "trouble")
            }
        }
        let newest = AlertLogic.newest(events, after: first ? Date() : since)
        defaults.set(newest.timeIntervalSince1970, forKey: sinceKey)

        if let agents = agents {
            let previous = Set(defaults.stringArray(forKey: onlineKey) ?? [])
            if offline && !first {
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
        let events = (try? await api.events(kind: "")) ?? []
        let agents = try? await api.overview(range: "session").agents
        check(events: events, agents: agents)
    }
}

/// Shows notifications as banners while the app is open too.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}
