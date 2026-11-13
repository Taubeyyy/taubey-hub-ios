import SwiftUI
import Charts

@MainActor
struct OverviewView: View {
    @EnvironmentObject var store: HubStore
    @State private var metric = "cash"
    @State private var hours = 6
    @State private var points: [HistoryPoint] = []
    @State private var allRarities = false
    /// the point under the finger while it rests on the chart
    @State private var picked: HistoryPoint?

    private let ranges: [(String, String)] = [("session", "Session"), ("today", "Heute"), ("7d", "7 Tage"), ("all", "Alles")]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if store.accounts.count > 1 {
                        AccountChips(selection: $store.account, accounts: store.accounts) { name in
                            (store.overview?.agents ?? []).contains { $0.account == name && $0.online }
                        }
                    }
                    if let error = store.error { ErrorBanner(text: error) }
                    if let o = store.shown {
                        hero(o).appear(0)
                        if let next = o.nextRebirth { rebirth(next).appear(1) }
                        chart.appear(2)
                        rarities(o).appear(3)
                        events(o).appear(4)
                    } else {
                        Skeleton(height: 210, radius: 18)
                        Skeleton(height: 120)
                        Skeleton(height: 280)
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
            .onChange(of: store.account) { _ in Task { await store.refresh() } }
            .task(id: "\(metric)-\(hours)-\(store.account)") { await loadHistory() }
        }
    }

    @MainActor
    private func loadHistory() async {
        let m = metric, h = hours, a = store.account
        if let p = await store.call({ try await store.api.history(metric: m, hours: h, account: a) }) { points = p }
    }

    // MARK: the hero - what the farm earns, at a glance

    private func hero(_ o: Overview) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("CASH PRO SEKUNDE").font(.system(size: 10.5, weight: .bold)).kerning(1).foregroundColor(Theme.faint)
                Spacer()
                HStack(spacing: 6) {
                    StatusDot(online: o.online > 0)
                    Text(o.online == o.total ? "\(o.online) / \(o.total) online" : "\(o.total - o.online) offline")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(o.online == o.total ? Theme.good : Theme.warn)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())
            }
            Text(Format.number(o.cashPerSec))
                .font(.system(size: 46, weight: .heavy, design: .rounded))
                .kerning(-1)
                .foregroundColor(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.4), value: o.cashPerSec)
                .padding(.top, 8)
            Text("\(Format.number(o.cashPerSec * 3600)) pro Stunde · \(Format.number(o.cash)) auf dem Konto")
                .font(.system(size: 13)).foregroundColor(Theme.muted)
                .lineLimit(1).minimumScaleFactor(0.8)
            Rectangle().fill(Theme.line).frame(height: 1).padding(.vertical, 16)
            FigureRow(items: [
                ("Fänge / min", Format.number(o.catchesPerMin)),
                ("Gems / min", Format.number(o.gemsPerMin)),
                store.account.isEmpty ? ("Fänge", Format.number(o.catches)) : ("Rebirths", Format.number(o.rebirths)),
            ])
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RadialGradient(colors: [Theme.accent.opacity(0.28), .clear], center: .topTrailing, startRadius: 0, endRadius: 260)
        )
        .cardSurface(radius: 18)
    }

    // MARK: sections

    private func rebirth(_ next: NextRebirth) -> some View {
        Card(title: "Nächster Rebirth", icon: "arrow.triangle.2.circlepath", trailing: store.account.isEmpty ? next.account : nil) {
            HStack(alignment: .firstTextBaseline) {
                Text(next.short <= 0 ? "bereit" : "in \(Format.duration(next.eta))")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(next.short <= 0 ? Theme.good : Theme.text)
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("kostet \(Format.number(next.cost))").font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.text)
                    if next.short > 0 {
                        Text("fehlen \(Format.number(next.short))").font(.system(size: 12.5)).foregroundColor(Theme.muted)
                    }
                }
            }
            if next.cost > 0 {
                FillBar(fraction: CGFloat(1 - next.short / next.cost),
                        fill: LinearGradient(colors: [Theme.accent, Color(hex: 0xB49CFF)], startPoint: .leading, endPoint: .trailing),
                        glow: Theme.accent)
            }
        }
    }

    /// Hours for a day or less, weekdays for the week.
    private var timeFormat: Date.FormatStyle {
        hours > 24 ? .dateTime.weekday(.abbreviated) : .dateTime.hour()
    }

    private var chart: some View {
        Card(title: "Verlauf", icon: "chart.xyaxis.line") {
            SegPicker(selection: $metric, options: [("cash", "Cash"), ("gems", "Gems"), ("catches", "Fänge")])

            if points.isEmpty || points.allSatisfy({ $0.value == 0 }) {
                Text("Noch keine Daten in diesem Zeitraum.")
                    .font(.system(size: 14)).foregroundColor(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                Chart(points) { p in
                    AreaMark(x: .value("Zeit", p.date), y: .value("pro Stunde", p.value))
                        .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.45), Theme.accent.opacity(0.02)],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Zeit", p.date), y: .value("pro Stunde", p.value))
                        .foregroundStyle(Theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                        .interpolationMethod(.monotone)
                    if let picked = picked, picked.id == p.id {
                        RuleMark(x: .value("Zeit", picked.date))
                            .foregroundStyle(Theme.line2)
                            .lineStyle(StrokeStyle(lineWidth: 1))
                        PointMark(x: .value("Zeit", picked.date), y: .value("pro Stunde", picked.value))
                            .foregroundStyle(Theme.text)
                            .symbolSize(70)
                    }
                }
                // a finger resting on the chart reads off the point under it
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(Color.clear).contentShape(Rectangle())
                            // a short hold first, so a swipe over the chart still scrolls the page
                            .gesture(
                                LongPressGesture(minimumDuration: 0.18)
                                    .sequenced(before: DragGesture(minimumDistance: 0))
                                    .onChanged { value in
                                        guard case .second(true, let drag?) = value else { return }
                                        let x = drag.location.x - geo[proxy.plotAreaFrame].origin.x
                                        guard let date: Date = proxy.value(atX: x) else { return }
                                        let near = points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
                                        if near?.id != picked?.id {
                                            Haptics.tap()
                                            picked = near
                                        }
                                    }
                                    .onEnded { _ in withAnimation(.easeOut(duration: 0.25)) { picked = nil } }
                            )
                    }
                }
                // the axis ends a little above the highest point, not at the next
                // round power of a thousand - otherwise the curve hugs the floor
                .chartYScale(domain: 0...max(1, (points.map { $0.value }.max() ?? 1) * 1.15))
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine().foregroundStyle(Theme.outline)
                        AxisValueLabel {
                            if let v = value.as(Double.self) { Text(Format.number(v)).foregroundColor(Theme.faint) }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                        AxisValueLabel(format: timeFormat)
                            .foregroundStyle(Theme.faint)
                    }
                }
                .frame(height: 170)
            }

            HStack {
                if let picked = picked {
                    Text("\(Format.number(picked.value)) · \(picked.date.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 12.5, weight: .semibold)).foregroundColor(Theme.text)
                } else {
                    Text(store.account.isEmpty ? "pro Stunde, alle zusammen" : "pro Stunde")
                        .font(.system(size: 12)).foregroundColor(Theme.faint)
                }
                Spacer()
                SegPicker(selection: $hours, options: [(6, "6 h"), (24, "24 h"), (168, "7 T")]).frame(width: 170)
            }
        }
    }

    private func rarities(_ o: Overview) -> some View {
        Card(title: "Fänge nach Seltenheit", icon: "sparkles") {
            SegPicker(selection: $store.rarityRange, options: ranges)
                .onChange(of: store.rarityRange) { _ in Task { await store.refresh() } }

            let all = o.raritiesBestFirst
            if all.isEmpty {
                Text("Noch nichts gefangen.").font(.system(size: 14)).foregroundColor(Theme.muted)
            } else {
                // log scale: one God next to 800 Commons is still a bar you can see
                let top = log10((all.map { $0.count }.max() ?? 1) + 1)
                let list = allRarities ? all : Array(all.prefix(6))
                VStack(spacing: 10) {
                    ForEach(list) { row in
                        HStack(spacing: 10) {
                            RarityText(name: row.name, size: 13.5).frame(width: 104, alignment: .leading)
                            FillBar(fraction: CGFloat(log10(row.count + 1) / max(0.3, top)),
                                    fill: Theme.gradient(rarity: row.name), glow: Theme.color(rarity: row.name))
                            Text(Format.number(row.count))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.text)
                                .frame(width: 52, alignment: .trailing)
                        }
                    }
                }
                if all.count > 6 {
                    Button {
                        Haptics.tap()
                        withAnimation(Motion.settle) { allRarities.toggle() }
                    } label: {
                        HStack(spacing: 5) {
                            Text(allRarities ? "Weniger" : "Alle \(all.count) Seltenheiten")
                            Image(systemName: allRarities ? "chevron.up" : "chevron.down").font(.system(size: 11, weight: .bold))
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.accent)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PressStyle())
                }
            }
        }
    }

    private func events(_ o: Overview) -> some View {
        Card(title: "Zuletzt", icon: "clock") {
            if o.events.isEmpty {
                Text("Noch nichts passiert.").font(.system(size: 14)).foregroundColor(Theme.muted)
            } else {
                VStack(spacing: 12) {
                    ForEach(o.events.prefix(4)) { e in EventRow(event: e) }
                }
                Button {
                    Haptics.tap()
                    Notifier.shared.openTab = 3
                } label: {
                    HStack(spacing: 5) {
                        Text("Alle Events")
                        Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PressStyle())
            }
        }
    }
}
