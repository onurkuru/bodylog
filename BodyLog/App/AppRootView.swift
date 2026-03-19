import SwiftUI
import SwiftData

struct AppRootView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [UserSettings]

    private var settings: UserSettings {
        if let existing = settingsArray.first { return existing }
        let newSettings = UserSettings()
        modelContext.insert(newSettings)
        return newSettings
    }

    var body: some View {
        ZStack {
            BLTheme.background.ignoresSafeArea()

            if !settings.onboardingCompleted {
                OnboardingContainerView()
                    .transition(.move(edge: .leading))
            } else {
                MainTabView()
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: settings.onboardingCompleted)
    }
}

struct MainTabView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        @Bindable var vm = appViewModel

        TabView(selection: $vm.selectedTab) {
            DashboardView()
                .tabItem {
                    Label(AppTab.dashboard.rawValue, systemImage: AppTab.dashboard.systemImage)
                }
                .tag(AppTab.dashboard)

            PhotosView()
                .tabItem {
                    Label(AppTab.photos.rawValue, systemImage: AppTab.photos.systemImage)
                }
                .tag(AppTab.photos)

            SettingsView()
                .tabItem {
                    Label(AppTab.settings.rawValue, systemImage: AppTab.settings.systemImage)
                }
                .tag(AppTab.settings)
        }
        .tint(BLTheme.accent)
        .sheet(item: $vm.activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .fullScreenCover(item: $vm.activeFullScreenCover) { cover in
            fullScreenContent(for: cover)
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: AppSheet) -> some View {
        switch sheet {
        case .addWeight: AddWeightSheet()
        case .editWeight(let entry): EditWeightSheet(entry: entry)
        case .photoCapture: PhotoCaptureSheet()
        case .goalWeight: GoalWeightSheet()
        case .notificationPicker: NotificationPickerSheet()
        case .paywall(let trigger): PaywallSheet(trigger: trigger)
        case .streakDetail: StreakDetailSheet()
        }
    }

    @ViewBuilder
    private func fullScreenContent(for cover: AppViewModel.FullScreenCover) -> some View {
        switch cover {
        case .photoDetail(let entry): PhotoDetailView(entry: entry)
        case .photoCompare(let before, let after): PhotoCompareView(beforeEntry: before, afterEntry: after)
        }
    }
}
