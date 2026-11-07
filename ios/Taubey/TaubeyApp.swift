import SwiftUI

@main
struct TaubeyApp: App {
    @StateObject private var store = HubStore()

    init() {
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(Theme.surface)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(Theme.ink)
        nav.shadowColor = .clear
        nav.titleTextAttributes = [.foregroundColor: UIColor(Theme.text)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(Theme.text)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if store.signedIn {
                    RootView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(store)
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: HubStore
    @Environment(\.scenePhase) private var phase

    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("Übersicht", systemImage: "square.grid.2x2") }
            InstancesView()
                .tabItem { Label("Instanzen", systemImage: "desktopcomputer") }
            InventoryView()
                .tabItem { Label("Inventar", systemImage: "shippingbox") }
            EventsView()
                .tabItem { Label("Events", systemImage: "bell") }
            AccountView()
                .tabItem { Label("Konto", systemImage: "person.crop.circle") }
        }
        .overlay(alignment: .top) {
            if let toast = store.toast {
                Text(toast)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.raised)
                    .overlay(Capsule().stroke(Theme.accent.opacity(0.5), lineWidth: 1))
                    .clipShape(Capsule())
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.toast)
        // every ten seconds while the app is open - the scripts report every
        // fifteen, so this never shows anything more than one beat old
        .task(id: phase) {
            guard phase == .active else { return }
            while !Task.isCancelled {
                await store.refresh()
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }
}
