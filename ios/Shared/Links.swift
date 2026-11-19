import Foundation

/// taubey://open?view=<view> - what a Bark push opens when it is tapped. The
/// view names are the ones the server already uses for the web dashboard's
/// sections, so one name means the same place in both.
enum HubLink {
    static func tab(for url: URL) -> Int? {
        guard url.scheme?.lowercased() == "taubey" else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let view = items.first { $0.name == "view" }?.value ?? (url.host == "open" ? "" : url.host ?? "")
        return PushLogic.tab(for: view.lowercased())
    }

    /// The link the server puts into a Bark push for a view.
    static func url(view: String) -> String {
        view.isEmpty ? "taubey://open" : "taubey://open?view=" + view
    }
}

/// A build on GitHub's release page (build-<n> with Taubey.ipa), for updating
/// from inside the app: TrollStore installs an IPA from a link.
struct AppRelease: Equatable {
    let build: Int
    let ipa: URL
    let title: String

    init?(_ j: JSONValue) {
        guard let tag = j["tag_name"].string, tag.hasPrefix("build-"), let n = Int(tag.dropFirst(6)) else { return nil }
        let assets = j["assets"].array ?? []
        guard let asset = assets.first(where: { ($0["name"].string ?? "").lowercased().hasSuffix(".ipa") }),
              let link = asset["browser_download_url"].string, let url = URL(string: link) else { return nil }
        build = n
        ipa = url
        title = j["name"].string ?? "Build \(n)"
    }

    init(build: Int, ipa: URL, title: String) {
        self.build = build
        self.ipa = ipa
        self.title = title
    }

    static let latestURL = URL(string: "https://api.github.com/repos/Taubeyyy/taubey-hub-ios/releases/latest")!

    /// TrollStore's own link: it downloads the IPA and installs it over this app.
    var installURL: URL? {
        var c = URLComponents()
        c.scheme = "apple-magnifier"
        c.host = "install"
        c.queryItems = [URLQueryItem(name: "url", value: ipa.absoluteString)]
        return c.url
    }

    /// newer than what runs?
    func isNewer(than build: Int) -> Bool { self.build > build }
}
