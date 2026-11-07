import SwiftUI

@main
struct TaubeyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = HubStore()
    @StateObject private var notifier = Notifier.shared
    @Environment(\.scenePhase) private var phase

    init() {
        // glass bars over the ambience, like the website's sidebar
        let tab = UITabBarAppearance()
        tab.configureWithTransparentBackground()
        tab.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        tab.backgroundColor = UIColor(Theme.ink).withAlphaComponent(0.55)
        tab.shadowColor = UIColor(white: 1, alpha: 0.06)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        nav.backgroundColor = UIColor(Theme.ink).withAlphaComponent(0.4)
        nav.shadowColor = UIColor(white: 1, alpha: 0.06)
        let rounded = UIFont.systemFont(ofSize: 32, weight: .heavy).fontDescriptor.withDesign(.rounded)
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(Theme.text),
                                        .font: rounded.map { UIFont(descriptor: $0, size: 32) } ?? UIFont.systemFont(ofSize: 32, weight: .heavy)]
        nav.titleTextAttributes = [.foregroundColor: UIColor(Theme.text), .font: UIFont.systemFont(ofSize: 16, weight: .semibold)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()
        edge.largeTitleTextAttributes = nav.largeTitleTextAttributes
        edge.titleTextAttributes = nav.titleTextAttributes
        UINavigationBar.appearance().scrollEdgeAppearance = edge
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
            .environmentObject(notifier)
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
        }
        .onChange(of: phase) { now in
            if now == .background && store.signedIn { notifier.scheduleRefresh() }
        }
        .backgroundTask(.appRefresh(Notifier.refreshTask)) {
            await Notifier.shared.backgroundCheck()
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
        // asks once; afterwards this only reads the answer
        .task { await Notifier.shared.requestPermission() }
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
