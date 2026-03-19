import SwiftUI
import SwiftData

@main
struct BodyLogApp: App {
    @State private var appViewModel = AppViewModel()
    @State private var entitlementManager = EntitlementManager.shared

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(appViewModel)
                .environment(entitlementManager)
                .onOpenURL { url in
                    appViewModel.handleDeepLink(url)
                }
        }
        .modelContainer(for: [
            WeightEntry.self,
            PhotoEntry.self,
            UserSettings.self
        ])
    }

    init() {
        EntitlementManager.shared.configure()

        // Record first launch date for rating prompt
        if UserDefaults.standard.object(forKey: "firstLaunchDate") == nil {
            UserDefaults.standard.set(Date.now, forKey: "firstLaunchDate")
        }
    }
}
