import SwiftUI

struct InstancesView: View {
    @EnvironmentObject var store: HubStore

    private var games: [String] {
        Array(Set((store.overview?.agents ?? []).map { $0.game })).sorted()
    }

    var body: some View {
        NavigationStack {
            List {
                if let error = store.error {
                    ErrorBanner(text: error).listRowBackground(Color.clear)
                }
                let agents = store.overview?.agents ?? []
                if agents.isEmpty, store.overview != nil {
                    EmptyHint(icon: "desktopcomputer", title: "Keine Instanzen",
                              text: "Starte ein Script und schalte im Menü unter Settings > Dashboard „Report to the dashboard“ ein.")
                        .listRowBackground(Color.clear)
                }
                ForEach(games, id: \.self) { game in
                    Section {
                        NavigationLink {
                            SettingsEditor(game: game)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.accent)
                                    .frame(width: 30, height: 30)
                                    .background(Theme.accentSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Einstellungen für alle").font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text)
                                    Text("Standard für jede Instanz – auch offline").font(.system(size: 12)).foregroundColor(Theme.faint)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .rowSurface()
                        ForEach(agents.filter { $0.game == game }.sorted(by: order)) { agent in
                            NavigationLink(value: agent) { AgentRow(agent: agent) }
                                .rowSurface()
                                .swipeActions(edge: .trailing) {
                                    Button { Task { await store.command("hop", agents: [agent.id]) } } label: {
                                        Label("Server", systemImage: "arrow.left.arrow.right")
                                    }
                                    .tint(Theme.accent)
                                    Button { Task { await store.command("rejoin", agents: [agent.id]) } } label: {
                                        Label("Rejoin", systemImage: "arrow.clockwise")
                                    }
                                    .tint(Theme.warn)
                                }
                                .swipeActions(edge: .leading) {
                                    Button { Task { await store.setPaused(!agent.paused, agent: agent) } } label: {
                                        Label(agent.paused ? "Weiter" : "Pause", systemImage: agent.paused ? "play.fill" : "pause.fill")
                                    }
                                    .tint(agent.paused ? Theme.good : Theme.muted)
                                }
                        }
                    } header: {
                        Text(game).foregroundColor(Theme.muted)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .screenBackground()
            .refreshable { await store.refresh() }
            .navigationTitle("Instanzen")
            .navigationDestination(for: Agent.self) { agent in
                InstanceDetailView(agentId: agent.id, fallback: agent)
            }
        }
    }

    /// Online first, then by name.
    private func order(_ a: Agent, _ b: Agent) -> Bool {
        if a.online != b.online { return a.online }
        return a.account.lowercased() < b.account.lowercased()
    }
}

struct AgentRow: View {
    let agent: Agent

    var body: some View {
        HStack(spacing: 12) {
            StatusDot(online: agent.online)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(agent.account).font(.system(size: 16, weight: .semibold)).foregroundColor(Theme.text)
                    if agent.paused {
                        Text("PAUSE").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.warn)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Theme.warn.opacity(0.15)).clipShape(Capsule())
                    }
                    if agent.pending > 0 {
                        Image(systemName: "arrow.up.circle").font(.system(size: 12)).foregroundColor(Theme.accent)
                    }
                }
                Text(agent.online ? agent.note : "offline · zuletzt \(Format.duration(Double(agent.age ?? 0))) her")
                    .font(.system(size: 13)).foregroundColor(Theme.muted).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(Format.number(agent.metric("cashPerSec")) + "/s")
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(Theme.text)
                Text(Format.number(agent.metric("catchesPerMin")) + " Fänge/min")
                    .font(.system(size: 12)).foregroundColor(Theme.muted)
            }
        }
        .padding(.vertical, 4)
    }
}

struct InstanceDetailView: View {
    @EnvironmentObject var store: HubStore
    let agentId: String
    let fallback: Agent
    @State private var confirmRemove = false
    @State private var confirmReset = false
    @Environment(\.dismiss) private var dismiss

    /// The newest copy from the store, so the screen follows the refreshes.
    private var agent: Agent {
        store.overview?.agents.first { $0.id == agentId } ?? fallback
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                actions
                stats
                Card(title: "Einstellungen", icon: "slider.horizontal.3") {
                    NavigationLink {
                        SettingsEditor(agent: agent)
                    } label: {
                        row("Script-Einstellungen bearbeiten", icon: "gearshape", detail: agent.overrides > 0 ? "\(agent.overrides) eigene" : nil)
                    }
                    Divider().background(Theme.outline)
                    Button { confirmReset = true } label: {
                        row("Auf Spiel-Standard zurücksetzen", icon: "arrow.uturn.backward", detail: nil)
                    }
                }
                Button(role: .destructive) { confirmRemove = true } label: {
                    Text("Instanz aus dem Dashboard entfernen")
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .foregroundColor(Theme.bad)
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(agent.account)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refresh() }
        .confirmationDialog("Eigene Einstellungen dieser Instanz verwerfen?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Zurücksetzen", role: .destructive) {
                Task {
                    if await store.call({ try await store.api.reset(agent: agentId) }) != nil { store.say("Folgt wieder dem Standard") }
                }
            }
        }
        .confirmationDialog("Instanz entfernen? Sie taucht wieder auf, sobald das Script sich meldet.", isPresented: $confirmRemove,
                            titleVisibility: .visible) {
            Button("Entfernen", role: .destructive) {
                Task {
                    if await store.call({ try await store.api.remove(agent: agentId) }) != nil {
                        await store.refresh()
                        dismiss()
                    }
                }
            }
        }
    }

    private var header: some View {
        Card {
            HStack(spacing: 12) {
                StatusDot(online: agent.online)
                VStack(alignment: .leading, spacing: 3) {
                    Text(agent.game).font(.system(size: 13)).foregroundColor(Theme.muted)
                    Text(agent.online ? (agent.note.isEmpty ? "läuft" : agent.note) : "offline")
                        .font(.system(size: 17, weight: .semibold)).foregroundColor(Theme.text)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("seit").font(.system(size: 12)).foregroundColor(Theme.muted)
                    Text(Format.duration(Double(agent.uptime ?? 0))).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.text)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                Tile(caption: "Cash / s", value: Format.number(agent.metric("cashPerSec")), icon: "dollarsign.circle")
                Tile(caption: "Fänge / min", value: Format.number(agent.metric("catchesPerMin")), icon: "fish")
                Tile(caption: "Cash", value: Format.number(agent.metric("cash")), icon: "banknote")
                Tile(caption: "Rebirths", value: Format.number(agent.metric("rebirths")), icon: "arrow.triangle.2.circlepath")
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            action(agent.paused ? "Weiter" : "Pause", icon: agent.paused ? "play.fill" : "pause.fill",
                   tint: agent.paused ? Theme.good : Theme.warn) {
                await store.setPaused(!agent.paused, agent: agent)
            }
            action("Rejoin", icon: "arrow.clockwise", tint: Theme.accent) {
                await store.command("rejoin", agents: [agentId])
            }
            action("Server", icon: "arrow.left.arrow.right", tint: Theme.accent) {
                await store.command("hop", agents: [agentId])
            }
            action("Neu lesen", icon: "arrow.down.circle", tint: Theme.muted) {
                await store.command("refresh", agents: [agentId])
            }
        }
    }

    private func action(_ title: String, icon: String, tint: Color, _ work: @escaping () async -> Void) -> some View {
        Button {
            Task { await work() }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(title).font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(tint.opacity(0.07))
            .cardSurface()
        }
        .buttonStyle(.plain)
    }

    private var stats: some View {
        Card(title: "Was das Script meldet", icon: "list.bullet.rectangle") {
            let lines = agent.statLines
            if lines.isEmpty {
                Text("Noch nichts gemeldet.").font(.system(size: 14)).foregroundColor(Theme.muted)
            } else {
                VStack(spacing: 8) {
                    ForEach(lines.indices, id: \.self) { i in
                        HStack(alignment: .top) {
                            Text(lines[i].0).font(.system(size: 14)).foregroundColor(Theme.muted)
                            Spacer(minLength: 12)
                            Text(lines[i].1).font(.system(size: 14, weight: .medium)).foregroundColor(Theme.text)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            if let rod = agent.metrics["rod"]?.string {
                HStack {
                    Text("Rute").font(.system(size: 14)).foregroundColor(Theme.muted)
                    Spacer()
                    Text(rod).font(.system(size: 14, weight: .medium)).foregroundColor(Theme.text)
                }
            }
        }
    }

    private func row(_ title: String, icon: String, detail: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(Theme.accent).frame(width: 22)
            Text(title).font(.system(size: 15)).foregroundColor(Theme.text)
            Spacer()
            if let detail = detail { Text(detail).font(.system(size: 13)).foregroundColor(Theme.muted) }
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.muted)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
