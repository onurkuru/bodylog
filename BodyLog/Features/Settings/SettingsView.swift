import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(EntitlementManager.self) private var entitlementManager
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [UserSettings]
    @Query(sort: \WeightEntry.date, order: .reverse) private var entries: [WeightEntry]

    @State private var showDeleteConfirmation = false
    @State private var showExportSheet = false
    @State private var csvURL: URL?
    @State private var showExportError = false
    @State private var exportErrorMessage = ""
    @State private var photoSizeLabel = "—"

    private var settings: UserSettings? { settingsArray.first }

    var body: some View {
        ZStack {
            BLTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BLTheme.spacingLG) {
                    // Header
                    Text("Settings")
                        .font(BLTheme.headlineSerif(28))
                        .foregroundStyle(BLTheme.textPrimary)
                        .padding(.top, BLTheme.spacingSM)

                    // Profile Section
                    sectionHeader("Profile")
                    BLCard {
                        VStack(spacing: 16) {
                            if let settings {
                                settingRow(title: "Unit") {
                                    Picker("", selection: Binding(
                                        get: { settings.unitPreference },
                                        set: { settings.unitPreference = $0 }
                                    )) {
                                        Text("kg").tag(WeightUnit.kg)
                                        Text("lbs").tag(WeightUnit.lbs)
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 120)
                                }

                                Divider().foregroundStyle(BLTheme.background)

                                settingRow(title: "Goal Weight") {
                                    Button {
                                        appViewModel.activeSheet = .goalWeight
                                    } label: {
                                        HStack(spacing: 4) {
                                            if let goal = settings.goalWeight {
                                                Text(goal.formattedWithUnit(settings.unitPreference))
                                                    .font(BLTheme.body())
                                                    .foregroundStyle(BLTheme.textSecondary)
                                            } else {
                                                Text("Not set")
                                                    .font(BLTheme.body())
                                                    .foregroundStyle(BLTheme.textTertiary)
                                            }
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(BLTheme.textTertiary)
                                        }
                                    }
                                }

                                Divider().foregroundStyle(BLTheme.background)

                                settingRow(title: "Same-day entries") {
                                    Picker("", selection: Binding(
                                        get: { settings.dailyEntryBehavior },
                                        set: { settings.dailyEntryBehavior = $0 }
                                    )) {
                                        ForEach(DailyEntryBehavior.allCases) { b in
                                            Text(b.rawValue).tag(b)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(BLTheme.textSecondary)
                                }
                            }
                        }
                    }

                    // Reminders Section
                    sectionHeader("Reminders")
                    BLCard {
                        VStack(spacing: 16) {
                            if let settings {
                                settingRow(title: "Daily Reminder") {
                                    Toggle("", isOn: Binding(
                                        get: { settings.notificationEnabled },
                                        set: { newValue in
                                            settings.notificationEnabled = newValue
                                            if newValue {
                                                enableNotifications(settings: settings)
                                            } else {
                                                NotificationManager.shared.cancelDailyReminder()
                                            }
                                        }
                                    ))
                                    .tint(BLTheme.accent)
                                }

                                if settings.notificationEnabled {
                                    Divider().foregroundStyle(BLTheme.background)
                                    settingRow(title: "Reminder Time") {
                                        Button {
                                            appViewModel.activeSheet = .notificationPicker
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text(formatTime(hour: settings.notificationHour, minute: settings.notificationMinute))
                                                    .font(BLTheme.body())
                                                    .foregroundStyle(BLTheme.textSecondary)
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundStyle(BLTheme.textTertiary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Subscription
                    sectionHeader("Subscription")
                    BLCard {
                        VStack(spacing: 16) {
                            if entitlementManager.isPro {
                                HStack {
                                    Image(systemName: "crown.fill")
                                        .foregroundStyle(.yellow)
                                    Text("Bodygraph Pro")
                                        .font(BLTheme.bodyBold())
                                        .foregroundStyle(BLTheme.textPrimary)
                                    Spacer()
                                    Text("Active")
                                        .font(BLTheme.caption())
                                        .foregroundStyle(BLTheme.success)
                                }

                                Divider().foregroundStyle(BLTheme.background)

                                Button {
                                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    settingRowLabel(title: "Manage Subscription")
                                }
                            } else {
                                Button {
                                    appViewModel.showPaywall(trigger: .csvExport)
                                } label: {
                                    HStack {
                                        Image(systemName: "crown.fill")
                                            .foregroundStyle(.yellow)
                                        Text("Upgrade to Pro")
                                            .font(BLTheme.bodyBold())
                                            .foregroundStyle(BLTheme.textPrimary)
                                        Spacer()
                                        if entitlementManager.isTrialActive {
                                            Text("\(entitlementManager.trialDaysRemaining)d left")
                                                .font(BLTheme.caption(12))
                                                .foregroundStyle(BLTheme.accent)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(BLTheme.accentLight)
                                                .clipShape(Capsule())
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(BLTheme.textTertiary)
                                    }
                                }
                            }

                            Divider().foregroundStyle(BLTheme.background)

                            Button {
                                Task { await entitlementManager.restorePurchases() }
                            } label: {
                                settingRowLabel(title: "Restore Purchases")
                            }
                        }
                    }

                    // Data
                    sectionHeader("Data")
                    BLCard {
                        VStack(spacing: 16) {
                            Button {
                                if entitlementManager.isPro { exportCSV() }
                                else { appViewModel.showPaywall(trigger: .csvExport) }
                            } label: {
                                HStack {
                                    settingRowLabel(title: "Export CSV")
                                    Spacer()
                                    if !entitlementManager.isPro {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 11))
                                            .foregroundStyle(BLTheme.textTertiary)
                                    }
                                }
                            }

                            Divider().foregroundStyle(BLTheme.background)

                            Button {
                                showDeleteConfirmation = true
                            } label: {
                                Text("Delete All Data")
                                    .font(BLTheme.body())
                                    .foregroundStyle(BLTheme.danger)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    // About
                    sectionHeader("About")
                    BLCard {
                        VStack(spacing: 16) {
                            Button { requestReview() } label: {
                                settingRowLabel(title: "Rate Bodygraph", icon: "star.fill")
                            }

                            Divider().foregroundStyle(BLTheme.background)

                            settingRow(title: "Version") {
                                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                    .font(BLTheme.body())
                                    .foregroundStyle(BLTheme.textTertiary)
                            }

                            Divider().foregroundStyle(BLTheme.background)

                            settingRow(title: "Photo Storage") {
                                Text(photoSizeLabel)
                                    .font(BLTheme.body())
                                    .foregroundStyle(BLTheme.textTertiary)
                            }
                        }
                    }
                }
                .padding(.horizontal, BLTheme.spacingMD)
                .padding(.bottom, BLTheme.spacingXL)
            }
        }
        .task {
            let size = PhotoStorageManager.shared.totalPhotoSizeFormatted
            await MainActor.run { photoSizeLabel = size }
        }
        .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
            Button("Delete Everything", role: .destructive) { deleteAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all weight entries and photos. This cannot be undone.")
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = csvURL { ShareSheet(items: [url]) }
        }
        .alert("Export Error", isPresented: $showExportError) {
            Button("OK") {}
        } message: { Text(exportErrorMessage) }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(BLTheme.titleSerif(18))
            .foregroundStyle(BLTheme.textPrimary)
    }

    private func settingRow<Content: View>(title: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(BLTheme.body())
                .foregroundStyle(BLTheme.textPrimary)
            Spacer()
            trailing()
        }
    }

    private func settingRowLabel(title: String, icon: String? = nil) -> some View {
        HStack {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(BLTheme.accent)
            }
            Text(title)
                .font(BLTheme.body())
                .foregroundStyle(BLTheme.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(BLTheme.textTertiary)
        }
    }

    // MARK: - Actions

    private func enableNotifications(settings: UserSettings) {
        Task {
            let granted = await NotificationManager.shared.requestAuthorization()
            if granted {
                NotificationManager.shared.scheduleDailyReminder(
                    hour: settings.notificationHour, minute: settings.notificationMinute
                )
            } else {
                await MainActor.run { settings.notificationEnabled = false }
            }
        }
    }

    private func exportCSV() {
        let unit = settings?.unitPreference ?? .kg
        var csv = "Date,Weight (\(unit.rawValue)),Note\n"
        let sorted = entries.sorted { $0.date < $1.date }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for entry in sorted {
            let date = formatter.string(from: entry.date)
            let weight = entry.weight.formatted(unit: unit)
            let note = entry.note?.replacingOccurrences(of: ",", with: ";") ?? ""
            csv += "\(date),\(weight),\(note)\n"
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Bodygraph_Export.csv")
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            csvURL = tempURL
            showExportSheet = true
        } catch {
            exportErrorMessage = "Export failed: \(error.localizedDescription)"
            showExportError = true
        }
    }

    private func deleteAllData() {
        for entry in entries { modelContext.delete(entry) }
        let photoDescriptor = FetchDescriptor<PhotoEntry>()
        if let photos = try? modelContext.fetch(photoDescriptor) {
            for photo in photos {
                PhotoStorageManager.shared.deletePhoto(photoName: photo.fileName, thumbName: photo.thumbnailName)
                modelContext.delete(photo)
            }
        }
    }

    private func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: scene)
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        Date.formatTime(hour: hour, minute: minute)
    }
}

// MARK: - Sub-sheets (Goal, Notification, Streak)

struct GoalWeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsArray: [UserSettings]
    @State private var goalText: String = ""
    private var settings: UserSettings? { settingsArray.first }
    private var unit: WeightUnit { settings?.unitPreference ?? .kg }

    var body: some View {
        ZStack {
            BLTheme.background.ignoresSafeArea()
            VStack(spacing: BLTheme.spacingLG) {
                HStack {
                    BLDismissButton { dismiss() }
                    Spacer()
                }
                .padding(.horizontal, BLTheme.spacingLG)
                .padding(.top, BLTheme.spacingMD)

                Spacer()

                Text("Goal Weight")
                    .font(BLTheme.headlineSerif(28))
                    .foregroundStyle(BLTheme.textPrimary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("0", text: $goalText)
                        .keyboardType(.decimalPad)
                        .font(BLTheme.numberDisplay(56))
                        .foregroundStyle(BLTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 180)
                    Text(unit.rawValue)
                        .font(BLTheme.titleSerif(20))
                        .foregroundStyle(BLTheme.textSecondary)
                }

                Spacer()

                VStack(spacing: 12) {
                    BLPrimaryButton("Save") {
                        guard let value = Double(goalText), value > 0 else { return }
                        settings?.goalWeight = unit == .lbs ? value.toKg : value
                        dismiss()
                    }
                    if settings?.goalWeight != nil {
                        Button("Remove Goal") {
                            settings?.goalWeight = nil
                            dismiss()
                        }
                        .font(BLTheme.body(15))
                        .foregroundStyle(BLTheme.danger)
                    }
                }
                .padding(.horizontal, BLTheme.spacingLG)
                .padding(.bottom, BLTheme.spacingXL)
            }
        }
        .onAppear {
            if let goal = settings?.goalWeight {
                goalText = String(format: "%.1f", unit == .lbs ? goal.toLbs : goal)
            }
        }
    }
}

struct NotificationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsArray: [UserSettings]
    @State private var selectedTime: Date = .now
    private var settings: UserSettings? { settingsArray.first }

    var body: some View {
        ZStack {
            BLTheme.background.ignoresSafeArea()
            VStack {
                HStack {
                    BLDismissButton { dismiss() }
                    Spacer()
                }
                .padding(.horizontal, BLTheme.spacingLG)
                .padding(.top, BLTheme.spacingMD)

                Spacer()

                Text("Reminder Time")
                    .font(BLTheme.headlineSerif(28))
                    .foregroundStyle(BLTheme.textPrimary)

                DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()

                Spacer()

                BLPrimaryButton("Save") {
                    let c = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
                    settings?.notificationHour = c.hour ?? 20
                    settings?.notificationMinute = c.minute ?? 0
                    NotificationManager.shared.scheduleDailyReminder(hour: c.hour ?? 20, minute: c.minute ?? 0)
                    dismiss()
                }
                .padding(.horizontal, BLTheme.spacingLG)
                .padding(.bottom, BLTheme.spacingXL)
            }
        }
        .onAppear {
            if let s = settings {
                var c = DateComponents()
                c.hour = s.notificationHour
                c.minute = s.notificationMinute
                selectedTime = Calendar.current.date(from: c) ?? .now
            }
        }
    }
}

struct StreakDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WeightEntry.date, order: .reverse) private var entries: [WeightEntry]
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        ZStack {
            BLTheme.background.ignoresSafeArea()
            VStack(spacing: BLTheme.spacingLG) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Text("Done")
                            .font(BLTheme.bodyBold())
                            .foregroundStyle(BLTheme.accent)
                    }
                }
                .padding(.horizontal, BLTheme.spacingLG)
                .padding(.top, BLTheme.spacingMD)

                Spacer()

                Image(systemName: "flame.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(BLTheme.streak)

                let streak = viewModel.calculateStreak(from: entries)
                Text("\(streak)")
                    .font(BLTheme.numberDisplay(64))
                    .foregroundStyle(BLTheme.textPrimary)

                Text(streak == 1 ? "day streak" : "days streak")
                    .font(BLTheme.titleSerif(20))
                    .foregroundStyle(BLTheme.textSecondary)

                Text("Log your weight every day to keep\nyour streak alive.")
                    .font(BLTheme.body(15))
                    .foregroundStyle(BLTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BLTheme.spacingXL)

                Spacer()
            }
        }
        .presentationDetents([.medium])
    }
}
