import SwiftUI

@main
struct VeilApp: App {
    @StateObject private var appFlow = AppFlowStore()
    @StateObject private var socialStore = DemoSocialStore()
    @StateObject private var messagingStore = MessagingStore()
    @StateObject private var appearance = AppearanceStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appFlow)
                .environmentObject(socialStore)
                .environmentObject(messagingStore)
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
            } else if let recoveryCode = appFlow.pendingRecoveryCode {
                RecoveryCodeView(recoveryCode: recoveryCode)
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
            .environmentObject(MessagingStore())
            .environmentObject(AppearanceStore())
            .preferredColorScheme(.dark)
    }
}
