import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: opacity)
    }
}

/// Nyra - the look of Taubey UI 2, the script menu, and of the web dashboard
/// (taubey-hub/dashboard.html :root): magenta on near-black, glass with a
/// little grain over a flowing tube and soft leaves.
enum Theme {
    static let ink = Color(hex: 0x050507)          // --bg
    static let surface = Color(hex: 0x121016)      // --panel
    static let raised = Color(hex: 0x1A171F)       // --panel-2
    static let line = Color.white.opacity(0.065)   // --line
    static let line2 = Color.white.opacity(0.12)   // --line-2
    static let outline = line
    static let text = Color(hex: 0xF3F2F7)         // --text
    static let muted = Color(hex: 0xA09FAD)        // --dim
    static let faint = Color(hex: 0x6E6D7A)        // --dim-2
    static let accent = Color(hex: 0xC21FB3)       // --accent
    static let accent2 = Color(hex: 0xEE6AE2)      // --accent2, the light one
    static let accent3 = Color(hex: 0x7A0B73)      // --accent3, the deep one
    static let accentSoft = Color(hex: 0xC21FB3, opacity: 0.16)
    static let good = Color(hex: 0x4ADE80)
    static let warn = Color(hex: 0xFBBF24)
    static let bad = Color(hex: 0xF87171)
    static let radius: CGFloat = 14

    /// the lit magenta of buttons, pills and ticked boxes
    static let accentFill = LinearGradient(colors: [Color(hex: 0xD93BCB), Color(hex: 0xA8169A)], startPoint: .top, endPoint: .bottom)

    // The game's own rarity gradients, stop for stop, from the look dump
    // (taubey-hub/look/fish-anime.json, tools/look-from-dump.py): black
    // stops left out and the darkest lifted so every tier reads on near-black.
    // rarityColor is one colour per tier for dots, bars and glows.
    static let rarityColor: [String: UInt32] = [
        "Common": 0xB0B0B0, "Uncommon": 0x69FF99, "Rare": 0x59EEFF, "Epic": 0xE45EFF, "Legendary": 0xFFFF59,
        "Mythical": 0xFF5356, "Cosmic": 0x9659FF, "Secret": 0x9B9BB3, "Rainbow": 0xFFB15A, "Ascended": 0x59F1FF,
        "Divine": 0xFFD059, "Supreme": 0x59FF5E, "Celestial": 0x2185FF, "Ancient": 0xFFEC59, "God": 0xFF595C,
        "Omniscient": 0xFF595C, "Apex": 0x59F7FF, "Transcendent": 0x9C59FF, "Exclusive": 0x8860FF,
    ]
    static let rarityGradient: [String: [UInt32]] = [
        "Common": [0xB0B0B0, 0x9C9C9C],
        "Uncommon": [0x69FF99, 0x69FF99],
        "Rare": [0x00E5FF, 0x00E5FF],
        "Epic": [0xD711FF, 0xD711FF],
        "Legendary": [0xFFFF00, 0xFFFF00],
        "Mythical": [0xFF2125, 0xFF3A3D],
        "Cosmic": [0x9355FF, 0xDF05FC, 0xBA32FF],
        "Secret": [0x8C8CA8, 0x8585A0, 0x8C8CA8, 0x858C9C],
        "Rainbow": [0xFF6A00, 0xFF8801, 0xFFAA00, 0xFEFF00, 0xA9FF00, 0x54FF00, 0x00FF01, 0x00FF57, 0x00FFAC, 0x00FDFF,
                    0x00A8FF, 0x499BFF, 0x8595FF, 0xA57BFF, 0xAB57FF, 0xFF4AE7, 0xFF00A6, 0xFF3773, 0xFF6F6F],
        "Ascended": [0x00EAFF, 0x9C55FF, 0xD400FF, 0x00A8FF, 0x499BFF, 0x8595FF, 0xA57BFF, 0xAB57FF, 0xFF4AE7, 0xFF00A6,
                     0xB347FF, 0xA14EFF],
        "Divine": [0xFFB700, 0xFFD93F, 0xBA32FF],
        "Supreme": [0x23FF14, 0x3CFF42, 0x34FF26, 0x00FF08],
        "Celestial": [0xFF0004, 0x2185FF, 0xFA44E3, 0xFF0004],
        "Ancient": [0xFFE100, 0xFF8800, 0xFFE14C, 0xF2FF00, 0xFFB200, 0xFFFF00, 0xFFB200, 0xFFE100],
        "God": [0xFF0004, 0xFF399F, 0xC226FF, 0xFF00B3],
        "Omniscient": [0xFF0004, 0xFF2528, 0xFF3D4B, 0xFF272B, 0xFF272E, 0xFF3336, 0xFF2124, 0xFF3A3D, 0xFF222A, 0xFF3B3F, 0xFF2024],
        "Apex": [0x00F2FF, 0x00DDFF, 0x8A5CFF, 0x696BFF, 0x00EAFF, 0x37FBFF, 0x2F78FF, 0x00F2FF, 0x00FFFF, 0x696BFF,
                 0x1D78FF, 0x636DFF, 0x00D0FF],
        "Transcendent": [0x9955FF, 0x8863FF, 0xC226FF, 0xA14EFF, 0xC330FE, 0xC336FF, 0x8E61FF, 0x8560FF, 0xB93FFF,
                         0xA74EFF, 0x9E4EFF, 0xB247FF, 0x7369FF, 0xA74EFF, 0xA947FF],
        "Exclusive": [0xFF6AE6, 0xC93FFF, 0x6A63FF, 0xFF00D4],
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

// MARK: - the background: soft leaves and the flowing tube, nothing else

struct Ambience: View {
    @Environment(\.accessibilityReduceMotion) private var still
    @State private var drift = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Theme.ink
                RadialGradient(colors: [Theme.accent.opacity(0.12), .clear], center: UnitPoint(x: 0.8, y: -0.05),
                               startRadius: 0, endRadius: max(w, h) * 0.8)
                Leaf()
                    .frame(width: w * 1.25, height: w * 0.62)
                    .rotationEffect(.degrees(drift ? -8 : -22))
                    .offset(x: w * (drift ? 0.3 : 0.38), y: -h * (drift ? 0.34 : 0.4))
                    .opacity(0.5)
                    .animation(still ? nil : .easeInOut(duration: 19).repeatForever(autoreverses: true), value: drift)
                Leaf()
                    .frame(width: w * 1.05, height: w * 0.52)
                    .rotationEffect(.degrees(drift ? 40 : 28))
                    .offset(x: -w * (drift ? 0.3 : 0.4), y: h * (drift ? 0.36 : 0.42))
                    .opacity(0.4)
                    .animation(still ? nil : .easeInOut(duration: 23).repeatForever(autoreverses: true), value: drift)
                Tube(still: still)
                    .frame(width: w, height: h)
                    .opacity(0.32)
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { drift = true }
    }
}

/// One of Nyra's leaves: pointed at both ends, magenta, out of focus.
struct Leaf: View {
    var body: some View {
        LeafShape()
            .fill(LinearGradient(colors: [Theme.accent2, Theme.accent, Theme.accent3], startPoint: .top, endPoint: .bottom))
            .blur(radius: 34)
    }
}

struct LeafShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let mid = CGPoint(x: r.minX, y: r.midY), end = CGPoint(x: r.maxX, y: r.midY)
        p.move(to: mid)
        p.addCurve(to: end, control1: CGPoint(x: r.minX + r.width * 0.19, y: r.minY + r.height * 0.06),
                   control2: CGPoint(x: r.maxX - r.width * 0.19, y: r.minY + r.height * 0.06))
        p.addCurve(to: mid, control1: CGPoint(x: r.maxX - r.width * 0.19, y: r.maxY - r.height * 0.06),
                   control2: CGPoint(x: r.minX + r.width * 0.19, y: r.maxY - r.height * 0.06))
        p.closeSubpath()
        return p
    }
}

/// The website's glossy tube. Drawn once, two screens wide with a bend that
/// repeats every screen, and slid sideways forever - so the phone only moves
/// a finished picture and never redraws it.
struct Tube: View {
    var still = false
    @State private var flow = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Canvas { ctx, size in
                let t = min(h, 900) * 0.05
                func line(_ dy: CGFloat) -> Path {
                    var p = Path()
                    let steps = 180
                    for i in 0...steps {
                        let x = CGFloat(i) / CGFloat(steps) * size.width
                        let y = h * 0.64 + h * 0.13 * sin(2 * .pi * x / w + 2.4) + dy
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    return p
                }
                func stroke(_ dy: CGFloat, _ width: CGFloat, _ color: Color, blur: CGFloat) {
                    ctx.drawLayer { layer in
                        if blur > 0 { layer.addFilter(.blur(radius: blur)) }
                        layer.stroke(line(dy), with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
                    }
                }
                // halo, then the tube from its dark underside to the shine on top
                stroke(0, t * 4.4, Color(hex: 0xEB38D6, opacity: 0.22), blur: t * 1.3)
                stroke(0, t * 2, Color(hex: 0x4E0748), blur: 0)
                stroke(-t * 0.12, t * 1.72, Color(hex: 0x8E0E84), blur: t * 0.12)
                stroke(-t * 0.3, t * 1.2, Color(hex: 0xC824B8), blur: t * 0.22)
                stroke(-t * 0.5, t * 0.62, Color(hex: 0xF07FE4), blur: t * 0.2)
                stroke(-t * 0.64, t * 0.2, Color(hex: 0xFFE0FA, opacity: 0.7), blur: t * 0.1)
            }
            .frame(width: w * 2, height: h)
            .drawingGroup()
            .offset(x: flow ? -w : 0)
            .animation(still ? nil : .linear(duration: 34).repeatForever(autoreverses: false), value: flow)
            .onAppear { flow = true }
        }
    }
}

// MARK: - grain: only on the glass that lies over the background

enum GrainTile {
    /// 128 x 128 light and dark specks, made once.
    static let image: UIImage = {
        let n = 128
        var bytes = [UInt8](repeating: 0, count: n * n * 4)
        var seed: UInt32 = 1337
        for i in 0..<(n * n) {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let v = Double(seed >> 8) / Double(1 << 24)
            let light = v >= 0.5
            let a = light ? (v - 0.5) * 0.36 : (0.5 - v) * 0.5
            let c = UInt8(light ? 255 * a : 0)   // premultiplied
            bytes[i * 4] = c; bytes[i * 4 + 1] = c; bytes[i * 4 + 2] = c
            bytes[i * 4 + 3] = UInt8(255 * a)
        }
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let cg = CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4, space: space,
                               bitmapInfo: info, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return UIImage() }
        return UIImage(cgImage: cg, scale: 2, orientation: .up)
    }()
}

struct Grain: View {
    var body: some View {
        Image(uiImage: GrainTile.image)
            .resizable(resizingMode: .tile)
            .opacity(0.28)
            .allowsHitTesting(false)
    }
}

extension View {
    func screenBackground() -> some View {
        self.background(Ambience())
    }

    /// The card surface: frosted glass over the background - blurred, a dark
    /// tint, a breath of white from the top, a lit hairline edge, the grain.
    /// `glass: false` for grids of many, where a blur each costs more than it
    /// shows.
    func cardSurface(radius: CGFloat = Theme.radius, glass: Bool = true) -> some View {
        self
            .background {
                ZStack {
                    if glass { Rectangle().fill(.ultraThinMaterial) }
                    Theme.surface.opacity(glass ? 0.55 : 0.84)
                    LinearGradient(colors: [Color.white.opacity(0.05), Color.white.opacity(0.012)], startPoint: .top, endPoint: .bottom)
                    if glass { Grain() }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.045)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }

    /// List rows on the same glass.
    func rowSurface() -> some View {
        self
            .listRowBackground(
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Theme.surface.opacity(0.6)
                    Grain()
                }
            )
            .listRowSeparatorTint(Theme.line2)
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
                        Image(systemName: icon).foregroundColor(Theme.accent2.opacity(0.85)).font(.system(size: 14, weight: .semibold))
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

/// One of the dashboard's tiles: a small caption with its icon, the number
/// big, a line under it (its number part tinted when `subTint` is set).
struct Tile: View {
    let caption: String
    let value: String
    var icon: String? = nil
    var sub: String? = nil
    var tint: Color = Theme.text
    var subTint: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                if let icon = icon { Image(systemName: icon).font(.system(size: 11, weight: .bold)) }
                Text(caption.uppercased()).font(.system(size: 10.5, weight: .bold)).kerning(1)
                    .lineLimit(1).minimumScaleFactor(0.8)
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
                subLine(sub).font(.system(size: 11.5)).lineLimit(1).minimumScaleFactor(0.8).padding(.top, 5)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .cardSurface()
    }

    /// "518B pro Stunde": the number in the tint, the words faint
    private func subLine(_ s: String) -> Text {
        guard let tint = subTint, let space = s.firstIndex(of: " ") else { return Text(s).foregroundColor(Theme.faint) }
        return Text(s[..<space]).foregroundColor(tint).fontWeight(.bold) + Text(s[space...]).foregroundColor(Theme.faint)
    }
}

/// The dashboard's first tile: how many instances report, with the ring.
struct OnlineTile: View {
    let online: Int
    let total: Int

    var body: some View {
        let share = total > 0 ? Double(online) / Double(total) : 0
        Tile(caption: "Online", value: "\(online) / \(total)", icon: "dot.radiowaves.left.and.right",
             sub: total > 0 ? "\(Int((share * 100).rounded()))% melden sich" : "noch nichts verbunden", subTint: Theme.good)
            .overlay(alignment: .topTrailing) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.07), lineWidth: 4.5)
                    Circle().trim(from: 0, to: share)
                        .stroke(Theme.good, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1), value: share)
                }
                .frame(width: 34, height: 34)
                .padding(14)
            }
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

/// Segmented pills: the chosen one lit magenta, sliding from choice to choice.
struct SegPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]
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
                        .foregroundColor(on ? .white : Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if on {
                                Capsule().fill(Theme.accentFill)
                                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                                    .shadow(color: Theme.accent.opacity(0.55), radius: 8, y: 3)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.035))
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

/// The accent button: lit magenta glass with a glow.
struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(Theme.accentFill)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent2.opacity(0.45), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Theme.accent.opacity(configuration.isPressed ? 0.25 : 0.55), radius: 16, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.snap, value: configuration.isPressed)
    }
}

/// Switches are check boxes, as in the script menu: the whole row is the
/// button, the box on the right ticks with a little spring.
struct CheckToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            Haptics.tap()
            withAnimation(Motion.snap) { configuration.isOn.toggle() }
        } label: {
            HStack(spacing: 12) {
                configuration.label
                Spacer(minLength: 8)
                CheckBox(on: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The fine slider of the script menu (B): a thin lit track and a small white
/// knob with a glowing ring. Moves freely while dragging; `done` runs when the
/// finger lets go (or after a VoiceOver step).
struct FineSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var done: () -> Void = {}
    @State private var dragging = false

    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        return span > 0 ? min(1, max(0, (value - range.lowerBound) / span)) : 0
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, knob: CGFloat = 16
            let x = knob / 2 + CGFloat(fraction) * (w - knob)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1)).frame(height: 3)
                Capsule()
                    .fill(LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(3, x), height: 3)
                    .shadow(color: Theme.accent.opacity(0.6), radius: 4)
                Circle()
                    .fill(Color.white)
                    .frame(width: knob, height: knob)
                    .background(Circle().fill(Theme.accent2.opacity(0.28)).frame(width: knob + 8, height: knob + 8))
                    .shadow(color: Theme.accent2.opacity(0.75), radius: 7)
                    .scaleEffect(dragging ? 1.2 : 1)
                    .animation(Motion.snap, value: dragging)
                    .offset(x: x - knob / 2)
            }
            .frame(height: 28)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if !dragging { dragging = true; Haptics.tap() }
                        let f = min(1, max(0, Double((g.location.x - knob / 2) / max(1, w - knob))))
                        value = range.lowerBound + f * (range.upperBound - range.lowerBound)
                    }
                    .onEnded { _ in
                        dragging = false
                        done()
                    }
            )
        }
        .frame(height: 28)
        .accessibilityElement()
        .accessibilityValue(Text(String(format: "%.0f %%", fraction * 100)))
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) / 20
            value = min(range.upperBound, max(range.lowerBound, value + (direction == .increment ? step : -step)))
            done()
        }
    }
}

struct CheckBox: View {
    let on: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(on ? AnyShapeStyle(LinearGradient(colors: [Theme.accent2, Theme.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                         : AnyShapeStyle(Color.white.opacity(0.04)))
            RoundedRectangle(cornerRadius: 7)
                .stroke(on ? Theme.accent2.opacity(0.55) : Color.white.opacity(0.22), lineWidth: 1.5)
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(.white)
                .scaleEffect(on ? 1 : 0.3)
                .opacity(on ? 1 : 0)
        }
        .frame(width: 24, height: 24)
        .shadow(color: on ? Theme.accent.opacity(0.7) : .clear, radius: 8, y: 3)
        .accessibilityHidden(true)
    }
}
