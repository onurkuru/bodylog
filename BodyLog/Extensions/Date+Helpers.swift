import Foundation

// MARK: - Cached DateFormatters (allocated once, reused)

private let shortDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM d"
    return f
}()

private let mediumDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f
}()

private let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    return f
}()

private let monthYearFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMMM yyyy"
    return f
}()

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
        shortDateFormatter.string(from: self)
    }

    /// Medium display format: "Mar 19, 2026"
    var mediumFormatted: String {
        mediumDateFormatter.string(from: self)
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

    /// Month + year: "March 2026" (for timeline grouping)
    var monthYearFormatted: String {
        monthYearFormatter.string(from: self)
    }

    /// Format time from components (used in Settings)
    static func formatTime(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? .now
        return timeFormatter.string(from: date)
    }
}
