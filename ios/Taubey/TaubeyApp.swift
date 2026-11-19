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
                    RootView().transition(.opacity.combined(with: .scale(scale: 1.03)))
                } else {
                    LoginView().transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: store.signedIn)
            .environmentObject(store)
            .environmentObject(notifier)
            .preferredColorScheme(.dark)
            .tint(Theme.accent2)
            .toggleStyle(CheckToggleStyle())
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
    @EnvironmentObject var notifier: Notifier
    @Environment(\.scenePhase) private var phase
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            OverviewView()
                .tabItem { Label("Übersicht", systemImage: "square.grid.2x2") }
                .tag(0)
            InstancesView()
                .tabItem { Label("Instanzen", systemImage: "desktopcomputer") }
                .tag(1)
            InventoryView()
                .tabItem { Label("Inventar", systemImage: "shippingbox") }
                .tag(2)
            EventsView()
                .tabItem { Label("Events", systemImage: "bell") }
                .tag(3)
            AccountView()
                .tabItem { Label("Konto", systemImage: "person.crop.circle") }
                .tag(4)
        }
        // a tapped notification lands on the tab it is about
        .onChange(of: notifier.openTab) { wanted in
            guard let wanted = wanted else { return }
            tab = wanted
            notifier.openTab = nil
        }
        .onChange(of: tab) { _ in Haptics.tap() }
        .overlay(alignment: .top) {
            if let toast = store.toast {
                ToastView(text: toast)
                    .id(toast)
                    .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.92, anchor: .top)))
            }
        }
        .animation(Motion.snap, value: store.toast)
        // asks once; afterwards this only reads the answer - then the token
        // for real push, which iOS hands over again on every start
        .task {
            Heads.shared.api = store.api
            await Notifier.shared.requestPermission()
            Notifier.shared.registerForPush()
        }
        // every five seconds while the app is open - an open app makes the
        // scripts report every three (the server's fast mode), so what you see
        // is never more than a few seconds old
        .task(id: phase) {
            guard phase == .active else { return }
            while !Task.isCancelled {
                await store.refresh()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }
}
