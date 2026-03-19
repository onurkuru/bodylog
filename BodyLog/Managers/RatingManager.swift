import StoreKit
import UIKit

/// Manages App Store rating prompt based on blueprint criteria:
/// - 5+ weight entries
/// - 7+ days using app
/// - After first PhotoCompareView dismiss
/// - Not shown in last 60 days
enum RatingManager {
    private static let lastPromptKey = "lastRatingPromptDate"
    private static let hasComparedKey = "hasComparedPhotos"

    static func markCompareUsed() {
        UserDefaults.standard.set(true, forKey: hasComparedKey)
    }

    static func requestIfEligible(entryCount: Int) {
        let hasCompared = UserDefaults.standard.bool(forKey: hasComparedKey)
        guard hasCompared else { return }
        guard entryCount >= 5 else { return }

        // Check 60-day cooldown
        if let lastPrompt = UserDefaults.standard.object(forKey: lastPromptKey) as? Date {
            let daysSince = Date.now.daysFrom(lastPrompt)
            guard daysSince >= 60 else { return }
        }

        // Check app installed for 7+ days (use first launch date)
        let firstLaunchKey = "firstLaunchDate"
        if UserDefaults.standard.object(forKey: firstLaunchKey) == nil {
            UserDefaults.standard.set(Date.now, forKey: firstLaunchKey)
            return // First launch — too early
        }
        if let firstLaunch = UserDefaults.standard.object(forKey: firstLaunchKey) as? Date {
            guard Date.now.daysFrom(firstLaunch) >= 7 else { return }
        }

        // All conditions met — prompt
        UserDefaults.standard.set(Date.now, forKey: lastPromptKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
