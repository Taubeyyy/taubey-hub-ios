import Foundation

/// Real push through Apple (APNs) - the pure parts, so the CI checks them.
///
/// The server sends every alert it makes (a problem, an account going quiet
/// or coming back, a good catch, the daily summary) to every iPhone that
/// handed it a device token. That needs an Apple developer key on the server;
/// until one is there - or if Apple refuses a TrollStore-signed app - the
/// app keeps looking for news itself (Notifier.check).
enum PushLogic {
    /// APNs hands the token over as bytes; the server wants it as hex.
    static func hex(_ token: Data) -> String {
        token.map { String(format: "%02x", $0) }.joined()
    }

    /// Which tab a push opens, by the `view` the server puts in it.
    static func tab(for view: String) -> Int {
        switch view {
        case "accounts", "sessions", "instances": return 1
        case "inventory": return 2
        // the events live on the overview since Trade took their tab
        case "activity", "events": return 0
        case "trade": return 3
        case "alerts", "account": return 4
        default: return 0
        }
    }

    /// Whether the server's answer to /api/apns/device means pushes really
    /// arrive: a key on the server, one push through, and no refusal since.
    static func working(_ answer: JSONValue) -> Bool {
        (answer["configured"].bool ?? false) && answer["lastOk"].string != nil && answer["lastError"].string == nil
    }
}

/// What the server pushes about (GET /api/alerts), and whether it can.
struct AlertSettings: Equatable {
    var trouble = true
    var silent = true
    var back = true
    var summary = true
    var catches = ""
    /// characters announced whatever their rarity
    var catchNames: [String] = []
    var appPush = false
    var appDevices = 0
    /// every message goes through Bark (since 2026-11-19): is a key saved?
    var barkSet = false
    /// the key's last four characters, to recognise it
    var barkHint = ""

    init() {}

    init(_ j: JSONValue) {
        let a = j["alerts"]
        trouble = a["trouble"].bool ?? true
        silent = a["silent"].bool ?? true
        back = a["back"].bool ?? true
        summary = a["summary"].bool ?? true
        catches = a["catches"].string ?? ""
        catchNames = a["catchNames"].strings
        appPush = j["apns"]["available"].bool ?? false
        appDevices = j["apns"]["devices"].int ?? 0
        barkSet = j["barkSet"].bool ?? false
        barkHint = j["barkHint"].string ?? ""
    }
}
