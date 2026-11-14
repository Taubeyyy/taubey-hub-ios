import SwiftUI

/// One character from the inventory: a big picture, what it is, and what can
/// be done with it - put it on a stand or to work, lock it, change its
/// picture. Moves go to the account picked at the top of the inventory.
@MainActor
struct CharacterSheet: View {
    @EnvironmentObject var store: HubStore
    let item: Item
    let game: String
    /// The instance of the picked account; nil while "Alle" is picked.
    let agent: String?
    let account: String
    var onPicture: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var plot: PlotReport?
    @State private var picture = false
    @State private var locked: Bool

    init(item: Item, game: String, agent: String?, account: String, onPicture: @escaping () -> Void = {}) {
        self.item = item
        self.game = game
        self.agent = agent
        self.account = account
        self.onPicture = onPicture
        _locked = State(initialValue: item.locked)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        Portrait(name: item.name, game: game, rarity: item.rarity, size: 112, radius: 26)
                        VStack(spacing: 5) {
                            Text(item.name).font(.system(size: 22, weight: .bold)).foregroundColor(Theme.text)
                            HStack(spacing: 7) {
                                RarityText(name: item.rarity, size: 14)
                                if !item.mutation.isEmpty { Chip(text: item.mutation, tint: Theme.accent) }
                            }
                        }
                        FigureRow(items: [
                            ("Anzahl", "×\(item.count)"),
                            ("Level", item.level > 0 ? "\(item.level)" : "1"),
                            ("Einkommen", Format.number(item.cps) + "/s"),
                        ])
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .rowSurface()

                if let agent = agent {
                    Section {
                        NavigationLink {
                            StandPicker(item: item, game: game, plot: plot) { stand in
                                Task { await store.run("stand.swap", args: ["stand": .string(stand.id), "key": .string(item.key)], agent: agent) }
                                dismiss()
                            }
                        } label: { Label("Auf einen Stand setzen …", systemImage: "square.grid.3x3") }
                        NavigationLink {
                            JobPicker(item: item, game: game, plot: plot) { job in
                                Task { await store.run("job.set", args: ["job": .string(job.id), "key": .string(item.key)], agent: agent) }
                                dismiss()
                            }
                        } label: { Label("Zum Arbeiten schicken …", systemImage: "briefcase") }
                        Toggle(isOn: Binding(get: { locked }, set: { value in
                            locked = value
                            Task { await store.run("char.lock", args: ["key": .string(item.key), "on": .bool(value)], agent: agent) }
                        })) { Label("Gesperrt (wird nie verkauft)", systemImage: "lock") }
                            .tint(Theme.accent)
                    } header: {
                        Text("Auf \(account)")
                    }
                    .rowSurface()
                } else {
                    Section {
                        Label("Wähle oben im Inventar einen Account, dann kannst du ihn setzen.", systemImage: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 14)).foregroundColor(Theme.muted)
                    }
                    .rowSurface()
                }

                Section {
                    Button { picture = true } label: { Label("Bild ändern", systemImage: "photo") }
                }
                .rowSurface()
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .task {
                if let agent = agent { plot = try? await store.api.plot(agent: agent) }
            }
            .sheet(isPresented: $picture) {
                PictureSheet(item: item, game: game) { onPicture() }
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// Every stand of the account as a grid, each with what the move would do to
/// its income.
private struct StandPicker: View {
    let item: Item
    let game: String
    let plot: PlotReport?
    let pick: (PlotStand) -> Void

    var body: some View {
        ScrollView {
            if let plot = plot {
                let stands = plot.stands.filter { !$0.locked }.sorted { $0.number < $1.number }
                Text("Grün = mehr Einkommen als jetzt, rot = weniger.")
                    .font(.system(size: 12.5)).foregroundColor(Theme.faint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(stands) { stand in
                        Button {
                            Haptics.tap()
                            pick(stand)
                        } label: {
                            VStack(spacing: 5) {
                                StandTile(stand: stand, game: game)
                                delta(stand)
                            }
                        }
                        .buttonStyle(PressStyle(scale: 0.95))
                    }
                }
            } else {
                Skeleton(height: 320).padding(.top, 8)
            }
        }
        .padding(16)
        .screenBackground()
        .navigationTitle("Welcher Stand?")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func delta(_ stand: PlotStand) -> some View {
        let change = item.cps - (stand.has ? stand.cps : 0)
        return Text((change >= 0 ? "+" : "−") + Format.number(abs(change)) + "/s")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(change >= 0 ? Theme.good : Theme.bad)
    }
}

/// The jobs of the account, with who works there now.
private struct JobPicker: View {
    let item: Item
    let game: String
    let plot: PlotReport?
    let pick: (PlotJob) -> Void

    var body: some View {
        ScrollView {
            if let plot = plot {
                if plot.jobs.isEmpty {
                    EmptyHint(icon: "briefcase", title: "Keine Jobs", text: "Auf diesem Plot gibt es keine Jobs.")
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(plot.jobs) { job in
                        Button {
                            Haptics.tap()
                            pick(job)
                        } label: { JobTile(job: job, game: game) }
                        .buttonStyle(PressStyle(scale: 0.96))
                    }
                }
            } else {
                Skeleton(height: 200).padding(.top, 8)
            }
        }
        .padding(16)
        .screenBackground()
        .navigationTitle("Welcher Job?")
        .navigationBarTitleDisplayMode(.inline)
    }
}
