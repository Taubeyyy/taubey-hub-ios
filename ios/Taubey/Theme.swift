import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: opacity)
    }
}

/// The web dashboard's tokens (taubey-hub/dashboard.html :root), so the app
/// and the site are one thing.
enum Theme {
    static let ink = Color(hex: 0x070709)          // --bg
    static let surface = Color(hex: 0x0E0E12)      // --panel
    static let raised = Color(hex: 0x15151B)       // --panel-2
    static let line = Color.white.opacity(0.06)    // --line
    static let line2 = Color.white.opacity(0.11)   // --line-2
    static let outline = line
    static let text = Color(hex: 0xF4F4F7)         // --text
    static let muted = Color(hex: 0xA1A1AD)        // --dim
    static let faint = Color(hex: 0x6B6B78)        // --dim-2
    static let accent = Color(hex: 0x7C5CFF)       // --accent
    static let accentSoft = Color(hex: 0x7C5CFF, opacity: 0.14)
    static let good = Color(hex: 0x2EE6A6)
    static let warn = Color(hex: 0xFFB547)
    static let bad = Color(hex: 0xFF5D6C)
    static let radius: CGFloat = 14

    // the dashboard's RCOL / RGRAD, so a rarity has the same colour everywhere
    static let rarityColor: [String: UInt32] = [
        "Common": 0xC4C4C4, "Uncommon": 0x3DFF7E, "Rare": 0x00D4FF, "Epic": 0xC21CFF, "Legendary": 0xFFD200,
        "Mythical": 0xFF3030, "Cosmic": 0xD024FF, "Secret": 0x8C8CAB, "Rainbow": 0x7DFF1A, "Ascended": 0x8A5CFF,
        "Divine": 0xF0A33C, "Supreme": 0x33FF4D, "Celestial": 0x8A45FF, "Ancient": 0xFFC000, "God": 0xF01E9A,
        "Omniscient": 0xFF2020, "Apex": 0x9BE9FF, "Transcendent": 0xFF6A1F, "Exclusive": 0x8A2BFF,
    ]
    static let rarityGradient: [String: [UInt32]] = [
        "Common": [0xA9A9A9, 0xE2E2E2], "Uncommon": [0x3DFF7E, 0xA8FFC6], "Rare": [0x00D4FF, 0x7AF3FF],
        "Epic": [0xC21CFF, 0xEC8DFF], "Legendary": [0xFFF200, 0xFFB800], "Mythical": [0xFF3030, 0xD4001E],
        "Cosmic": [0xA51CFF, 0xFF2DF2], "Secret": [0x707090, 0xB3B3CC],
        "Rainbow": [0xFF6A00, 0xFFD000, 0x7DFF1A, 0x1AE0FF], "Ascended": [0xA52BFF, 0x6D8DFF],
        "Divine": [0xFFBF00, 0xD47AD0], "Supreme": [0x1F9A10, 0x33FF4D], "Celestial": [0xFF2D2D, 0x6C4BFF, 0xFF38D8],
        "Ancient": [0xFFE600, 0xFF9800], "God": [0xFF2424, 0xE01CFF], "Omniscient": [0xFF2B2B, 0xC8000F, 0xFF2B2B],
        "Apex": [0xFFFFFF, 0x7FE8FF, 0xFFD36B, 0xFFFFFF], "Transcendent": [0xE03A0B, 0xFF7A22, 0xFF3D0E],
        "Exclusive": [0xB21CFF, 0x5A2BFF, 0xB21CFF],
    ]

    static func color(rarity: String) -> Color {
        if let hex = rarityColor[rarity] { return Color(hex: hex) }
        // unknown tier: a colour from its name (the same on every launch -
        // hashValue is not) rather than grey
        let sum = rarity.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return Color(hue: Double(sum % 360) / 360, saturation: 0.7, brightness: 0.95)
    }

    static func gradient(rarity: String) -> LinearGradient {
        let stops = (rarityGradient[rarity] ?? []).map { Color(hex: $0) }
        let colors = stops.isEmpty ? [color(rarity: rarity), color(rarity: rarity)] : stops
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - the website's ambience: slow drifting light over a faint grid

struct Ambience: View {
    @State private var drift = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.ink
                Circle()
                    .fill(Theme.accent.opacity(0.22))
                    .frame(width: 420, height: 420)
                    .blur(radius: 90)
                    .offset(x: drift ? -geo.size.width * 0.05 : -geo.size.width * 0.3, y: drift ? -geo.size.height * 0.32 : -geo.size.height * 0.44)
                    .animation(.easeInOut(duration: 26).repeatForever(autoreverses: true), value: drift)
                Circle()
                    .fill(Theme.good.opacity(0.09))
                    .frame(width: 380, height: 380)
                    .blur(radius: 90)
                    .offset(x: drift ? geo.size.width * 0.2 : geo.size.width * 0.42, y: drift ? geo.size.height * 0.3 : geo.size.height * 0.45)
                    .animation(.easeInOut(duration: 32).repeatForever(autoreverses: true), value: drift)
                GridLines()
                    .stroke(Theme.line, lineWidth: 1)
                    .mask(RadialGradient(colors: [.black, .clear], center: .top, startRadius: 0, endRadius: geo.size.height * 0.7))
                    .opacity(0.6)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { drift = true }
    }

    private struct GridLines: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            let step: CGFloat = 44
            var x: CGFloat = 0
            while x <= rect.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: rect.height)); x += step }
            var y: CGFloat = 0
            while y <= rect.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: rect.width, y: y)); y += step }
            return p
        }
    }
}

extension View {
    func screenBackground() -> some View {
        self.background(Ambience())
    }

    /// The card surface: a breath of white from the top, a hairline edge.
    func cardSurface(radius: CGFloat = Theme.radius) -> some View {
        self
            .background(
                LinearGradient(colors: [Color.white.opacity(0.035), Color.white.opacity(0.012)], startPoint: .top, endPoint: .bottom)
                    .background(Theme.surface.opacity(0.72))
            )
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }

    /// List rows on the card surface.
    func rowSurface() -> some View {
        self.listRowBackground(Theme.surface.opacity(0.72)).listRowSeparatorTint(Theme.line2)
    }
}

// MARK: - building blocks

struct Card<Content: View>: View {
    var title: String? = nil
    var icon: String? = nil
    var trailing: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title = title {
                HStack(spacing: 9) {
                    if let icon = icon {
                        Image(systemName: icon).foregroundColor(Theme.muted).font(.system(size: 14, weight: .semibold))
                    }
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.text)
                    Spacer()
                    if let trailing = trailing { Chip(text: trailing) }
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

struct Tile: View {
    let caption: String
    let value: String
    var icon: String? = nil
    var sub: String? = nil
    var tint: Color = Theme.text

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                if let icon = icon { Image(systemName: icon).font(.system(size: 11, weight: .bold)) }
                Text(caption.uppercased()).font(.system(size: 10.5, weight: .bold)).kerning(1)
            }
            .foregroundColor(Theme.faint)
            Text(value)
                .font(.system(size: 25, weight: .heavy, design: .rounded))
                .kerning(-0.4)
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.4), value: value)
                .padding(.top, 9)
            if let sub = sub {
                Text(sub).font(.system(size: 11.5)).foregroundColor(Theme.faint).lineLimit(1).padding(.top, 5)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

struct Chip: View {
    let text: String
    var tint: Color? = nil

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundColor(tint ?? Theme.muted)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background((tint ?? .white).opacity(tint == nil ? 0.05 : 0.08))
            .overlay(Capsule().stroke((tint ?? .white).opacity(tint == nil ? 0.06 : 0.3), lineWidth: 1))
            .clipShape(Capsule())
    }
}

/// The site's segmented pills: the chosen one white with dark text.
struct SegPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]
    /// the white pill is one shape that slides from choice to choice
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { i in
                let on = options[i].0 == selection
                Button {
                    guard !on else { return }
                    Haptics.tap()
                    withAnimation(Motion.snap) { selection = options[i].0 }
                } label: {
                    Text(options[i].1)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(on ? Color(hex: 0x09090B) : Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if on { Capsule().fill(Theme.text).matchedGeometryEffect(id: "pill", in: pill) }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.04))
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
        .clipShape(Capsule())
    }
}

struct RarityText: View {
    let name: String
    var size: CGFloat = 15

    var body: some View {
        Text(name)
            .font(.system(size: size, weight: .heavy))
            .foregroundColor(.clear)
            .overlay(Theme.gradient(rarity: name).mask(Text(name).font(.system(size: size, weight: .heavy))))
            .shadow(color: .black.opacity(0.9), radius: 0.5, x: 0, y: 1)
    }
}

struct StatusDot: View {
    let online: Bool
    var body: some View {
        Circle()
            .fill(online ? Theme.good : Theme.faint)
            .frame(width: 8, height: 8)
            .shadow(color: online ? Theme.good.opacity(0.8) : .clear, radius: 5)
    }
}

struct ErrorBanner: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.warn)
            Text(text).font(.system(size: 13.5)).foregroundColor(Theme.text)
            Spacer()
        }
        .padding(12)
        .background(Theme.warn.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.warn.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EmptyHint: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 32)).foregroundColor(Theme.faint)
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(Theme.text)
            Text(text).font(.system(size: 13.5)).foregroundColor(Theme.faint).multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
    }
}

/// The accent button with the site's glow.
struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Theme.accent.opacity(configuration.isPressed ? 0.2 : 0.45), radius: 16, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.snap, value: configuration.isPressed)
    }
}
