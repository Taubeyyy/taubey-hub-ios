import SwiftUI

/// The Trade tab: a request that waits (with its countdown), the trade that is
/// open, everyone in the script's server, the trusted players, the automatic
/// and the history. Follows the script live; every tap goes back as a command.
@MainActor
struct TradeView: View {
    @EnvironmentObject var store: HubStore
    @State private var account = ""
    @State private var live: TradeLive?
    @State private var version = 0
    @State private var loaded = false
    @State private var showSession = false
    @State private var newTrust = ""

    /// the instances that can trade - Fish an Anime, online first
    private var agents: [Agent] {
        (store.overview?.agents ?? []).filter { $0.game.lowercased().contains("fish") }
            .sorted { a, b in a.online != b.online ? a.online : a.account.lowercased() < b.account.lowercased() }
    }

    private var agent: Agent? { agents.first { $0.account == account } ?? agents.first }

    var body: some View {
        NavigationStack {
            List {
                if agents.count > 1 {
                    Section {
                        AccountChips(selection: $account, accounts: agents.map { $0.account }) { name in
                            agents.contains { $0.account == name && $0.online }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 6, trailing: 0))
                }
                if let error = store.error { ErrorBanner(text: error).listRowBackground(Color.clear) }
                if let live = live {
                    if let request = live.request { requestSection(request) }
                    if live.open { openSection(live) }
                    playersSection(live)
                    trustedSection(live)
                    autoSection(live)
                    if !live.log.isEmpty { logSection(live) }
                } else if loaded {
                    EmptyHint(icon: "arrow.left.arrow.right", title: "Noch keine Trade-Daten",
                              text: "Das Script meldet sich nach dem nächsten Rejoin mit seinem Trade-Tab. Danach steht hier alles live.")
                        .listRowBackground(Color.clear)
                } else {
                    Section { ForEach(0..<4, id: \.self) { _ in SkeletonRow().rowSurface() } }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Trade")
            .refreshable { await command("trade.refresh", quiet: true) }
            .task(id: agent?.id ?? "") { await follow() }
            .onChange(of: live?.open ?? false) { open in showSession = open }
            .fullScreenCover(isPresented: $showSession) {
                TradeSessionView(live: $live, game: agent?.game ?? "", send: { cmd, args in
                    Task { await command(cmd, args, quiet: cmd == "trade.offer" || cmd == "trade.unoffer") }
                })
            }
        }
    }

    // MARK: following the script

    /// Waits on the server for each new version; a fresh one replaces the old.
    private func follow() async {
        guard let id = agent?.id else { loaded = true; return }
        version = 0
        live = nil
        loaded = false
        var misses = 0
        while !Task.isCancelled {
            do {
                let answer = try await store.api.tradeLive(agent: id, version: version)
                misses = 0
                loaded = true
                if answer.version != version || live == nil {
                    version = answer.version
                    withAnimation(.easeOut(duration: 0.25)) { live = answer.live }
                }
                // nothing posted yet, or the demo: no answer waits, so this does
                if answer.version == 0 || store.api.demo { try? await Task.sleep(nanoseconds: 3_000_000_000) }
            } catch {
                misses += 1
                loaded = true
                try? await Task.sleep(nanoseconds: UInt64(min(misses, 5)) * 1_000_000_000)
            }
        }
    }

    /// A tap in here: quiet ones (putting things in) just go, the rest is
    /// followed step by step with a toast.
    private func command(_ cmd: String, _ args: [String: JSONValue] = [:], quiet: Bool = false) async {
        guard let id = agent?.id else { return }
        Haptics.tap()
        if quiet {
            if await store.call({ try await store.api.gameCommand(cmd, args: args, agent: id) }) == nil {
                store.say("Nicht gesendet – keine Verbindung")
            }
        } else {
            await store.run(cmd, args: args, agent: id, patience: 5)
        }
    }

    private func setOption(_ key: String, _ value: JSONValue) {
        guard let agent = agent else { return }
        Haptics.tap()
        Task {
            if await store.call({ try await store.api.apply(changes: [key: value], agent: agent.id, game: agent.game, asDefault: false) }) != nil {
                store.say("Gespeichert – kommt in ein paar Sekunden an")
            }
        }
    }

    // MARK: sections

    private func requestSection(_ request: TradeRequest) -> some View {
        Section {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let left = request.left(now: context.date)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Avatar(name: request.name, size: 42, online: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(request.name) will traden").font(.system(size: 16, weight: .semibold)).foregroundColor(Theme.text)
                            Text(left > 0 ? "noch \(left) s" + (request.trusted ? " · vertraut" : "") : "abgelaufen")
                                .font(.system(size: 13)).foregroundColor(left > 5 ? Theme.muted : Theme.warn)
                        }
                        Spacer(minLength: 0)
                    }
                    ProgressView(value: Double(left), total: 20).tint(Theme.accent)
                    HStack(spacing: 10) {
                        Button { Task { await command("trade.respond", ["yes": .bool(false)]) } } label: {
                            Label("Ablehnen", systemImage: "xmark").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderless)
                        .padding(.vertical, 10)
                        .background(Theme.bad.opacity(0.14))
                        .foregroundColor(Theme.bad)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        Button { Task { await command("trade.respond", ["yes": .bool(true)]) } } label: {
                            Label("Annehmen", systemImage: "checkmark").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderless)
                        .padding(.vertical, 10)
                        .background(Theme.good.opacity(0.16))
                        .foregroundColor(Theme.good)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .accessibilityIdentifier("tradeAcceptRequest")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .disabled(left == 0)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Anfrage").foregroundColor(Theme.muted)
        }
        .rowSurface()
    }

    private func openSection(_ live: TradeLive) -> some View {
        Section {
            Button { showSession = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Theme.accentFill)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trade mit \(live.partnerLabel)" + (live.partnerTrusted ? " ★" : ""))
                            .font(.system(size: 16, weight: .semibold)).foregroundColor(Theme.text)
                        Text(live.status).font(.system(size: 12.5)).foregroundColor(Theme.muted).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.faint)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("tradeOpen")
        } header: {
            Text("Läuft gerade").foregroundColor(Theme.muted)
        }
        .rowSurface()
    }

    private func playersSection(_ live: TradeLive) -> some View {
        Section {
            if live.players.isEmpty {
                Text("Außer dir ist niemand im Server.").font(.system(size: 14)).foregroundColor(Theme.muted)
            }
            ForEach(live.players) { p in
                HStack(spacing: 12) {
                    Avatar(name: p.name, size: 34, online: true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.title).font(.system(size: 15, weight: .medium)).foregroundColor(Theme.text).lineLimit(1)
                        if p.trusted { Text("vertraut").font(.system(size: 11.5, weight: .semibold)).foregroundColor(Theme.accent) }
                    }
                    Spacer(minLength: 8)
                    Button { Task { await command("trade.send", ["userId": .number(Double(p.id))]) } } label: {
                        Text("Anfragen").font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Theme.accentSoft).foregroundColor(Theme.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.borderless)
                    .disabled(live.open)
                }
                .swipeActions(edge: .trailing) {
                    if !p.trusted {
                        Button { Task { await command("trade.trust", ["userId": .number(Double(p.id)), "name": .string(p.name)]) } } label: {
                            Label("Vertrauen", systemImage: "star.fill")
                        }
                        .tint(Theme.accent)
                    }
                }
            }
        } header: {
            Text("Im Server · \(live.players.count)").foregroundColor(Theme.muted)
        } footer: {
            Text("Wischen = vertrauen. Vertraute werden sofort angenommen und bestätigt.").foregroundColor(Theme.faint)
        }
        .rowSurface()
    }

    private func trustedSection(_ live: TradeLive) -> some View {
        Section {
            ForEach(live.trusted) { p in
                HStack(spacing: 12) {
                    Image(systemName: "star.fill").foregroundColor(Theme.accent)
                    Text(p.name).foregroundColor(Theme.text)
                    Spacer()
                    Text(p.id > 0 ? String(p.id) : "").font(.system(size: 12, design: .monospaced)).foregroundColor(Theme.faint)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { Task { await command("trade.untrust", ["userId": .number(Double(p.id))]) } } label: {
                        Label("Entfernen", systemImage: "trash")
                    }
                }
            }
            HStack {
                TextField("Roblox-Name hinzufügen", text: $newTrust)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    let name = newTrust.trimmingCharacters(in: .whitespaces)
                    newTrust = ""
                    Task { await command("trade.trust", ["name": .string(name)]) }
                } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 20))
                }
                .buttonStyle(.borderless)
                .disabled(newTrust.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text("Vertraut").foregroundColor(Theme.muted)
        }
        .rowSurface()
    }

    private func autoSection(_ live: TradeLive) -> some View {
        let s = live.settings
        return Section {
            Toggle(isOn: Binding(get: { s.take }, set: { setOption("TradeTrustedTake", .bool($0)) })) {
                Label("Anfragen von Vertrauten sofort annehmen", systemImage: "hand.thumbsup")
            }
            Toggle(isOn: Binding(get: { s.confirm }, set: { setOption("TradeTrustedConfirm", .bool($0)) })) {
                Label("Ihre Trades sofort bestätigen", systemImage: "checkmark.seal")
            }
            Toggle(isOn: Binding(get: { s.onlyReceive }, set: { setOption("TradeOnlyReceive", .bool($0)) })) {
                Label("Nur wenn ich nichts gebe", systemImage: "lock.shield")
            }
            Menu {
                ForEach(["0", "100K", "300K", "500K", "1M", "3M", "10M"], id: \.self) { fee in
                    Button(fee == "0" ? "Kein Limit" : fee) { setOption("TradeMaxFee", .string(fee)) }
                }
            } label: {
                HStack {
                    Label("Höchste Gebühr", systemImage: "diamond").foregroundColor(Theme.text)
                    Spacer()
                    Text(s.maxFee == "0" ? "kein Limit" : "\(s.maxFee) Gems").foregroundColor(Theme.muted)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.faint)
                }
            }
            Toggle(isOn: Binding(get: { s.ask }, set: { setOption("TradeAskPopup", .bool($0)) })) {
                Label("Andere: im Spiel fragen", systemImage: "questionmark.bubble")
            }
            Toggle(isOn: Binding(get: { s.declineOthers }, set: { setOption("TradeDeclineOthers", .bool($0)) })) {
                Label("Andere sofort ablehnen", systemImage: "hand.raised")
            }
            Toggle(isOn: Binding(get: { s.push }, set: { setOption("TradePush", .bool($0)) })) {
                Label("Über Bark melden", systemImage: "bell.badge")
            }
            Toggle(isOn: Binding(get: { s.window }, set: { setOption("TradeOwnMenu", .bool($0)) })) {
                Label("Trade-Fenster auch im Spiel", systemImage: "rectangle.on.rectangle")
            }
        } header: {
            Text("Automatik").foregroundColor(Theme.muted)
        } footer: {
            Text("Die Gebühr zahlen beide Seiten in Gems. Liegt sie über dem Limit, wartet der Trade auf dich (Bark sagt Bescheid).")
                .foregroundColor(Theme.faint)
        }
        .tint(Theme.accent)
        .rowSurface()
    }

    private func logSection(_ live: TradeLive) -> some View {
        Section {
            ForEach(live.log.indices, id: \.self) { i in
                Text(live.log[i]).font(.system(size: 13)).foregroundColor(Theme.muted)
            }
        } header: {
            Text("Verlauf").foregroundColor(Theme.muted)
        }
        .rowSurface()
    }
}

/// The trade itself, full screen: both sides on top, your things below
/// (search, filter, how many a tap puts in), accept and cancel at the bottom.
@MainActor
struct TradeSessionView: View {
    @Binding var live: TradeLive?
    let game: String
    let send: (String, [String: JSONValue]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var filter: TradeLogic.Filter = .all
    @State private var step: Int? = 1
    @State private var confirmCancel = false

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if let live = live {
                    VStack(spacing: 14) {
                        header(live)
                        side(title: "Du gibst", offers: live.mine, fee: live.selfFee, mine: true, accepted: live.selfAccepted)
                        side(title: "\(live.partnerLabel) gibt", offers: live.theirs, fee: live.otherFee, mine: false, accepted: live.otherAccepted)
                        itemsBlock(live)
                    }
                    .padding(16)
                } else {
                    EmptyHint(icon: "arrow.left.arrow.right", title: "Kein Trade offen", text: "Der Trade ist zu Ende.")
                        .padding(.top, 60)
                }
            }
            .screenBackground()
            .navigationTitle(live.map { "Trade mit \($0.partnerLabel)" } ?? "Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.down") }
                        .accessibilityIdentifier("tradeClose")
                }
            }
            .safeAreaInset(edge: .bottom) { if let live = live, live.open { actionBar(live) } }
            .confirmationDialog("Trade abbrechen?", isPresented: $confirmCancel, titleVisibility: .visible) {
                Button("Abbrechen", role: .destructive) { send("trade.cancel", [:]) }
            }
        }
    }

    private func header(_ live: TradeLive) -> some View {
        HStack(spacing: 12) {
            Avatar(name: live.partnerLabel, size: 44, online: true)
            VStack(alignment: .leading, spacing: 3) {
                Text(live.partnerLabel + (live.partnerTrusted ? " ★" : ""))
                    .font(.system(size: 17, weight: .semibold)).foregroundColor(Theme.text)
                Text(live.status).font(.system(size: 13)).foregroundColor(live.selfAccepted && live.otherAccepted ? Theme.good : Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let c = live.countdown, live.selfAccepted && live.otherAccepted {
                Text("\(c)").font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundColor(Theme.good)
                    .contentTransition(.numericText())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func side(title: String, offers: [TradeOffer], fee: Double, mine: Bool, accepted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text)
                if accepted {
                    Label("angenommen", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11.5, weight: .semibold)).foregroundColor(Theme.good)
                }
                Spacer()
                if fee > 0 {
                    Text("Gebühr \(Format.number(fee)) Gems").font(.system(size: 12)).foregroundColor(Theme.muted)
                }
            }
            if offers.isEmpty {
                Text(mine ? "Tippe unten deine Items an" : "Noch nichts").font(.system(size: 13)).foregroundColor(Theme.faint)
                    .padding(.vertical, 6)
            }
            ForEach(offers) { o in
                HStack(spacing: 10) {
                    thumb(name: o.name, kind: o.kind, rarity: o.rarity, size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(o.name).font(.system(size: 14, weight: .medium)).foregroundColor(Theme.text).lineLimit(1)
                        HStack(spacing: 5) {
                            if !o.mutation.isEmpty { MutationChip(name: o.mutation) }
                            if o.kind == "char" && o.level > 1 { Text("L\(o.level)").font(.system(size: 11.5)).foregroundColor(Theme.muted) }
                            if !o.rarity.isEmpty { RarityText(name: o.rarity, size: 11.5) }
                        }
                    }
                    Spacer(minLength: 6)
                    Text("x\(Format.number(Double(o.count)))").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(Theme.text)
                    if mine {
                        Button { send("trade.unoffer", ["gk": .string(o.gk), "n": .number(Double(TradeLogic.amount(step: step, free: o.count)))]) } label: {
                            Image(systemName: "minus").frame(width: 30, height: 30).background(Theme.raised).clipShape(Circle())
                        }
                        .buttonStyle(PressStyle())
                        Button { send("trade.unoffer", ["gk": .string(o.gk), "n": .number(Double(o.count))]) } label: {
                            Image(systemName: "xmark").frame(width: 30, height: 30).background(Theme.bad.opacity(0.16))
                                .foregroundColor(Theme.bad).clipShape(Circle())
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.text)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func itemsBlock(_ live: TradeLive) -> some View {
        let offered = live.offered
        let all = live.items ?? []
        let shown = TradeLogic.shown(all, filter: filter, search: search)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Deine Items").font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text)
                Spacer()
                Text("\(shown.count)").font(.system(size: 12)).foregroundColor(Theme.muted)
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(Theme.faint)
                TextField("Suchen", text: $search).textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            .padding(10)
            .background(Theme.raised)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            SegPicker(selection: $filter, options: TradeLogic.Filter.allCases.map { ($0, $0.rawValue) })
            HStack(spacing: 8) {
                Text("Pro Tipp").font(.system(size: 12.5)).foregroundColor(Theme.muted)
                ForEach([1, 10, 100, 0], id: \.self) { s in
                    let value: Int? = s == 0 ? nil : s
                    Button { step = value; Haptics.tap() } label: {
                        Text(s == 0 ? "Alle" : "+\(s)")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(step == value ? AnyShapeStyle(Theme.accentFill) : AnyShapeStyle(Theme.raised))
                            .foregroundColor(step == value ? .white : Theme.muted)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PressStyle())
                }
            }
            if live.items == nil {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 30)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(shown) { item in
                        itemTile(item, offered: offered[item.gk] ?? 0)
                    }
                }
            }
        }
        .padding(14)
        .cardSurface()
    }

    private func itemTile(_ item: TradeItem, offered: Int) -> some View {
        let free = max(0, item.count - offered)
        return Button {
            guard !item.locked else { Haptics.failure(); return }
            let n = TradeLogic.amount(step: step, free: free)
            guard n > 0 else { Haptics.failure(); return }
            send("trade.offer", ["gk": .string(item.gk), "n": .number(Double(n))])
        } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    thumb(name: item.name, kind: item.kind, rarity: item.rarity, size: 58)
                    if offered > 0 {
                        Text("\(Format.number(Double(offered)))")
                            .font(.system(size: 10.5, weight: .heavy)).foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Theme.accentFill).clipShape(Capsule())
                            .offset(x: 6, y: -5)
                    }
                    if item.locked {
                        Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                            .padding(4).background(Color.black.opacity(0.6)).clipShape(Circle()).offset(x: 5, y: -4)
                    }
                }
                Text(item.name).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.text).lineLimit(1)
                Text(detail(item)).font(.system(size: 10.5)).foregroundColor(Theme.color(rarity: item.rarity)).lineLimit(1)
                Text("x\(Format.number(Double(free)))").font(.system(size: 11, weight: .medium)).foregroundColor(Theme.muted)
            }
            .padding(.vertical, 10).padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(Theme.raised.opacity(offered > 0 ? 1 : 0.6))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(offered > 0 ? AnyShapeStyle(Theme.accentFill) : AnyShapeStyle(Theme.line), lineWidth: offered > 0 ? 1.5 : 1)
            )
            .opacity(item.locked || item.placed ? 0.5 : 1)
        }
        .buttonStyle(PressStyle(scale: 0.95))
    }

    private func detail(_ item: TradeItem) -> String {
        var bits: [String] = []
        if !item.mutation.isEmpty { bits.append(item.mutation) }
        if item.isCharacter { bits.append("L\(item.level)") }
        if item.isMaterial { bits.append("Material") }
        if !item.isCharacter && !item.isMaterial { bits.append("Trank") }
        if item.placed { bits.append("steht") }
        return bits.joined(separator: " · ")
    }

    /// A character's picture, or a symbol for materials and potions.
    @ViewBuilder
    private func thumb(name: String, kind: String, rarity: String, size: CGFloat) -> some View {
        if kind == "char" {
            Portrait(name: name, game: game, rarity: rarity, size: size, radius: size * 0.26)
        } else {
            Image(systemName: kind == "mat" ? "cube.fill" : "flask.fill")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(Theme.accentFill)
                .frame(width: size, height: size)
                .background(Theme.raised)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
        }
    }

    private func actionBar(_ live: TradeLive) -> some View {
        HStack(spacing: 10) {
            Button { confirmCancel = true } label: {
                Text("Abbrechen").font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.bad.opacity(0.15)).foregroundColor(Theme.bad)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressStyle())
            Button { send("trade.accept", [:]) } label: {
                Text(live.selfAccepted ? (live.otherAccepted ? "Beide bereit" : "Warte auf \(live.partnerLabel)") : "Annehmen")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(live.selfAccepted ? AnyShapeStyle(Theme.good.opacity(0.25)) : AnyShapeStyle(Theme.accentFill))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressStyle())
            .disabled(live.selfAccepted)
            .accessibilityIdentifier("tradeAccept")
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)
        .background(.ultraThinMaterial)
    }
}
