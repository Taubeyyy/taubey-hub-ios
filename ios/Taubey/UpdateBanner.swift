import SwiftUI

/// "A new build is out" on the overview: one tap and TrollStore installs it.
struct UpdateBanner: View {
    let release: AppRelease
    @EnvironmentObject var store: HubStore

    var body: some View {
        Button { store.installUpdate() } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Theme.accentFill)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Neue Version: \(release.title)")
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text)
                    Text("Antippen – TrollStore installiert sie über diese hier")
                        .font(.system(size: 12.5)).foregroundColor(Theme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.faint)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier("updateBanner")
    }
}
