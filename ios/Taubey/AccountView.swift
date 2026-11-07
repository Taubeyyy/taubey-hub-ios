import SwiftUI

struct AccountView: View {
    @EnvironmentObject var store: HubStore
    @EnvironmentObject var notifier: Notifier
    @State private var confirmLogout = false

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 40)).foregroundColor(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.who.isEmpty ? "Angemeldet" : store.who)
                                .font(.system(size: 18, weight: .semibold)).foregroundColor(Theme.text)
                            Text("über taubey.com").font(.system(size: 13)).foregroundColor(Theme.muted)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .rowSurface()

                Section {
                    if notifier.allowed == false {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        } label: {
                            Label("Mitteilungen sind aus – in den Einstellungen erlauben", systemImage: "bell.slash")
                                .foregroundColor(Theme.warn)
                        }
                    }
                    Toggle(isOn: $notifier.catches) { Label("Gute Fänge", systemImage: "sparkles") }
                    Toggle(isOn: $notifier.trouble) { Label("Probleme", systemImage: "exclamationmark.triangle") }
                    Toggle(isOn: $notifier.offline) { Label("Instanz geht offline", systemImage: "bolt.horizontal.circle") }
                    Toggle(isOn: $notifier.server) { Label("Rejoins und Serverwechsel", systemImage: "arrow.triangle.2.circlepath") }
                } header: {
                    Text("Mitteilungen")
                } footer: {
                    Text("Welche Fänge zählen, stellst du im Web-Dashboard unter Alerts ein. Bei offener App kommen Mitteilungen sofort, sonst wenn iOS die App im Hintergrund kurz weckt – das entscheidet iOS, meist alle 15 Minuten bis paar Stunden.")
                        .foregroundColor(Theme.faint)
                }
                .tint(Theme.accent)
                .rowSurface()

                if let o = store.overview, !o.groups.isEmpty, o.groups.contains(where: { !$0.name.isEmpty }) {
                    Section("Gruppen") {
                        ForEach(o.groups, id: \.name) { g in
                            HStack {
                                Text(g.name.isEmpty ? "ohne Gruppe" : g.name).foregroundColor(Theme.text)
                                Spacer()
                                Text("\(g.online) / \(g.total) online").foregroundColor(Theme.muted)
                            }
                        }
                    }
                    .rowSurface()
                }

                Section("Alle Instanzen") {
                    let ids = (store.overview?.agents ?? []).filter { $0.online }.map { $0.id }
                    Button { Task { await store.command("rejoin", agents: ids) } } label: {
                        Label("Alle online neu joinen (\(ids.count))", systemImage: "arrow.clockwise")
                    }
                    .disabled(ids.isEmpty)
                    Button { Task { await store.command("refresh", agents: ids) } } label: {
                        Label("Alle neu einlesen", systemImage: "arrow.down.circle")
                    }
                    .disabled(ids.isEmpty)
                }
                .rowSurface()

                Section {
                    Link(destination: URL(string: "https://taubey.com/dashboard")!) {
                        Label("Web-Dashboard öffnen", systemImage: "safari")
                    }
                    Button(role: .destructive) { confirmLogout = true } label: {
                        Label("Abmelden", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .foregroundColor(Theme.bad)
                } footer: {
                    Text("Taubey Hub \(version)").foregroundColor(Theme.muted)
                }
                .rowSurface()
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Konto")
            .confirmationDialog("Abmelden? Danach brauchst du einen neuen Code vom Dashboard.", isPresented: $confirmLogout,
                                titleVisibility: .visible) {
                Button("Abmelden", role: .destructive) { store.signOut() }
            }
        }
    }
}
