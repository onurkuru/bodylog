import Foundation

enum Config {
    // Replace with your actual RevenueCat API key
    static let revenueCatKey = "appl_ExwOtkcEsCLyodpreHDeBKjCdlx"

    // URL Scheme for deep links
    static let urlScheme = "bodylog"

    // Free tier limits
    static let freePhotoLimit = 10
    static let freeChartDays = 30

    // Photo settings
    static let photoMaxDimension: CGFloat = 1200
    static let photoCompressionQuality: CGFloat = 0.85
    static let thumbMaxDimension: CGFloat = 300
    static let thumbCompressionQuality: CGFloat = 0.7
}
