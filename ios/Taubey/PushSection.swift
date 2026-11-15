import SwiftUI

/// The settings for notifications: whether real push works, what the server
/// pushes about, and - only while real push is not working - what the app
/// looks for itself.
@MainActor
struct PushSection: View {
    @EnvironmentObject var store: HubStore
    @EnvironmentObject var notifier: Notifier
    @State private var settings = AlertSettings()
    @State private var testing = false

    var body: some View {
        Group {
            Section {
                if notifier.allowed == false {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: {
                        Label("Mitteilungen sind aus – in den Einstellungen erlauben", systemImage: "bell.slash")
                            .foregroundColor(Theme.warn)
                    }
                }
                HStack(spacing: 10) {
                    Image(systemName: notifier.pushActive ? "checkmark.seal.fill" : "exclamationmark.circle")
                        .foregroundColor(notifier.pushActive ? Theme.good : Theme.warn)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(notifier.pushActive ? "Echter Push ist an" : "Echter Push läuft noch nicht")
                            .foregroundColor(Theme.text)
                        if !notifier.pushNote.isEmpty {
                            Text(notifier.pushNote).font(.system(size: 13)).foregroundColor(Theme.muted)
                        }
                    }
                }
                .padding(.vertical, 2)
                Button {
                    Task { await test() }
                } label: {
                    Label(testing ? "Wird geschickt …" : "Test-Push schicken", systemImage: "paperplane")
                }
                .disabled(testing)
            } header: {
                Text("Push")
            } footer: {
                Text("Echter Push kommt vom Server über Apple – sofort, auch wenn die App zu ist. Dafür braucht der Server einen Apple-Developer-Schlüssel.")
                    .foregroundColor(Theme.faint)
            }
            .rowSurface()

            if settings.appPush {
                Section {
                    Toggle(isOn: bind(\.trouble, "trouble")) { Label("Probleme", systemImage: "exclamationmark.triangle") }
                    Toggle(isOn: bind(\.silent, "silent")) { Label("Account geht offline", systemImage: "bolt.horizontal.circle") }
                    Toggle(isOn: bind(\.back, "back")) { Label("Account ist wieder da", systemImage: "checkmark.circle") }
                    Toggle(isOn: bind(\.summary, "summary")) { Label("Tagesbericht", systemImage: "doc.text") }
                    HStack {
                        Label("Fänge ab", systemImage: "sparkles").foregroundColor(Theme.text)
                        Spacer()
                        Text(settings.catches.isEmpty ? "aus" : settings.catches).foregroundColor(Theme.muted)
                    }
                } header: {
                    Text("Worüber der Server pusht")
                } footer: {
                    Text("Ab welcher Seltenheit ein Fang zählt, stellst du im Web-Dashboard unter Alerts ein.")
                        .foregroundColor(Theme.faint)
                }
                .tint(Theme.accent)
                .rowSurface()
            }

            if !notifier.pushActive {
                Section {
                    Toggle(isOn: $notifier.catches) { Label("Gute Fänge", systemImage: "sparkles") }
                    Toggle(isOn: $notifier.trouble) { Label("Probleme", systemImage: "exclamationmark.triangle") }
                    Toggle(isOn: $notifier.offline) { Label("Instanz geht offline", systemImage: "bolt.horizontal.circle") }
                    Toggle(isOn: $notifier.server) { Label("Rejoins und Serverwechsel", systemImage: "arrow.triangle.2.circlepath") }
                } header: {
                    Text("Ohne Push: die App schaut selbst")
                } footer: {
                    Text("Bei offener App sofort, sonst wenn iOS die App im Hintergrund kurz weckt – das entscheidet iOS, meist alle 15 Minuten bis paar Stunden.")
                        .foregroundColor(Theme.faint)
                }
                .tint(Theme.accent)
                .rowSurface()
            }
        }
        .task { await load() }
    }

    /// A switch that saves itself on the server the moment it moves.
    private func bind(_ key: WritableKeyPath<AlertSettings, Bool>, _ name: String) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: key] },
            set: { value in
                settings[keyPath: key] = value
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
            Notifier.shared.rememberCatchRule(settings)
        }
    }

    private func test() async {
        testing = true
        defer { testing = false }
        guard let answer = await store.call({ try await store.api.post("/api/alerts/test") }) else { return }
        let sent = answer["apns"].int ?? 0
        if sent > 0 {
            notifier.confirmPush()
            store.say("Test-Push an \(sent) iPhone geschickt")
        } else {
            let why = answer["apnsErrors"][0].string
                ?? (settings.appPush ? "kein iPhone beim Server angemeldet" : "dem Server fehlt der Apple-Schlüssel")
            notifier.pushNote = "Test ging nicht durch: \(why)"
            store.say("Kein Push: \(why)")
        }
        await load()
    }
}
