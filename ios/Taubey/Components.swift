import SwiftUI

/// "Live" with a breathing dot while instances report; the time of the last
/// update underneath it, small.
struct LiveChip: View {
    let online: Bool
    let at: Date?
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(online ? Theme.good : Theme.faint).frame(width: 7, height: 7)
                if online {
                    Circle()
                        .stroke(Theme.good.opacity(pulse ? 0 : 0.7), lineWidth: 2)
                        .frame(width: pulse ? 16 : 7, height: pulse ? 16 : 7)
                        .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulse)
                }
            }
            .frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(online ? "Live" : "Offline").font(.system(size: 12, weight: .bold)).foregroundColor(online ? Theme.good : Theme.faint)
                if let at = at {
                    Text(at, style: .time).font(.system(size: 9.5, weight: .medium)).foregroundColor(Theme.faint)
                }
            }
        }
        .padding(.leading, 6).padding(.trailing, 10).padding(.vertical, 4)
        .background(Color.white.opacity(0.05))
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
        .clipShape(Capsule())
        .onAppear { pulse = true }
    }
}

/// A round initial in a colour that belongs to the account name.
struct Avatar: View {
    let name: String
    var size: CGFloat = 36
    var online: Bool? = nil
    @State private var pulse = false

    private var tint: Color {
        let sum = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return Color(hue: Double(sum % 360) / 360, saturation: 0.55, brightness: 0.95)
    }

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.44, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [tint, tint.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            .overlay(alignment: .bottomTrailing) {
                if let online = online {
                    Circle()
                        .fill(online ? Theme.good : Theme.faint)
                        .frame(width: size * 0.3, height: size * 0.3)
                        .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
                        .background(
                            Circle()
                                .stroke(Theme.good.opacity(online && !pulse ? 0.7 : 0), lineWidth: 2)
                                .scaleEffect(pulse ? 2.1 : 1)
                                .animation(online ? .easeOut(duration: 1.8).repeatForever(autoreverses: false) : .default, value: pulse)
                        )
                        .offset(x: 2, y: 2)
                        .onAppear { pulse = true }
                }
            }
    }
}

/// "Alle" and one pill per account, a dot for whether it is online - the
/// same switch on the overview and in the inventory.
struct AccountChips: View {
    @Binding var selection: String
    let accounts: [String]
    var online: (String) -> Bool = { _ in false }
    @Namespace private var pill

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill("", title: "Alle", dot: nil)
                ForEach(accounts, id: \.self) { name in pill(name, title: name, dot: online(name)) }
            }
            .padding(.horizontal, 2)
        }
    }

    private func pill(_ value: String, title: String, dot: Bool?) -> some View {
        let on = selection == value
        return Button {
            guard selection != value else { return }
            Haptics.tap()
            withAnimation(Motion.snap) { selection = value }
        } label: {
            HStack(spacing: 7) {
                if let dot = dot { StatusDot(online: dot) }
                Text(title).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
            }
            .foregroundColor(on ? Color(hex: 0x09090B) : Theme.text)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background {
                ZStack {
                    Capsule().fill(Color.white.opacity(0.05))
                    if on { Capsule().fill(Theme.text).matchedGeometryEffect(id: "pill", in: pill) }
                }
            }
            .overlay(Capsule().stroke(on ? Color.clear : Theme.line2, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle(scale: 0.95))
    }
}

/// Small figures side by side with hairlines between - the row under a big
/// number on the overview and on an instance.
struct FigureRow: View {
    let items: [(String, String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                if i > 0 { Rectangle().fill(Theme.line2).frame(width: 1, height: 30).padding(.horizontal, 12) }
                VStack(alignment: .leading, spacing: 5) {
                    Text(items[i].0.uppercased()).font(.system(size: 9.5, weight: .bold)).kerning(0.8).foregroundColor(Theme.faint)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(items[i].1).font(.system(size: 19, weight: .heavy, design: .rounded)).foregroundColor(Theme.text)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.4), value: items[i].1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// A small tap in the hand for what happened.
enum Haptics {
    static func tap() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func failure() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

/// Events sorted into days, newest first: Heute, Gestern, then dates.
func dayTitle(_ date: Date, now: Date = Date()) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(date) { return "Heute" }
    if cal.isDateInYesterday(date) { return "Gestern" }
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_DE")
    f.dateFormat = "EEEE, d. MMMM"
    return f.string(from: date)
}
