import SwiftUI

/// Notifications: since 2026-11-19 every message goes through Bark - the app
/// sends none of its own and asks for no permission. Here: whether Bark is
/// connected, a test, which catches count and what else is reported. Tapping
/// a Bark message opens this app on the right tab (taubey://).
@MainActor
struct PushSection: View {
    @EnvironmentObject var store: HubStore
    @State private var settings = AlertSettings()
    @State private var loaded = false
    @State private var testing = false
    @State private var key = ""

    var body: some View {
        Group {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: settings.barkSet ? "checkmark.seal.fill" : "exclamationmark.circle")
                        .foregroundColor(settings.barkSet ? Theme.good : Theme.warn)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(settings.barkSet ? "Bark ist verbunden" : (loaded ? "Bark ist noch nicht eingerichtet" : "Lädt …"))
                            .foregroundColor(Theme.text)
                        if settings.barkSet && !settings.barkHint.isEmpty {
                            Text("Schlüssel \(settings.barkHint)").font(.system(size: 13)).foregroundColor(Theme.muted)
                        }
                    }
                }
                .padding(.vertical, 2)
                if loaded && !settings.barkSet {
                    TextField("Bark-Schlüssel oder Bark-Link einfügen", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button { Task { await saveKey() } } label: { Label("Speichern", systemImage: "checkmark") }
                        .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Button {
                    Task { await test() }
                } label: {
                    Label(testing ? "Wird geschickt …" : "Test-Nachricht an Bark", systemImage: "paperplane")
                }
                .disabled(testing || !settings.barkSet)
            } header: {
                Text("Bark")
            } footer: {
                Text("Alle Nachrichten kommen über Bark, auch wenn diese App zu ist. Tippst du eine an, öffnet sich Taubey am passenden Tab.")
                    .foregroundColor(Theme.faint)
            }
            .rowSurface()

            // the one choice for catches: Bark, the dashboard and the pop-ups in
            // the game all follow it
            Section {
                Menu {
                    Picker("Fänge ab", selection: Binding(get: { settings.catches }, set: { setFloor($0) })) {
                        Text("Aus").tag("")
                        ForEach(ladder.reversed(), id: \.self) { tier in Text(tier).tag(tier) }
                    }
                } label: {
                    HStack {
                        Label("Fänge ab", systemImage: "sparkles").foregroundColor(Theme.text)
                        Spacer()
                        if settings.catches.isEmpty {
                            Text("aus").foregroundColor(Theme.muted)
                        } else {
                            RarityText(name: settings.catches, size: 15)
                        }
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.faint)
                    }
                }
                if !settings.catchNames.isEmpty {
                    HStack(alignment: .top) {
                        Label("Immer bei", systemImage: "star").foregroundColor(Theme.text)
                        Spacer()
                        Text(settings.catchNames.joined(separator: ", ")).foregroundColor(Theme.muted).multilineTextAlignment(.trailing)
                    }
                }
            } header: {
                Text("Welche Fänge gemeldet werden")
            } footer: {
                Text("Gilt überall: Bark, die Events hier, das Dashboard und die Pop-ups im Spiel. Diese Seltenheit und besser.")
                    .foregroundColor(Theme.faint)
            }
            .rowSurface()

            Section {
                Toggle(isOn: bind(\.trouble, "trouble")) { Label("Probleme", systemImage: "exclamationmark.triangle") }
                Toggle(isOn: bind(\.silent, "silent")) { Label("Account geht offline", systemImage: "bolt.horizontal.circle") }
                Toggle(isOn: bind(\.back, "back")) { Label("Account ist wieder da", systemImage: "checkmark.circle") }
                Toggle(isOn: bind(\.summary, "summary")) { Label("Tagesbericht", systemImage: "doc.text") }
            } header: {
                Text("Was sonst über Bark kommt")
            } footer: {
                Text("Der Watchdog auf dem Handy meldet sich nur, wenn er einen Account nach drei Neustarts nicht zurückholt.")
                    .foregroundColor(Theme.faint)
            }
            .tint(Theme.accent)
            .rowSurface()
        }
        .task { await load() }
    }

    /// The rarity ladder as the scripts report it, worst first.
    private var ladder: [String] {
        let l = store.overview?.ladder ?? []
        return l.isEmpty ? ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Cosmic", "Secret", "Rainbow", "Ascended",
                            "Divine", "Supreme", "Celestial", "Ancient", "God", "Omniscient", "Apex", "Transcendent", "Paradox", "Exclusive"] : l
    }

    /// The catch floor, saved on the server at once - from there Bark and the
    /// game's pop-ups take it.
    private func setFloor(_ tier: String) {
        guard tier != settings.catches else { return }
        Haptics.tap()
        settings.catches = tier
        Task {
            if await store.call({ try await store.api.post("/api/alerts", .object(["alerts": .object(["catches": .string(tier)])])) }) == nil {
                await load()
            } else {
                store.say(tier.isEmpty ? "Fänge werden nicht mehr gemeldet" : "Fänge ab \(tier) werden gemeldet")
            }
        }
    }

    /// A switch that saves itself on the server the moment it moves.
    private func bind(_ path: WritableKeyPath<AlertSettings, Bool>, _ name: String) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: path] },
            set: { value in
                settings[keyPath: path] = value
                Task {
                    if await store.call({ try await store.api.post("/api/alerts", .object(["alerts": .object([name: .bool(value)])])) }) == nil {
                        await load()
                    }
                }
            }
        )
    }

    private func load() async {
        if let answer = try? await store.api.get("/api/alerts") {
            settings = AlertSettings(answer)
        }
        loaded = true
    }

    /// the key itself or a whole Bark link - the server picks the key out
    private func saveKey() async {
        let raw = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        if await store.call({ try await store.api.post("/api/alerts", .object(["bark": .string(raw)])) }) != nil {
            key = ""
            store.say("Bark gespeichert")
            Haptics.success()
            await load()
        }
    }

    private func test() async {
        testing = true
        defer { testing = false }
        guard let answer = await store.call({ try await store.api.post("/api/alerts/test") }) else { return }
        if answer["bark"].bool == true {
            store.say("Test ist bei Bark angekommen")
            Haptics.success()
        } else {
            store.say("Bark hat nicht angenommen: \(answer["barkError"].string ?? "unbekannt")")
            Haptics.failure()
        }
    }
}
