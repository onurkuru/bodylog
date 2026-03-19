import Foundation

extension Date {
    /// Start of day for date comparison
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Check if this date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Check if this date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Short display format: "Mar 19"
    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }

    /// Medium display format: "Mar 19, 2026"
    var mediumFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    /// Relative display: "Today", "Yesterday", or short format
    var relativeFormatted: String {
        if isToday { return "Today" }
        if isYesterday { return "Yesterday" }
        return shortFormatted
    }

    /// Days between two dates
    func daysFrom(_ date: Date) -> Int {
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: date)
        let to = calendar.startOfDay(for: self)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    /// Date N days ago
    static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
    }
}
