import Foundation
import SwiftData

enum ChartRange: String, CaseIterable, Identifiable {
    case week = "7D"
    case month = "30D"
    case allTime = "All"

    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .week: 7
        case .month: 30
        case .allTime: nil
        }
    }
}

struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
}

struct WeightStats {
    let current: Double?
    let change: Double?
    let goalProgress: Double? // 0.0 to 1.0
}

@Observable
final class DashboardViewModel {
    var selectedRange: ChartRange = .month

    // MARK: - Chart Data

    func chartPoints(from entries: [WeightEntry], range: ChartRange) -> [ChartPoint] {
        let sorted = entries.sorted { $0.date < $1.date }

        let filtered: [WeightEntry]
        if let days = range.days {
            let cutoff = Date.daysAgo(days)
            filtered = sorted.filter { $0.date >= cutoff }
        } else {
            filtered = sorted
        }

        return filtered.map { ChartPoint(date: $0.date, weight: $0.weight) }
    }

    // MARK: - Streak

    func calculateStreak(from entries: [WeightEntry]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        // Get unique days that have entries, sorted descending
        let entryDays = Set(entries.map { calendar.startOfDay(for: $0.date) })
            .sorted(by: >)

        guard !entryDays.isEmpty else { return 0 }

        var streak = 0
        var checkDate = today

        // Grace period: if no entry today, start from yesterday
        if !entryDays.contains(today) {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            if entryDays.contains(yesterday) {
                checkDate = yesterday
            } else {
                return 0
            }
        }

        while entryDays.contains(checkDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = previousDay
        }

        return streak
    }

    // MARK: - Stats

    func stats(from entries: [WeightEntry], goalWeight: Double?) -> WeightStats {
        let sorted = entries.sorted { $0.date < $1.date }
        let current = sorted.last?.weight
        let first = sorted.first?.weight

        let change: Double? = if let current, let first {
            current - first
        } else {
            nil
        }

        var goalProgress: Double? = nil
        if let current, let goal = goalWeight, let first {
            let totalNeeded = first - goal
            if totalNeeded == 0 {
                goalProgress = 1.0
            } else {
                let achieved = first - current
                goalProgress = min(max(achieved / totalNeeded, 0), 1.0)
            }
        }

        return WeightStats(current: current, change: change, goalProgress: goalProgress)
    }

    // MARK: - Recent Entries

    func recentEntries(from entries: [WeightEntry], limit: Int = 10) -> [WeightEntry] {
        entries.sorted { $0.date > $1.date }.prefix(limit).map { $0 }
    }

    // MARK: - Today Check

    func hasEntryToday(entries: [WeightEntry]) -> Bool {
        entries.contains { $0.date.isToday }
    }
}
