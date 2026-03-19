import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [UserSettings]
    @State private var currentPage = 0

    @State private var selectedUnit: WeightUnit = .kg
    @State private var goalText: String = ""

    private var settings: UserSettings? { settingsArray.first }

    var body: some View {
        ZStack {
            BLTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                BLStepIndicator(totalSteps: 3, currentStep: currentPage)
                    .padding(.top, 16)

                TabView(selection: $currentPage) {
                    UnitSelectionPage(selectedUnit: $selectedUnit, onContinue: nextPage)
                        .tag(0)

                    GoalWeightPage(
                        selectedUnit: selectedUnit,
                        goalText: $goalText,
                        onContinue: nextPage,
                        onSkip: nextPage
                    )
                    .tag(1)

                    NotificationPage(onComplete: completeOnboarding)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)
            }
        }
    }

    private func nextPage() {
        if currentPage < 2 { currentPage += 1 }
    }

    private func completeOnboarding() {
        guard let settings else { return }
        settings.unitPreference = selectedUnit
        if let v = Double(goalText), v > 0 {
            settings.goalWeight = selectedUnit == .lbs ? v.toKg : v
        }
        settings.onboardingCompleted = true
        try? modelContext.save()
    }
}

// MARK: - Page 1: Unit Selection

private struct UnitSelectionPage: View {
    @Binding var selectedUnit: WeightUnit
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "scalemass.fill")
                .font(.system(size: 64))
                .foregroundStyle(BLTheme.accent)

            Text("Welcome to BodyLog")
                .font(BLTheme.headlineSerif(28))
                .foregroundStyle(BLTheme.textPrimary)
                .padding(.top, BLTheme.spacingLG)

            Text("Choose your preferred unit")
                .font(BLTheme.body(15))
                .foregroundStyle(BLTheme.textSecondary)
                .padding(.top, BLTheme.spacingSM)
                .padding(.bottom, BLTheme.spacingXL)

            VStack(spacing: 12) {
                BLSelectionPill(isSelected: selectedUnit == .kg, action: { selectedUnit = .kg }) {
                    HStack {
                        Text("Kilograms (kg)")
                            .font(BLTheme.bodyBold())
                            .foregroundStyle(BLTheme.textPrimary)
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundStyle(selectedUnit == .kg ? BLTheme.accent : .clear)
                    }
                }

                BLSelectionPill(isSelected: selectedUnit == .lbs, action: { selectedUnit = .lbs }) {
                    HStack {
                        Text("Pounds (lbs)")
                            .font(BLTheme.bodyBold())
                            .foregroundStyle(BLTheme.textPrimary)
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundStyle(selectedUnit == .lbs ? BLTheme.accent : .clear)
                    }
                }
            }
            .padding(.horizontal, BLTheme.spacingLG)

            Spacer()
            Spacer()

            BLPrimaryButton("Continue", action: onContinue)
                .padding(.horizontal, BLTheme.spacingLG)
                .padding(.bottom, BLTheme.spacingXL)
        }
    }
}

// MARK: - Page 2: Goal Weight

private struct GoalWeightPage: View {
    let selectedUnit: WeightUnit
    @Binding var goalText: String
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "target")
                .font(.system(size: 64))
                .foregroundStyle(BLTheme.accent)

            Text("Set a Goal")
                .font(BLTheme.headlineSerif(28))
                .foregroundStyle(BLTheme.textPrimary)
                .padding(.top, BLTheme.spacingLG)

            Text("What's your target weight?")
                .font(BLTheme.body(15))
                .foregroundStyle(BLTheme.textSecondary)
                .padding(.top, BLTheme.spacingSM)
                .padding(.bottom, BLTheme.spacingXL)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("0.0", text: $goalText)
                    .keyboardType(.decimalPad)
                    .font(BLTheme.numberDisplay(48))
                    .foregroundStyle(BLTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 180)

                Text(selectedUnit.rawValue)
                    .font(BLTheme.titleSerif(20))
                    .foregroundStyle(BLTheme.textSecondary)
            }

            Spacer()
            Spacer()

            VStack(spacing: 12) {
                BLPrimaryButton("Continue", action: onContinue)

                Button("Skip for now", action: onSkip)
                    .font(BLTheme.body(15))
                    .foregroundStyle(BLTheme.textTertiary)
            }
            .padding(.horizontal, BLTheme.spacingLG)
            .padding(.bottom, BLTheme.spacingXL)
        }
    }
}

// MARK: - Page 3: Notifications

private struct NotificationPage: View {
    let onComplete: () -> Void
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Notification mockup
            BLCard {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(BLTheme.accent)
                            .frame(width: 40, height: 40)
                        Image(systemName: "scalemass.fill")
                            .foregroundStyle(.white)
                            .font(.system(size: 16))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BodyLog")
                            .font(BLTheme.bodyBold(14))
                            .foregroundStyle(BLTheme.textPrimary)
                        Text("Time to log your weight")
                            .font(BLTheme.body(14))
                            .foregroundStyle(BLTheme.textSecondary)
                    }
                    Spacer()
                    Text("now")
                        .font(BLTheme.caption(12))
                        .foregroundStyle(BLTheme.textTertiary)
                }
            }
            .padding(.horizontal, BLTheme.spacingLG)
            .padding(.bottom, BLTheme.spacingXL)

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 64))
                .foregroundStyle(BLTheme.accent)

            Text("Stay Consistent")
                .font(BLTheme.headlineSerif(28))
                .foregroundStyle(BLTheme.textPrimary)
                .padding(.top, BLTheme.spacingLG)

            Text("Get a daily reminder to log your weight")
                .font(BLTheme.body(15))
                .foregroundStyle(BLTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, BLTheme.spacingSM)

            Spacer()
            Spacer()

            VStack(spacing: 12) {
                BLPrimaryButton("Allow Notifications", isLoading: isRequesting) {
                    requestAndComplete()
                }

                Button("Maybe Later", action: onComplete)
                    .font(BLTheme.body(15))
                    .foregroundStyle(BLTheme.textTertiary)
            }
            .padding(.horizontal, BLTheme.spacingLG)
            .padding(.bottom, BLTheme.spacingXL)
        }
    }

    private func requestAndComplete() {
        isRequesting = true
        Task {
            let granted = await NotificationManager.shared.requestAuthorization()
            if granted { NotificationManager.shared.scheduleDailyReminder(hour: 20, minute: 0) }
            await MainActor.run { isRequesting = false; onComplete() }
        }
    }
}
