import SwiftUI

// How the app moves: one set of springs and small effects, used everywhere,
// so every screen feels like the same thing. All of it stands still when
// "Reduce Motion" is on.

enum Motion {
    /// Things settling into place.
    static let settle = Animation.spring(response: 0.5, dampingFraction: 0.86)
    /// A control answering a finger.
    static let snap = Animation.spring(response: 0.3, dampingFraction: 0.78)
    /// A value growing or a bar filling.
    static let grow = Animation.spring(response: 0.8, dampingFraction: 0.88)
}

/// Fades a view in and lifts it into place the first time it shows; `index`
/// staggers siblings so a screen builds from the top down.
private struct Appear: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var still

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || still ? 0 : 16)
            .scaleEffect(shown || still ? 1 : 0.98, anchor: .top)
            .onAppear {
                guard !shown else { return }
                withAnimation(Motion.settle.delay(still ? 0 : Double(min(index, 8)) * 0.055)) { shown = true }
            }
    }
}

extension View {
    func appear(_ index: Int = 0) -> some View { modifier(Appear(index: index)) }
}

/// A button that gives under the finger: a touch smaller and dimmer while
/// pressed, springing back when let go.
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(Motion.snap, value: configuration.isPressed)
    }
}

/// A band of light wandering across - for the placeholders shown while
/// something loads.
private struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var still

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, Color.white.opacity(0.07), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.55)
                        .offset(x: phase * geo.size.width * 1.4)
                }
                .allowsHitTesting(false)
            )
            .onAppear {
                guard !still else { return }
                withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }
}

/// A card-shaped placeholder with the shimmer, the height of what will be there.
struct Skeleton: View {
    var height: CGFloat
    var radius: CGFloat = Theme.radius

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Theme.surface.opacity(0.72))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .modifier(Shimmer())
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

/// A row-shaped placeholder: a square, two lines, a short line on the right.
struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11).fill(Color.white.opacity(0.06)).frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 7) {
                Capsule().fill(Color.white.opacity(0.08)).frame(width: 130, height: 11)
                Capsule().fill(Color.white.opacity(0.05)).frame(width: 84, height: 9)
            }
            Spacer()
            Capsule().fill(Color.white.opacity(0.06)).frame(width: 46, height: 11)
        }
        .padding(.vertical, 3)
        .modifier(Shimmer())
    }
}

/// A bar that fills to its share when it shows, and moves when the share does.
struct FillBar: View {
    let fraction: CGFloat
    let fill: LinearGradient
    var glow: Color = .clear
    var height: CGFloat = 6
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var still

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.05))
                Capsule()
                    .fill(fill)
                    .frame(width: max(height, geo.size.width * (shown || still ? min(1, max(0, fraction)) : 0)))
                    .shadow(color: glow.opacity(0.5), radius: 5)
            }
        }
        .frame(height: height)
        .animation(Motion.grow, value: fraction)
        .onAppear {
            guard !shown else { return }
            withAnimation(Motion.grow.delay(0.12)) { shown = true }
        }
    }
}

/// Shakes a view sideways once each time `trigger` moves - "that was wrong".
struct Shake: GeometryEffect {
    var travel: CGFloat = 9
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * 4), y: 0))
    }
}

/// What the app says back after a command: a pill dropping in from the top,
/// green with a tick for "done", red with a cross for "did not work".
struct ToastView: View {
    let text: String

    private var kind: (icon: String, tint: Color, body: String) {
        if text.hasPrefix("✓ ") { return ("checkmark.circle.fill", Theme.good, String(text.dropFirst(2))) }
        if text.hasPrefix("✗ ") { return ("xmark.circle.fill", Theme.bad, String(text.dropFirst(2))) }
        if text.hasSuffix("…") { return ("paperplane.fill", Theme.accent, text) }
        return ("info.circle.fill", Theme.accent, text)
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: kind.icon).font(.system(size: 15, weight: .semibold)).foregroundColor(kind.tint)
            Text(kind.body)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial)
        .background(Theme.raised.opacity(0.75))
        .overlay(Capsule().stroke(kind.tint.opacity(0.45), lineWidth: 1))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
        .padding(.horizontal, 24)
        .padding(.top, 6)
    }
}
