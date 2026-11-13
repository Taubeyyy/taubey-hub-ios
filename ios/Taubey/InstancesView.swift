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
                if let o = store.overview, !agents.isEmpty {
                    HStack(spacing: 10) {
                        Tile(caption: "Online", value: "\(o.online) / \(o.total)", icon: "dot.radiowaves.left.and.right",
                             tint: o.online == o.total ? Theme.good : Theme.warn)
                        Tile(caption: "Cash / s", value: Format.number(o.cashPerSec), icon: "dollarsign.circle")
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
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
            Avatar(name: agent.account, size: 38, online: agent.online)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(agent.account).font(.system(size: 16, weight: .semibold)).foregroundColor(Theme.text)
                    if agent.paused {
                        Text("PAUSE").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.warn)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Theme.warn.opacity(0.15)).clipShape(Capsule())
                    }
                    if agent.pending > 0 {
                        Text("SENDET").font(.system(size: 9.5, weight: .bold)).foregroundColor(Theme.accent)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Theme.accentSoft).clipShape(Capsule())
                    }
                }
                Text(agent.online ? (agent.note.isEmpty ? "läuft" : Lingo.value(agent.note)) : "offline · vor \(Format.duration(Double(agent.age ?? 0)))")
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
    @State private var plot: PlotReport?
    @Environment(\.dismiss) private var dismiss

    /// The newest copy from the store, so the screen follows the refreshes.
    private var agent: Agent {
        store.overview?.agents.first { $0.id == agentId } ?? fallback
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header.appear(0)
                actions.appear(1)
                plotCard.appear(2)
                stats.appear(3)
                settingsCard.appear(4)
                Button(role: .destructive) { confirmRemove = true } label: {
                    Text("Instanz aus dem Dashboard entfernen")
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .foregroundColor(Theme.bad)
                .buttonStyle(PressStyle())
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(agent.account)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await store.refresh()
            plot = (try? await store.api.plot(agent: agentId)) ?? plot
        }
        .task { plot = try? await store.api.plot(agent: agentId) }
        .confirmationDialog("Eigene Einstellungen dieser Instanz verwerfen?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Zurücksetzen", role: .destructive) {
                Task {
                    if await store.call({ try await store.api.reset(agent: agentId) }) != nil { store.say("✓ Folgt wieder dem Standard") }
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

    private var plotCard: some View {
                Card(title: "Stände & Jobs", icon: "square.grid.3x3") {
                    NavigationLink {
                        PlotView(agent: agent)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.accent)
                                .frame(width: 30, height: 30)
                                .background(Theme.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plot.map { "\($0.occupied) von \($0.stands.count) Ständen belegt" } ?? "Stände, Jobs & Leveln")
                                    .font(.system(size: 15, weight: .medium)).foregroundColor(Theme.text)
                                Text(plot.map { "\(Format.number($0.income))/s · Futter \(Format.number($0.food))" } ?? "Aus der App steuern")
                                    .font(.system(size: 12)).foregroundColor(Theme.faint)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.muted)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityIdentifier("plotLink")
                }
    }

    private var settingsCard: some View {
                Card(title: "Einstellungen", icon: "slider.horizontal.3") {
                    NavigationLink {
                        SettingsEditor(agent: agent)
                    } label: {
                        row("Einstellungen bearbeiten", icon: "gearshape", detail: agent.overrides > 0 ? "\(agent.overrides) eigene" : nil)
                    }
                    Divider().background(Theme.outline)
                    Button { confirmReset = true } label: {
                        row("Auf Spiel-Standard zurücksetzen", icon: "arrow.uturn.backward", detail: nil)
                    }
                }
    }

    private var status: String {
        agent.online ? (agent.note.isEmpty ? "läuft" : Lingo.value(agent.note)) : "offline"
    }

    /// Who, what it is doing, and what it earns - the same shape as the
    /// overview's top card.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Avatar(name: agent.account, size: 46, online: agent.online)
                VStack(alignment: .leading, spacing: 3) {
                    Text(agent.game).font(.system(size: 12.5)).foregroundColor(Theme.muted).lineLimit(1)
                    Text(status)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(agent.online ? Theme.text : Theme.faint)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .id(status)
                        .transition(.opacity)
                }
                .animation(.easeOut(duration: 0.25), value: status)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text("läuft seit").font(.system(size: 11.5)).foregroundColor(Theme.faint)
                    Text(Format.duration(Double(agent.uptime ?? 0)))
                        .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(Theme.text)
                }
            }
            Text("CASH PRO SEKUNDE").font(.system(size: 10.5, weight: .bold)).kerning(1).foregroundColor(Theme.faint)
                .padding(.top, 20)
            Text(Format.number(agent.metric("cashPerSec")))
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .kerning(-1)
                .foregroundColor(Theme.text)
                .lineLimit(1).minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.4), value: agent.metric("cashPerSec"))
                .padding(.top, 6)
            Rectangle().fill(Theme.line).frame(height: 1).padding(.vertical, 16)
            FigureRow(items: [
                ("Fänge / min", Format.number(agent.metric("catchesPerMin"))),
                ("Cash", Format.number(agent.metric("cash"))),
                ("Rebirths", Format.number(agent.metric("rebirths"))),
            ])
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RadialGradient(colors: [Theme.accent.opacity(0.26), .clear], center: .topTrailing, startRadius: 0, endRadius: 260))
        .cardSurface(radius: 18)
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
            Haptics.tap()
            Task { await work() }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(title).font(.system(size: 12, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(tint.opacity(0.07))
            .cardSurface()
        }
        .buttonStyle(PressStyle(scale: 0.93))
    }

    private var stats: some View {
        Card(title: "Was das Script meldet", icon: "text.alignleft") {
            let lines = agent.statLines + (agent.metrics["rod"]?.string.map { [("Rod", $0)] } ?? [])
            if lines.isEmpty {
                Text("Noch nichts gemeldet.").font(.system(size: 14)).foregroundColor(Theme.muted)
            } else {
                VStack(spacing: 8) {
                    ForEach(lines.indices, id: \.self) { i in
                        HStack(alignment: .top) {
                            Text(Lingo.label(lines[i].0)).font(.system(size: 14)).foregroundColor(Theme.muted)
                            Spacer(minLength: 12)
                            Text(Lingo.value(lines[i].1)).font(.system(size: 14, weight: .medium)).foregroundColor(Theme.text)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
        }
    }

    private func row(_ title: String, icon: String, detail: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.accent)
                .frame(width: 30, height: 30)
                .background(Theme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let detail = detail { Chip(text: detail) }
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.muted)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
