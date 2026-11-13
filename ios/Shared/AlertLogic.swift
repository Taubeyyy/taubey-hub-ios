import Foundation

/// What deserves a notification. Pure functions, so the CI checks them.
///
/// The fallback for while real push (Push.swift) is not working: the app
/// asks the server itself - every ten seconds while it is open, and whenever
/// iOS hands it a background refresh. Whatever happened since the last look
/// becomes a local notification.
enum AlertLogic {
    /// Event kinds the server writes: catch, trouble, server.
    static let kinds = ["catch", "trouble", "server"]

    /// Events newer than `since`, of the kinds wanted, oldest first, at most
    /// `limit` - after a night offline nobody wants forty banners.
    static func fresh(_ events: [HubEvent], since: Date, kinds: Set<String>, limit: Int = 5) -> [HubEvent] {
        let list = events
            .filter { $0.at > since && kinds.contains($0.kind) }
            .sorted { $0.at < $1.at }
        return Array(list.suffix(limit))
    }

    /// The newest event time, so the next look starts after it.
    static func newest(_ events: [HubEvent], after since: Date) -> Date {
        events.map { $0.at }.reduce(since) { max($0, $1) }
    }

    /// Instances that were online at the last look and are not any more.
    static func wentOffline(previous: Set<String>, agents: [Agent]) -> [Agent] {
        agents.filter { previous.contains($0.id) && !$0.online }
    }

    static func onlineIds(_ agents: [Agent]) -> Set<String> {
        Set(agents.filter { $0.online }.map { $0.id })
    }

    /// Title and text of the notification for one event.
    static func text(for e: HubEvent) -> (title: String, body: String) {
        let who = [e.account, e.game].filter { !$0.isEmpty }.joined(separator: " · ")
        switch e.kind {
        case "catch":
            let rarity = e.detail.isEmpty ? "" : "\(e.detail): "
            return ("🎣 \(rarity)\(e.title)", who)
        case "trouble":
            return ("⚠️ \(Lingo.event(e.title))", e.detail.isEmpty ? who : "\(who)\n\(Lingo.detail(e.detail))")
        default:
            return (Lingo.event(e.title), e.detail.isEmpty ? who : "\(who) · \(Lingo.detail(e.detail))")
        }
    }
}
