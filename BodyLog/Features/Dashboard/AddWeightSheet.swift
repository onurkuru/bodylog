import SwiftUI
import SwiftData

struct AddWeightSheet: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsArray: [UserSettings]
    @Query(sort: \WeightEntry.date, order: .reverse) private var entries: [WeightEntry]

    @State private var weightWhole: Int = 70
    @State private var weightDecimal: Int = 0
    @State private var note: String = ""
    @State private var selectedDate: Date = .now

    private var unit: WeightUnit { settingsArray.first?.unitPreference ?? .kg }

    var body: some View {
        ZStack {
            BLTheme.background.ignoresSafeArea()

            VStack(spacing: BLTheme.spacingLG) {
                // Header
                HStack {
                    BLDismissButton { dismiss() }
                    Spacer()
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .labelsHidden()
                    Spacer()
                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.horizontal, BLTheme.spacingLG)
                .padding(.top, BLTheme.spacingMD)

                Spacer()

                // Title
                Text("Log your weight")
                    .font(BLTheme.headlineSerif(28))
                    .foregroundStyle(BLTheme.textPrimary)

                // Weight Display
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(weightWhole).\(weightDecimal)")
                        .font(BLTheme.numberDisplay(56))
                        .foregroundStyle(BLTheme.textPrimary)
                    Text(unit.rawValue)
                        .font(BLTheme.titleSerif(20))
                        .foregroundStyle(BLTheme.textSecondary)
                }

                // Pickers
                HStack(spacing: 0) {
                    Picker("Whole", selection: $weightWhole) {
                        ForEach(20...300, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 100)

                    Text(".")
                        .font(BLTheme.numberDisplay(32))
                        .foregroundStyle(BLTheme.textTertiary)

                    Picker("Decimal", selection: $weightDecimal) {
                        ForEach(0...9, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                }
                .frame(height: 150)

                // Note
                TextField("Add a note (optional)", text: $note)
                    .font(BLTheme.body())
                    .padding(14)
                    .background(BLTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: BLTheme.radiusMD))
                    .padding(.horizontal, BLTheme.spacingLG)

                Spacer()

                // Save
                BLPrimaryButton("Save", action: save)
                    .padding(.horizontal, BLTheme.spacingLG)
                    .padding(.bottom, BLTheme.spacingLG)
            }
        }
        .onAppear { prefillLastWeight() }
        .presentationDetents([.large])
    }

    private func prefillLastWeight() {
        if let last = entries.first {
            let (w, d) = last.weight.toPickerComponents(unit: unit)
            weightWhole = w
            weightDecimal = d
        } else if unit == .lbs {
            weightWhole = 154
        }
    }

    private func save() {
        let weightInKg = Double.fromPicker(whole: weightWhole, decimal: weightDecimal, unit: unit)
        let noteValue = note.isEmpty ? nil : note
        let behavior = settingsArray.first?.dailyEntryBehavior ?? .addNew

        if behavior == .updateExisting,
           let existing = entries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
            existing.weight = weightInKg
            existing.note = noteValue
        } else {
            let entry = WeightEntry(date: selectedDate, weight: weightInKg, note: noteValue)
            modelContext.insert(entry)
        }

        // Suppress today's notification since user logged
        if selectedDate.isToday {
            NotificationManager.shared.suppressTodayIfLogged()
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - Edit Weight Sheet

struct EditWeightSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsArray: [UserSettings]

    let entry: WeightEntry

    @State private var weightWhole: Int = 70
    @State private var weightDecimal: Int = 0
    @State private var note: String = ""
    @State private var showDeleteConfirmation = false

    private var unit: WeightUnit { settingsArray.first?.unitPreference ?? .kg }

    var body: some View {
        ZStack {
            BLTheme.background.ignoresSafeArea()

            VStack(spacing: BLTheme.spacingLG) {
                // Header
                HStack {
                    BLDismissButton { dismiss() }
                    Spacer()
                    Text(entry.date.mediumFormatted)
                        .font(BLTheme.bodyBold())
                        .foregroundStyle(BLTheme.textSecondary)
                    Spacer()
                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.horizontal, BLTheme.spacingLG)
                .padding(.top, BLTheme.spacingMD)

                Spacer()

                Text("Edit entry")
                    .font(BLTheme.headlineSerif(28))
                    .foregroundStyle(BLTheme.textPrimary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(weightWhole).\(weightDecimal)")
                        .font(BLTheme.numberDisplay(56))
                        .foregroundStyle(BLTheme.textPrimary)
                    Text(unit.rawValue)
                        .font(BLTheme.titleSerif(20))
                        .foregroundStyle(BLTheme.textSecondary)
                }

                HStack(spacing: 0) {
                    Picker("Whole", selection: $weightWhole) {
                        ForEach(20...300, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 100)

                    Text(".")
                        .font(BLTheme.numberDisplay(32))
                        .foregroundStyle(BLTheme.textTertiary)

                    Picker("Decimal", selection: $weightDecimal) {
                        ForEach(0...9, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                }
                .frame(height: 150)

                TextField("Note", text: $note)
                    .font(BLTheme.body())
                    .padding(14)
                    .background(BLTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: BLTheme.radiusMD))
                    .padding(.horizontal, BLTheme.spacingLG)

                Spacer()

                VStack(spacing: 12) {
                    BLPrimaryButton("Update", action: saveEdit)

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Text("Delete Entry")
                            .font(BLTheme.body(15))
                            .foregroundStyle(BLTheme.danger)
                    }
                }
                .padding(.horizontal, BLTheme.spacingLG)
                .padding(.bottom, BLTheme.spacingLG)
            }
        }
        .alert("Delete this entry?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(entry)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            let (w, d) = entry.weight.toPickerComponents(unit: unit)
            weightWhole = w
            weightDecimal = d
            note = entry.note ?? ""
        }
        .presentationDetents([.large])
    }

    private func saveEdit() {
        entry.weight = Double.fromPicker(whole: weightWhole, decimal: weightDecimal, unit: unit)
        entry.note = note.isEmpty ? nil : note
        dismiss()
    }
}
