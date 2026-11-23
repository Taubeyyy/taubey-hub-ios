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
        // No background checks and no notifications of its own any more: since
        // 2026-11-19 every message comes through Bark, which opens this app.
    }
}

struct RootView: View {
    @EnvironmentObject var store: HubStore
    @EnvironmentObject var notifier: Notifier
    @Environment(\.scenePhase) private var phase
    @State private var tab = 0

    var body: some View {
        // The system's bar is hidden on every tab; ours floats at the bottom
        // (TabBar). Trade took the Events' place on 2026-11-23 - the events
        // open from "Alle Events" on the overview.
        //
        // Each scrolling screen keeps room for the bar itself (.barRoom()):
        // without it the last rows - "Alle Events", "Abmelden" - sat under
        // the bar and could not be tapped.
        TabView(selection: $tab) {
            OverviewView().tag(0).toolbar(.hidden, for: .tabBar)
            InstancesView().tag(1).toolbar(.hidden, for: .tabBar)
            InventoryView().tag(2).toolbar(.hidden, for: .tabBar)
            TradeView().tag(3).toolbar(.hidden, for: .tabBar)
            AccountView().tag(4).toolbar(.hidden, for: .tabBar)
        }
        .overlay(alignment: .bottom) {
            TabBar(selection: $tab, items: [
                .init(tag: 0, title: "Übersicht", icon: "square.grid.2x2"),
                .init(tag: 1, title: "Instanzen", icon: "desktopcomputer"),
                .init(tag: 2, title: "Inventar", icon: "shippingbox"),
                .init(tag: 3, title: "Trade", icon: "arrow.left.arrow.right"),
                .init(tag: 4, title: "Konto", icon: "person.crop.circle"),
            ])
            // what scrolls under the bar fades into the dark, down to the very
            // edge: the fade starts a little above the bar, and it reaches into
            // the home indicator's strip (the bar's own frame touches that edge,
            // so ignoresSafeArea can take it the rest of the way)
            .padding(.top, 22)
            .background {
                LinearGradient(stops: [
                    .init(color: Theme.ink.opacity(0), location: 0),
                    .init(color: Theme.ink.opacity(0.78), location: 0.42),
                    .init(color: Theme.ink.opacity(0.97), location: 1),
                ], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
            }
            // the keyboard comes up over the bar, it does not push it up
            .ignoresSafeArea(.keyboard, edges: .bottom)
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
        // a tapped Bark message: taubey://open?view=… lands on its tab
        .onOpenURL { url in
            if let wanted = HubLink.tab(for: url) { tab = wanted }
            // events: the overview opens them as a sheet
            let view = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "view" }?.value ?? ""
            if view == "activity" || view == "events" { store.openEvents = true }
        }
        .task {
            Heads.shared.api = store.api
            await store.checkUpdate()
        }
        // every five seconds while the app is open - an open app makes the
        // scripts report every three (the server's fast mode), so what you see
        // is never more than a few seconds old
        .task(id: phase) {
            guard phase == .active else { return }
            await store.checkUpdate()
            while !Task.isCancelled {
                await store.refresh()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }
}
