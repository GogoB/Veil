import SwiftUI

private enum MainTab: Hashable {
    case discover
    case search
    case compose
    case messages
    case veiled
}

struct MainTabView: View {
    @EnvironmentObject private var appearance: AppearanceStore
    @EnvironmentObject private var appFlow: AppFlowStore
    @EnvironmentObject private var store: DemoSocialStore
    @State private var selection: MainTab = .discover
    @State private var priorSelection: MainTab = .discover
    @State private var presentsComposer = false

    var body: some View {
        TabView(selection: $selection) {
            FeedView()
                .tabItem { Label("Discover", systemImage: "safari") }
                .tag(MainTab.discover)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(MainTab.search)

            Color.clear
                .tabItem { Label("Post", systemImage: "plus.square.fill") }
                .tag(MainTab.compose)

            MessagesView()
                .tabItem { Label("Inbox", systemImage: "bubble.left.and.bubble.right") }
                .tag(MainTab.messages)

            VeiledActivityView()
                .tabItem { Label("Veiled", systemImage: "hexagon") }
                .tag(MainTab.veiled)
        }
        .tint(appearance.accentColor)
        .onAppear { store.setCurrentProfileHandle(appFlow.username) }
        .onChange(of: selection) { newSelection in
            if newSelection == .compose {
                selection = priorSelection
                presentsComposer = true
            } else {
                priorSelection = newSelection
            }
        }
        .sheet(isPresented: $presentsComposer) {
            ComposerView()
                .presentationDragIndicator(.visible)
        }
    }
}
