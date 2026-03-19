import SwiftUI
import RevenueCat

struct PaywallSheet: View {
    @Environment(EntitlementManager.self) private var entitlementManager
    @Environment(\.dismiss) private var dismiss

    let trigger: PaywallTrigger

    @State private var selectedPlan: PlanOption = .lifetime
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    enum PlanOption { case monthly, lifetime }

    private var isDismissable: Bool {
        trigger != .trialEnded
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: BLTheme.spacingLG) {
                // Close (only if dismissable)
                HStack {
                    Spacer()
                    if isDismissable {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(width: 32, height: 32)
                                .background(.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, BLTheme.spacingLG)

                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(BLTheme.accent.opacity(0.2))
                        .frame(width: 80, height: 80)
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(BLTheme.accent)
                }

                // Title
                Text(titleForTrigger)
                    .font(BLTheme.headlineSerif(36))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(subtitleForTrigger)
                    .font(BLTheme.body(15))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BLTheme.spacingXL)

                // Features
                VStack(alignment: .leading, spacing: 14) {
                    featureRow(icon: "photo.fill.on.rectangle.fill", text: "Unlimited progress photos")
                    featureRow(icon: "chart.xyaxis.line", text: "Full weight history")
                    featureRow(icon: "rectangle.on.rectangle", text: "Compare any two photos")
                }
                .padding(.horizontal, BLTheme.spacingXL)

                Spacer()

                // Pricing
                VStack(spacing: 12) {
                    pricingPill(
                        title: "$2.99 / month",
                        subtitle: "Billed monthly",
                        isSelected: selectedPlan == .monthly,
                        badge: nil
                    ) { selectedPlan = .monthly }

                    pricingPill(
                        title: "$19.99 one-time",
                        subtitle: "Pay once, keep forever",
                        isSelected: selectedPlan == .lifetime,
                        badge: "Best Value"
                    ) { selectedPlan = .lifetime }
                }
                .padding(.horizontal, BLTheme.spacingLG)

                // CTA
                Button(action: purchase) {
                    HStack {
                        if isPurchasing {
                            ProgressView().tint(.black)
                        } else {
                            Text(ctaText)
                                .font(BLTheme.bodyBold(17))
                        }
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(BLTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: BLTheme.radiusPill))
                }
                .disabled(isPurchasing)
                .padding(.horizontal, BLTheme.spacingLG)

                // "Start free trial" skip button (onboarding only)
                if trigger == .onboarding {
                    Button {
                        dismiss()
                    } label: {
                        Text("Start \(EntitlementManager.trialDays)-Day Free Trial")
                            .font(BLTheme.bodyBold(15))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, -8)
                }

                // Restore + Legal
                VStack(spacing: 8) {
                    Button("Restore Purchases") { restore() }
                        .font(BLTheme.body(14))
                        .foregroundStyle(.white.opacity(0.5))

                    Text("Payment will be charged to your Apple ID account. Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period.")
                        .font(BLTheme.caption(10))
                        .foregroundStyle(.white.opacity(0.25))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BLTheme.spacingXL)
                }
                .padding(.bottom, BLTheme.spacingMD)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: { Text(errorMessage) }
    }

    // MARK: - Subviews

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(BLTheme.accent)
                .frame(width: 24)
            Text(text)
                .font(BLTheme.body(15))
                .foregroundStyle(.white)
        }
    }

    private func pricingPill(title: String, subtitle: String, isSelected: Bool, badge: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BLTheme.bodyBold())
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(BLTheme.caption(12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                if let badge {
                    Text(badge)
                        .font(BLTheme.caption(11))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(BLTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? BLTheme.accent : .white.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: BLTheme.radiusLG)
                    .fill(.white.opacity(isSelected ? 0.1 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: BLTheme.radiusLG)
                            .stroke(isSelected ? BLTheme.accent : .white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logic

    private var ctaText: String {
        switch trigger {
        case .onboarding: "Subscribe Now"
        case .trialEnded: "Subscribe to Continue"
        default: "Continue"
        }
    }

    private var titleForTrigger: String {
        switch trigger {
        case .trialEnded: "Your Trial\nHas Ended"
        case .onboarding: "Start Your\nFree Trial"
        default: "Unlock\nBodygraph Pro"
        }
    }

    private var subtitleForTrigger: String {
        switch trigger {
        case .photoLimit: "You've built an amazing collection.\nUnlock unlimited photos to keep going."
        case .allTimeChart: "See your complete transformation\nstory from day one."
        case .csvExport: "Export all your weight data\nto a spreadsheet."
        case .trialEnded: "Subscribe to continue tracking\nyour transformation."
        case .onboarding: "Try everything free for \(EntitlementManager.trialDays) days.\nNo commitment, cancel anytime."
        }
    }

    private func purchase() {
        guard let offering = entitlementManager.currentOffering else { return }
        let packageID = selectedPlan == .monthly ? "$rc_monthly" : "$rc_lifetime"
        guard let package = offering.availablePackages.first(where: { $0.identifier == packageID })
               ?? offering.availablePackages.first else { return }

        isPurchasing = true
        Task {
            let success = await entitlementManager.purchase(package: package)
            isPurchasing = false
            if success { dismiss() }
            else if let error = entitlementManager.errorMessage {
                errorMessage = error
                showError = true
            }
        }
    }

    private func restore() {
        isPurchasing = true
        Task {
            let restored = await entitlementManager.restorePurchases()
            isPurchasing = false
            if restored { dismiss() }
            else { errorMessage = "No active subscription found."; showError = true }
        }
    }
}
