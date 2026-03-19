import Foundation
import RevenueCat

@MainActor @Observable
final class EntitlementManager {
    private(set) var isPro: Bool = false
    private(set) var currentOffering: Offering?
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    static let shared = EntitlementManager()
    private init() {
        // Record trial start on first launch
        if UserDefaults.standard.object(forKey: "trialStartDate") == nil {
            UserDefaults.standard.set(Date.now, forKey: "trialStartDate")
        }
    }

    // MARK: - Trial

    static let trialDays: Int = 3

    var trialStartDate: Date {
        UserDefaults.standard.object(forKey: "trialStartDate") as? Date ?? Date.now
    }

    var trialEndDate: Date {
        Calendar.current.date(byAdding: .day, value: Self.trialDays, to: trialStartDate) ?? trialStartDate
    }

    var trialDaysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date.now, to: trialEndDate).day ?? 0)
    }

    var isTrialActive: Bool {
        Date.now < trialEndDate
    }

    /// User has access: either Pro subscriber OR within trial period
    var hasAccess: Bool {
        isPro || isTrialActive
    }

    // MARK: - Setup

    func configure() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Config.revenueCatKey)

        // Listen for customer info changes
        Purchases.shared.delegate = PurchaseDelegateHandler.shared
        PurchaseDelegateHandler.shared.entitlementManager = self

        Task {
            await checkEntitlements()
            await fetchOfferings()
        }
    }

    // MARK: - Entitlement Check

    func checkEntitlements() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            updateProStatus(from: customerInfo)
        } catch {
            // Silently fail — isPro stays false (safe default)
        }
    }

    func updateProStatus(from customerInfo: CustomerInfo) {
        isPro = customerInfo.entitlements["pro"]?.isActive == true
    }

    // MARK: - Offerings

    func fetchOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.current
        } catch {
            // Offerings unavailable — paywall will show error state
        }
    }

    // MARK: - Purchase

    @discardableResult
    func purchase(package: Package) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                updateProStatus(from: result.customerInfo)
                return true
            }
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            updateProStatus(from: customerInfo)
            return isPro
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

// MARK: - RevenueCat Delegate

final class PurchaseDelegateHandler: NSObject, PurchasesDelegate, @unchecked Sendable {
    static let shared = PurchaseDelegateHandler()
    weak var entitlementManager: EntitlementManager?

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            entitlementManager?.updateProStatus(from: customerInfo)
        }
    }
}
