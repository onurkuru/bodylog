import Foundation
import WidgetKit

/// Shared data store for main app ↔ widget communication via AppGroup UserDefaults.
enum WidgetDataStore {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: Config.appGroupID)
    }

    // MARK: - Keys

    private enum Keys {
        static let lastWeight = "lastWeight"
        static let lastWeightUnit = "lastWeightUnit"
        static let currentStreak = "currentStreak"
        static let lastEntryDate = "lastEntryDate"
        static let goalWeight = "goalWeight"
    }

    // MARK: - Write (from main app)

    static func update(
        lastWeight: Double,
        unit: WeightUnit,
        streak: Int,
        entryDate: Date,
        goalWeight: Double?
    ) {
        let d = defaults
        d?.set(lastWeight, forKey: Keys.lastWeight)
        d?.set(unit.rawValue, forKey: Keys.lastWeightUnit)
        d?.set(streak, forKey: Keys.currentStreak)
        d?.set(entryDate.timeIntervalSince1970, forKey: Keys.lastEntryDate)
        if let goal = goalWeight {
            d?.set(goal, forKey: Keys.goalWeight)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Read (from widget)

    static var lastWeight: Double {
        defaults?.double(forKey: Keys.lastWeight) ?? 0
    }

    static var lastWeightUnit: String {
        defaults?.string(forKey: Keys.lastWeightUnit) ?? "kg"
    }

    static var currentStreak: Int {
        defaults?.integer(forKey: Keys.currentStreak) ?? 0
    }

    static var lastEntryDate: Date? {
        guard let interval = defaults?.object(forKey: Keys.lastEntryDate) as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: interval)
    }

    static var goalWeight: Double? {
        defaults?.object(forKey: Keys.goalWeight) as? Double
    }
}
