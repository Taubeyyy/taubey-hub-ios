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
                        .offset(x: 2, y: 2)
                }
            }
    }
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
