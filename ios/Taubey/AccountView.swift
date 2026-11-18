import SwiftUI

struct AccountView: View {
    @EnvironmentObject var store: HubStore
    @EnvironmentObject var notifier: Notifier
    @State private var confirmLogout = false

    /// the instance that takes the pictures: the first one online
    private var pictureAgent: Agent? { (store.overview?.agents ?? []).first { $0.online } }

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

                PushSection()

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

                // the game has its pictures only inside the game: one online
                // instance reads them there and sends them to the server
                Section {
                    Button {
                        guard let id = pictureAgent?.id else { return }
                        Task { _ = await store.run("dump.pictures", args: [:], agent: id, patience: 60) }
                    } label: { Label("Bilder der Tränke und Kisten holen", systemImage: "photo.on.rectangle") }
                    .disabled(pictureAgent == nil)
                    NavigationLink {
                        MissingPicturesView()
                    } label: { Label("Fehlende Charakterbilder", systemImage: "camera.viewfinder") }
                } header: {
                    Text("Bilder aus dem Spiel")
                } footer: {
                    (Text(pictureAgent.map { "Tränke und Kisten liest \($0.account) im Spiel aus. " } ?? "Für Tränke und Kisten muss eine Instanz online sein. ")
                        + Text("Charakterbilder machst du selbst per Screenshot – das Script stellt die Figur dafür groß ins Bild."))
                        .foregroundColor(Theme.faint)
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
