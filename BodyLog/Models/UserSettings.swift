import Foundation
import SwiftData

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case kg = "kg"
    case lbs = "lbs"

    var id: String { rawValue }
}

enum DailyEntryBehavior: String, Codable, CaseIterable, Identifiable {
    case addNew = "Add New Entry"
    case updateExisting = "Update Existing"

    var id: String { rawValue }
}

@Model
final class UserSettings {
    var unitPreference: WeightUnit
    var goalWeight: Double? // Stored in kg
    var notificationHour: Int
    var notificationMinute: Int
    var notificationEnabled: Bool
    var onboardingCompleted: Bool
    var dailyEntryBehavior: DailyEntryBehavior

    init(
        unitPreference: WeightUnit = .kg,
        goalWeight: Double? = nil,
        notificationHour: Int = 20,
        notificationMinute: Int = 0,
        notificationEnabled: Bool = false,
        onboardingCompleted: Bool = false,
        dailyEntryBehavior: DailyEntryBehavior = .addNew
    ) {
        self.unitPreference = unitPreference
        self.goalWeight = goalWeight
        self.notificationHour = notificationHour
        self.notificationMinute = notificationMinute
        self.notificationEnabled = notificationEnabled
        self.onboardingCompleted = onboardingCompleted
        self.dailyEntryBehavior = dailyEntryBehavior
    }
}
