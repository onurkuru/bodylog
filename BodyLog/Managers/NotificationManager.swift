import Foundation
import UserNotifications

@Observable
final class NotificationManager {
    private(set) var isAuthorized: Bool = false

    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    private init() {
        Task { await checkAuthorizationStatus() }
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { isAuthorized = granted }
            return granted
        } catch {
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        await MainActor.run {
            isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Daily Reminder

    func scheduleDailyReminder(hour: Int, minute: Int, currentStreak: Int = 0) {
        guard isAuthorized else { return }
        center.removePendingNotificationRequests(withIdentifiers: ["daily_weight_reminder"])

        let content = UNMutableNotificationContent()
        content.title = "Time to log your weight"
        if currentStreak > 0 {
            content.body = "Keep your \(currentStreak)-day streak alive!"
        } else {
            content.body = "Start building your streak today."
        }
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily_weight_reminder",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    /// Cancel today's reminder if user already logged (call after weight save)
    func suppressTodayIfLogged() {
        center.removePendingNotificationRequests(withIdentifiers: ["daily_weight_reminder"])
        // Will be re-scheduled tomorrow via the repeating trigger
    }

    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["daily_weight_reminder"])
    }

    // MARK: - Streak Warning (9 PM if not logged)

    func scheduleStreakWarning(currentStreak: Int) {
        center.removePendingNotificationRequests(withIdentifiers: ["streak_warning"])

        guard isAuthorized, currentStreak > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Don't break your streak!"
        content.body = "\(currentStreak)-day streak — 1 tap to log."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 21
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "streak_warning",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    func cancelStreakWarning() {
        center.removePendingNotificationRequests(withIdentifiers: ["streak_warning"])
    }
}
