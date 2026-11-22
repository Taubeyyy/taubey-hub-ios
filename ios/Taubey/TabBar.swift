import SwiftUI

/// The bar at the bottom, our own since 2026-11-23 (Edwin: "unten die Leiste
/// könnte cleaner sein"): one floating glass capsule, the tab you are on in a
/// magenta pill that slides over, its symbol filled. The system's bar is
/// hidden on every tab; content scrolls under this one.
struct TabBar: View {
    @Binding var selection: Int
    let items: [Item]
    @Namespace private var pill

    struct Item: Identifiable {
        let tag: Int
        let title: String
        let icon: String
        var badge = false
        var id: Int { tag }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                button(item)
            }
        }
        .padding(5)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule(style: .continuous).fill(Theme.ink.opacity(0.55)))
                .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    private func button(_ item: Item) -> some View {
        let on = selection == item.tag
        return Button {
            guard selection != item.tag else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { selection = item.tag }
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: item.icon)
                        .symbolVariant(on ? .fill : .none)
                        .font(.system(size: 17, weight: on ? .semibold : .regular))
                        .frame(height: 22)
                    if item.badge {
                        Circle().fill(Theme.accent2).frame(width: 7, height: 7).offset(x: 5, y: -1)
                    }
                }
                Text(item.title)
                    .font(.system(size: 10.5, weight: on ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(on ? .white : Theme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background {
                if on {
                    Capsule(style: .continuous)
                        .fill(Theme.accentFill)
                        .shadow(color: Theme.accent.opacity(0.45), radius: 10, y: 3)
                        .matchedGeometryEffect(id: "pill", in: pill)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle(scale: 0.94))
        .accessibilityLabel(item.title)
        .accessibilityIdentifier("tab-\(item.title)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
