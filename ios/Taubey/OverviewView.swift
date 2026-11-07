import SwiftUI
import Charts

struct OverviewView: View {
    @EnvironmentObject var store: HubStore
    @State private var metric = "cash"
    @State private var hours = 6
    @State private var points: [HistoryPoint] = []

    private let ranges = [("session", "Session"), ("today", "Heute"), ("7d", "7 Tage"), ("all", "Alles")]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if let error = store.error { ErrorBanner(text: error) }
                    if let o = store.overview {
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
                    if let at = store.lastUpdate {
                        Text(at, style: .time).font(.system(size: 12)).foregroundColor(Theme.muted)
                    }
                }
            }
            .task(id: "\(metric)-\(hours)") { await loadHistory() }
        }
    }

    @MainActor
    private func loadHistory() async {
        let m = metric, h = hours
        if let p = await store.call({ try await store.api.history(metric: m, hours: h) }) { points = p }
    }

    // MARK: sections

    private func tiles(_ o: Overview) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            Tile(caption: "Online", value: "\(o.online) / \(o.total)", tint: o.online > 0 ? Theme.good : Theme.muted)
            Tile(caption: "Cash / s", value: Format.number(o.cashPerSec))
            Tile(caption: "Fänge / min", value: Format.number(o.catchesPerMin))
            Tile(caption: "Gems / min", value: Format.number(o.gemsPerMin))
            Tile(caption: "Cash gesamt", value: Format.number(o.cash))
            Tile(caption: "Rebirths", value: Format.number(o.rebirths))
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
            Picker("", selection: $metric) {
                Text("Cash").tag("cash")
                Text("Gems").tag("gems")
                Text("Fänge").tag("catches")
            }
            .pickerStyle(.segmented)

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

            Picker("", selection: $hours) {
                Text("6 h").tag(6)
                Text("24 h").tag(24)
                Text("7 T").tag(168)
            }
            .pickerStyle(.segmented)
            Text("pro Stunde, alle Instanzen zusammen").font(.system(size: 12)).foregroundColor(Theme.muted)
        }
    }

    private func rarities(_ o: Overview) -> some View {
        Card(title: "Fänge nach Seltenheit", icon: "sparkles") {
            Picker("", selection: $store.rarityRange) {
                ForEach(ranges.indices, id: \.self) { i in Text(ranges[i].1).tag(ranges[i].0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: store.rarityRange) { _ in Task { await store.refresh() } }

            let list = o.raritiesBestFirst
            if list.isEmpty {
                Text("Noch nichts gefangen.").font(.system(size: 14)).foregroundColor(Theme.muted)
            } else {
                let top = list.map { $0.count }.max() ?? 1
                VStack(spacing: 8) {
                    ForEach(list) { row in
                        HStack(spacing: 10) {
                            RarityText(name: row.name, size: 14).frame(width: 110, alignment: .leading)
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.gradient(rarity: row.name))
                                    .frame(width: max(4, geo.size.width * CGFloat(row.count / max(1, top))))
                            }
                            .frame(height: 8)
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
