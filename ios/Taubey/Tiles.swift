import SwiftUI

/// A character's picture in a frame of its rarity's colours. Without a
/// picture (none exists yet, or it is still loading) its initials in the
/// rarity's colours - so a missing picture looks meant, not broken.
struct Portrait: View {
    let name: String
    let game: String
    let rarity: String
    var size: CGFloat = 56
    var radius: CGFloat = 14
    /// bumped after a picture changed, so it is asked for again
    var bust: Int = 0

    private var url: URL? {
        guard let url = HubAPI.imageURL(game: game, name: name) else { return nil }
        return bust == 0 ? url : URL(string: url.absoluteString + "?v=\(bust)")
    }

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
                    .transition(.opacity)
            } else {
                Text(Portrait.initials(name))
                    .font(.system(size: size * 0.34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.gradient(rarity: rarity))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(size * 0.08)
                    .shadow(color: Theme.color(rarity: rarity).opacity(0.5), radius: size * 0.08)
            }
        }
        .frame(width: size, height: size)
        .background(
            LinearGradient(colors: [Theme.color(rarity: rarity).opacity(0.22), Theme.raised],
                           startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Theme.gradient(rarity: rarity), lineWidth: 2)
        )
        .shadow(color: Theme.color(rarity: rarity).opacity(0.35), radius: 8, y: 2)
    }

    /// "Mari Kita II" -> "MK", "CeCe" -> "Ce", "AI Hoshi" -> "AH"
    static func initials(_ name: String) -> String {
        let words = name.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        // a trailing roman numeral is a version, not a name
        let named = words.filter { !$0.allSatisfy { "IVX".contains($0) } || words.count == 1 }
        if named.count >= 2 { return named.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }.joined() }
        guard let one = named.first ?? words.first else { return "?" }
        return String(one.prefix(2)).capitalized
    }
}

/// One stand in the grid: number in the corner, the character's picture,
/// level and income - or a dashed "+" when it is empty, a lock when locked.
struct StandTile: View {
    let stand: PlotStand
    let game: String

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                if stand.has {
                    Portrait(name: stand.name, game: game, rarity: stand.rarity, size: 74, radius: 16)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .foregroundColor(Theme.line2)
                        .frame(width: 74, height: 74)
                        .overlay(
                            Image(systemName: stand.locked ? "lock.fill" : "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Theme.faint)
                        )
                }
                if stand.held || stand.pinned {
                    Image(systemName: stand.held ? "hand.raised.fill" : "pin.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(stand.held ? Theme.warn : Theme.accent))
                        .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
                        .offset(x: 6, y: -6)
                }
            }
            .overlay(alignment: .topLeading) {
                Text(stand.shortNumber)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.text)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.ink.opacity(0.85)))
                    .offset(x: -5, y: -5)
            }
            VStack(spacing: 1) {
                Text(stand.has ? stand.name : (stand.locked ? "gesperrt" : "frei"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(stand.has ? Theme.text : Theme.faint)
                    .lineLimit(1)
                Text(stand.has ? "Lv \(stand.level) · \(Format.number(stand.cps))" : " ")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.4), value: stand.cps)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(Theme.surface.opacity(stand.has ? 0.72 : 0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .opacity(stand.locked && !stand.has ? 0.55 : 1)
        .accessibilityElement(children: .combine)
    }
}

/// One job in the grid: what kind it is, who works there.
struct JobTile: View {
    let job: PlotJob
    let game: String

    private var icon: String {
        switch job.kind {
        case "Gardens": return "leaf.fill"
        case "Lemon stand": return "cup.and.saucer.fill"
        case "Fishing dock": return "ferry.fill"
        default: return "briefcase.fill"
        }
    }

    var body: some View {
        HStack(spacing: 11) {
            ZStack(alignment: .bottomTrailing) {
                if job.busy && !job.whoName.isEmpty {
                    Portrait(name: job.whoName, game: game, rarity: job.whoRarity, size: 50, radius: 13)
                } else {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .foregroundColor(Theme.line2)
                        .frame(width: 50, height: 50)
                        .overlay(Image(systemName: "plus").foregroundColor(Theme.faint))
                }
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Theme.accent))
                    .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
                    .offset(x: 6, y: 6)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(job.name).font(.system(size: 13.5, weight: .semibold)).foregroundColor(Theme.text).lineLimit(1)
                    if job.held { Image(systemName: "hand.raised.fill").font(.system(size: 10)).foregroundColor(Theme.warn) }
                }
                Text(job.busy ? (job.whoName.isEmpty ? "besetzt" : job.whoName) : "frei")
                    .font(.system(size: 12)).foregroundColor(job.busy ? Theme.muted : Theme.warn).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
