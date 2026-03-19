import SwiftUI
import SwiftData

struct AppRootView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(EntitlementManager.self) private var entitlementManager
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [UserSettings]
    @State private var settingsReady = false
    @State private var showOnboardingPaywall = false
    @State private var showSplash = true

    private var settings: UserSettings? { settingsArray.first }

    var body: some View {
        ZStack {
            BLTheme.background.ignoresSafeArea()

            if showSplash {
                SplashView {
                    showSplash = false
                }
                .transition(.opacity)
                .zIndex(1)
            } else if let settings, settingsReady {
                if !settings.onboardingCompleted {
                    OnboardingContainerView()
                        .transition(.move(edge: .leading))
                } else {
                    MainTabView()
                        .transition(.move(edge: .trailing))
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: settings?.onboardingCompleted)
        .task {
            if settingsArray.isEmpty {
                modelContext.insert(UserSettings())
                try? modelContext.save()
            }
            settingsReady = true
        }
        // Show paywall after onboarding completes (first time)
        .onChange(of: settings?.onboardingCompleted) { _, newValue in
            if newValue == true && !entitlementManager.isPro {
                showOnboardingPaywall = true
            }
        }
        .fullScreenCover(isPresented: $showOnboardingPaywall) {
            PaywallSheet(trigger: .onboarding)
        }
        // Block access when trial expired and not Pro
        .fullScreenCover(isPresented: .constant(
            settingsReady &&
            settings?.onboardingCompleted == true &&
            !entitlementManager.hasAccess
        )) {
            PaywallSheet(trigger: .trialEnded)
                .interactiveDismissDisabled()
        }
    }
}

// MARK: - Splash Screen

struct SplashView: View {
    @State private var iconScale: CGFloat = 0.6
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var isFinished = false

    let onFinish: () -> Void

    var body: some View {
        ZStack {
            BLTheme.background.ignoresSafeArea()

            VStack(spacing: 20) {
                Image("SplashIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: BLTheme.accent.opacity(0.3), radius: 20, x: 0, y: 8)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)

                VStack(spacing: 4) {
                    Text("Bodygraph")
                        .font(BLTheme.headlineSerif(28))
                        .foregroundStyle(BLTheme.textPrimary)

                    Text("Track With Your Photo")
                        .font(BLTheme.body(14))
                        .foregroundStyle(BLTheme.textTertiary)
                }
                .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                textOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isFinished = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onFinish()
                }
            }
        }
        .opacity(isFinished ? 0 : 1)
    }
}

// MARK: - Main Tab View

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
