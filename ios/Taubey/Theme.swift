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

/// The hub's own palette (lib/hub-ui.lua: Accent, Ink, Surface, Outline,
/// Text, TextMuted) so the app looks like the menu and the dashboard.
enum Theme {
    static let ink = Color(hex: 0x08080D)
    static let surface = Color(hex: 0x0F0F16)
    static let raised = Color(hex: 0x16161F)
    static let outline = Color(hex: 0x1F1F28)
    static let text = Color(hex: 0xE8E8F0)
    static let muted = Color(hex: 0x9696A2)
    static let accent = Color(hex: 0x7C5CFF)
    static let accentSoft = Color(hex: 0x7C5CFF, opacity: 0.16)
    static let good = Color(hex: 0x3DDC84)
    static let warn = Color(hex: 0xFFB020)
    static let bad = Color(hex: 0xFF4D5E)

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
        let h = Double(sum % 360) / 360
        return Color(hue: h, saturation: 0.7, brightness: 0.95)
    }

    static func gradient(rarity: String) -> LinearGradient {
        let stops = (rarityGradient[rarity] ?? []).map { Color(hex: $0) }
        let colors = stops.isEmpty ? [color(rarity: rarity), color(rarity: rarity)] : stops
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }
}

struct Card<Content: View>: View {
    var title: String? = nil
    var icon: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                HStack(spacing: 8) {
                    if let icon = icon {
                        Image(systemName: icon).foregroundColor(Theme.accent).font(.system(size: 13, weight: .semibold))
                    }
                    Text(title.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .kerning(0.8)
                        .foregroundColor(Theme.muted)
                    Spacer()
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.outline, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct Tile: View {
    let caption: String
    let value: String
    var tint: Color = Theme.text

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caption).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.muted)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.raised)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct RarityText: View {
    let name: String
    var size: CGFloat = 15

    var body: some View {
        Text(name)
            .font(.system(size: size, weight: .bold))
            .foregroundColor(.clear)
            .overlay(Theme.gradient(rarity: name).mask(Text(name).font(.system(size: size, weight: .bold))))
    }
}

struct StatusDot: View {
    let online: Bool
    var body: some View {
        Circle()
            .fill(online ? Theme.good : Theme.muted.opacity(0.5))
            .frame(width: 9, height: 9)
            .shadow(color: online ? Theme.good.opacity(0.7) : .clear, radius: 4)
    }
}

struct ErrorBanner: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.warn)
            Text(text).font(.system(size: 14)).foregroundColor(Theme.text)
            Spacer()
        }
        .padding(12)
        .background(Theme.warn.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EmptyHint: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 34)).foregroundColor(Theme.accent)
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundColor(Theme.text)
            Text(text).font(.system(size: 14)).foregroundColor(Theme.muted).multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
    }
}

extension View {
    func screenBackground() -> some View {
        self.background(Theme.ink.ignoresSafeArea())
    }
}
