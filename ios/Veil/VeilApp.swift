import SwiftUI

@main
struct VeilApp: App {
    @StateObject private var appFlow = AppFlowStore()
    @StateObject private var socialStore = DemoSocialStore()
    @StateObject private var appearance = AppearanceStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appFlow)
                .environmentObject(socialStore)
                .environmentObject(appearance)
                .tint(appearance.accentColor)
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appFlow: AppFlowStore

    var body: some View {
        Group {
            if !appFlow.hasConfirmedAdultStatement {
                AdultConfirmationView()
            } else if !appFlow.hasLocalDemoAccount {
                AccountSetupView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.24), value: appFlow.routeID)
    }
}

struct VeilApp_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(DemoSocialStore())
            .environmentObject(AppFlowStore(previewingMainApp: true))
            .environmentObject(AppearanceStore())
            .preferredColorScheme(.dark)
    }
}
