import SwiftUI
import Charts

struct OverviewView: View {
    @EnvironmentObject var store: HubStore
    @State private var metric = "cash"
    @State private var hours = 6
    @State private var points: [HistoryPoint] = []

    private let ranges: [(String, String)] = [("session", "Session"), ("today", "Heute"), ("7d", "7 Tage"), ("all", "Alles")]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if store.accounts.count > 1 { accountSwitch }
                    if let error = store.error { ErrorBanner(text: error) }
                    if let o = store.shown {
                        tiles(o)
                        if let next = o.nextRebirth { rebirth(next) }
                        chart
                        rarities(o)
                        events(o)
                    } else {
                        ProgressView().padding(60)
                    }
                }
                .padding(16)
            }
            .refreshable {
                await store.refresh()
                await loadHistory()
            }
            .screenBackground()
            .navigationTitle(store.who.isEmpty ? "Übersicht" : "Hi, \(store.who)")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    LiveChip(online: (store.overview?.online ?? 0) > 0, at: store.lastUpdate)
                }
            }
            .task(id: "\(metric)-\(hours)-\(store.account)") { await loadHistory() }
        }
    }

    @MainActor
    private func loadHistory() async {
        let m = metric, h = hours, a = store.account
        if let p = await store.call({ try await store.api.history(metric: m, hours: h, account: a) }) { points = p }
    }

    /// All accounts together, or one: pills that scroll sideways, with a dot
    /// for whether that account's instance is online.
    private var accountSwitch: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                accountPill("", title: "Alle", online: (store.overview?.online ?? 0) > 0)
                ForEach(store.accounts, id: \.self) { name in
                    accountPill(name, title: name,
                                online: (store.overview?.agents ?? []).contains(where: { $0.account == name && $0.online }))
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func accountPill(_ value: String, title: String, online: Bool) -> some View {
        let on = store.account == value
        return Button {
            guard store.account != value else { return }
            store.account = value
            Task { await store.refresh() }
        } label: {
            HStack(spacing: 7) {
                if !value.isEmpty { StatusDot(online: online) }
                Text(title).font(.system(size: 13.5, weight: .semibold))
            }
            .foregroundColor(on ? Color(hex: 0x09090B) : Theme.text)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(on ? Theme.text : Color.white.opacity(0.05))
            .overlay(Capsule().stroke(on ? Color.clear : Theme.line2, lineWidth: 1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: sections

    private func tiles(_ o: Overview) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            Tile(caption: "Online", value: "\(o.online) / \(o.total)", icon: "dot.radiowaves.left.and.right",
                 sub: o.online == o.total ? "alle laufen" : "\(o.total - o.online) offline",
                 tint: o.online > 0 ? Theme.good : Theme.muted)
            Tile(caption: "Cash / s", value: Format.number(o.cashPerSec), icon: "dollarsign.circle",
                 sub: Format.number(o.cashPerSec * 3600) + " pro Stunde")
            Tile(caption: "Fänge / min", value: Format.number(o.catchesPerMin), icon: "fish",
                 sub: Format.number(o.catches) + " diese Session")
            Tile(caption: "Gems / min", value: Format.number(o.gemsPerMin), icon: "diamond",
                 sub: Format.number(o.gems) + " gesamt")
            Tile(caption: "Cash", value: Format.number(o.cash), icon: "banknote")
            Tile(caption: "Rebirths", value: Format.number(o.rebirths), icon: "arrow.triangle.2.circlepath")
        }
    }

    private func rebirth(_ next: NextRebirth) -> some View {
        Card(title: "Nächster Rebirth", icon: "arrow.triangle.2.circlepath") {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(next.short <= 0 ? "bereit" : "in \(Format.duration(next.eta))")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(next.short <= 0 ? Theme.good : Theme.text)
                    Text(next.account).font(.system(size: 13)).foregroundColor(Theme.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("kostet \(Format.number(next.cost))").font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.text)
                    if next.short > 0 {
                        Text("fehlen \(Format.number(next.short))").font(.system(size: 13)).foregroundColor(Theme.muted)
                    }
                }
            }
            if next.cost > 0 {
                ProgressView(value: max(0, min(1, 1 - next.short / next.cost)))
                    .tint(Theme.accent)
            }
        }
    }

    private var chart: some View {
        Card(title: "Verlauf", icon: "chart.xyaxis.line") {
            SegPicker(selection: $metric, options: [("cash", "Cash"), ("gems", "Gems"), ("catches", "Fänge")])

            if points.isEmpty || points.allSatisfy({ $0.value == 0 }) {
                Text("Noch keine Daten in diesem Zeitraum.")
                    .font(.system(size: 14)).foregroundColor(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                Chart(points) { p in
                    AreaMark(x: .value("Zeit", p.date), y: .value("pro Stunde", p.value))
                        .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.45), Theme.accent.opacity(0.02)],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Zeit", p.date), y: .value("pro Stunde", p.value))
                        .foregroundStyle(Theme.accent)
                        .interpolationMethod(.monotone)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(Theme.outline)
                        AxisValueLabel {
                            if let v = value.as(Double.self) { Text(Format.number(v)).foregroundColor(Theme.muted) }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Theme.outline)
                        AxisValueLabel().foregroundStyle(Theme.muted)
                    }
                }
                .frame(height: 170)
            }

            HStack {
                Text("pro Stunde, alle zusammen").font(.system(size: 12)).foregroundColor(Theme.faint)
                Spacer()
                SegPicker(selection: $hours, options: [(6, "6 h"), (24, "24 h"), (168, "7 T")]).frame(width: 170)
            }
        }
    }

    private func rarities(_ o: Overview) -> some View {
        Card(title: "Fänge nach Seltenheit", icon: "sparkles") {
            SegPicker(selection: $store.rarityRange, options: ranges)
                .onChange(of: store.rarityRange) { _ in Task { await store.refresh() } }

            let list = o.raritiesBestFirst
            if list.isEmpty {
                Text("Noch nichts gefangen.").font(.system(size: 14)).foregroundColor(Theme.muted)
            } else {
                // log scale: one God next to 800 Commons is still a bar you can see
                let top = log10((list.map { $0.count }.max() ?? 1) + 1)
                VStack(spacing: 9) {
                    ForEach(list) { row in
                        HStack(spacing: 10) {
                            RarityText(name: row.name, size: 14).frame(width: 110, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.04))
                                    Capsule()
                                        .fill(Theme.gradient(rarity: row.name))
                                        .frame(width: max(8, geo.size.width * CGFloat(log10(row.count + 1) / max(0.3, top))))
                                        .shadow(color: Theme.color(rarity: row.name).opacity(0.45), radius: 4)
                                }
                            }
                            .frame(height: 7)
                            Text(Format.number(row.count))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.text)
                                .frame(width: 56, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private func events(_ o: Overview) -> some View {
        Card(title: "Zuletzt", icon: "clock") {
            if o.events.isEmpty {
                Text("Noch nichts passiert.").font(.system(size: 14)).foregroundColor(Theme.muted)
            } else {
                VStack(spacing: 10) {
                    ForEach(o.events.prefix(8)) { e in EventRow(event: e) }
                }
            }
        }
    }
}
