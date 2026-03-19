import SwiftUI

// MARK: - BodyLog Design System
// Editorial serif typography, mint accent, generous whitespace, pill-shaped cards

enum BLTheme {

    // MARK: - Colors

    /// Primary accent: mint/emerald green
    static let accent = Color(red: 0.30, green: 0.78, blue: 0.55) // #4DC78C
    /// Light accent for selected backgrounds
    static let accentLight = Color(red: 0.30, green: 0.78, blue: 0.55).opacity(0.15)
    /// Background: warm off-white
    static let background = Color(red: 0.965, green: 0.965, blue: 0.975) // #F7F7F9
    /// Card background: pure white
    static let cardBackground = Color.white
    /// Text primary
    static let textPrimary = Color(red: 0.10, green: 0.10, blue: 0.12)
    /// Text secondary
    static let textSecondary = Color(red: 0.55, green: 0.55, blue: 0.58)
    /// Text tertiary
    static let textTertiary = Color(red: 0.75, green: 0.75, blue: 0.78)
    /// Danger/destructive
    static let danger = Color(red: 0.90, green: 0.30, blue: 0.30)
    /// Success
    static let success = Color(red: 0.30, green: 0.78, blue: 0.55)
    /// Streak orange
    static let streak = Color(red: 1.0, green: 0.60, blue: 0.20)
    /// Dark green for buttons
    static let darkGreen = Color(red: 0.18, green: 0.28, blue: 0.22)
    /// Input background
    static let inputBg = Color(red: 0.94, green: 0.94, blue: 0.96)
    /// Border
    static let border = Color(red: 0.90, green: 0.90, blue: 0.92)

    // MARK: - Typography (Serif + Sans mix)

    /// Large editorial headline — serif, bold
    static func headlineSerif(_ size: CGFloat = 32) -> Font {
        .system(size: size, weight: .bold, design: .serif)
    }

    /// Section title — serif, semibold
    static func titleSerif(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    /// Body text — rounded sans
    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    /// Bold body — rounded sans bold
    static func bodyBold(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    /// Caption text
    static func caption(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    /// Large number display — serif
    static func numberDisplay(_ size: CGFloat = 48) -> Font {
        .system(size: size, weight: .bold, design: .serif)
    }

    // MARK: - Spacing

    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32
    static let spacingXXL: CGFloat = 48

    // MARK: - Radius

    static let radiusSM: CGFloat = 12
    static let radiusMD: CGFloat = 16
    static let radiusLG: CGFloat = 24
    static let radiusPill: CGFloat = 50
}

// MARK: - Reusable Components

/// Pill-shaped card
struct BLCard<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    var body: some View {
        content()
            .padding(BLTheme.spacingLG)
            .background(BLTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: BLTheme.radiusLG))
            .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
}

/// Circle button
struct BLCircleButton: View {
    let icon: String
    let filled: Bool
    let action: () -> Void

    init(icon: String, filled: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.filled = filled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(filled ? .white : BLTheme.accent)
                .frame(width: 44, height: 44)
                .background(filled ? BLTheme.accent : BLTheme.accent.opacity(0.0))
                .overlay(
                    Circle().stroke(filled ? Color.clear : BLTheme.textTertiary, lineWidth: 1.5)
                )
                .clipShape(Circle())
        }
    }
}

/// Primary CTA button
struct BLPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    init(_ title: String, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(BLTheme.bodyBold(17))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(BLTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: BLTheme.radiusPill))
        }
        .disabled(isLoading)
    }
}

/// Step indicator (dots)
struct BLStepIndicator: View {
    let totalSteps: Int
    let currentStep: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index <= currentStep ? BLTheme.accent : BLTheme.border)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

/// Selection pill card
struct BLSelectionPill<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    let content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .padding(.horizontal, BLTheme.spacingLG)
                .padding(.vertical, BLTheme.spacingMD)
                .frame(maxWidth: .infinity)
                .background(isSelected ? BLTheme.accentLight : BLTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: BLTheme.radiusPill)
                        .stroke(isSelected ? BLTheme.accent : BLTheme.border, lineWidth: isSelected ? 2 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BLTheme.radiusPill))
        }
        .buttonStyle(.plain)
    }
}
