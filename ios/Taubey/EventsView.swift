import SwiftUI

struct EventsView: View {
    @EnvironmentObject var store: HubStore
    @State private var events: [HubEvent] = []
    @State private var kind = ""
    @State private var loaded = false

    private let kinds: [(String, String)] = [("", "Alle"), ("catch", "Fänge"), ("trouble", "Probleme"), ("server", "Server")]

    var body: some View {
        NavigationStack {
            List {
                SegPicker(selection: $kind, options: kinds)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                if let error = store.error { ErrorBanner(text: error).listRowBackground(Color.clear) }
                if loaded && events.isEmpty {
                    EmptyHint(icon: "bell.slash", title: "Keine Events", text: "Hier landen gute Fänge, Rejoins und Probleme.")
                        .listRowBackground(Color.clear)
                }
                // one section per day, newest first
                let days = Dictionary(grouping: events) { Calendar.current.startOfDay(for: $0.at) }
                ForEach(days.keys.sorted(by: >), id: \.self) { day in
                    Section {
                        ForEach(days[day] ?? []) { e in
                            EventRow(event: e).rowSurface()
                        }
                    } header: {
                        Text(dayTitle(day)).foregroundColor(Theme.muted)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .screenBackground()
            .refreshable { await load() }
            .navigationTitle("Events")
            .task(id: kind) { await load() }
        }
    }

    @MainActor
    private func load() async {
        let k = kind
        if let list = await store.call({ try await store.api.events(kind: k) }) { events = list }
        loaded = true
    }
}

struct EventRow: View {
    let event: HubEvent

    private var icon: (String, Color) {
        switch event.kind {
        case "catch": return ("sparkles", Theme.warn)
        case "trouble": return ("exclamationmark.triangle.fill", Theme.bad)
        case "server": return ("arrow.triangle.2.circlepath", Theme.accent)
        default: return ("circle.fill", Theme.muted)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon.0)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(icon.1)
                .frame(width: 30, height: 30)
                .background(icon.1.opacity(0.14))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(event.kind == "catch" ? event.title : Lingo.event(event.title))
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.text).lineLimit(2)
                    if event.kind == "catch" && !event.detail.isEmpty { RarityText(name: event.detail, size: 12) }
                }
                if event.kind != "catch" && !event.detail.isEmpty {
                    Text(Lingo.detail(event.detail)).font(.system(size: 12)).foregroundColor(Theme.muted).lineLimit(2)
                }
                Text("\(event.account) · \(Format.ago(event.at))").font(.system(size: 11)).foregroundColor(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}
