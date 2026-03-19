import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case photos = "Photos"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard: "chart.line.uptrend.xyaxis"
        case .photos: "photo.on.rectangle"
        case .settings: "gearshape"
        }
    }
}

enum AppSheet: Identifiable {
    case addWeight
    case editWeight(WeightEntry)
    case photoCapture
    case goalWeight
    case notificationPicker
    case paywall(PaywallTrigger)
    case streakDetail

    var id: String {
        switch self {
        case .addWeight: "addWeight"
        case .editWeight: "editWeight"
        case .photoCapture: "photoCapture"
        case .goalWeight: "goalWeight"
        case .notificationPicker: "notificationPicker"
        case .paywall(let trigger): "paywall_\(trigger.rawValue)"
        case .streakDetail: "streakDetail"
        }
    }
}

enum PaywallTrigger: String {
    case photoLimit
    case allTimeChart
    case csvExport
}

@Observable
final class AppViewModel {
    var selectedTab: AppTab = .dashboard
    var activeSheet: AppSheet?
    var activeFullScreenCover: FullScreenCover?

    enum FullScreenCover: Identifiable {
        case photoDetail(PhotoEntry)
        case photoCompare(before: PhotoEntry, after: PhotoEntry)

        var id: String {
            switch self {
            case .photoDetail(let entry): "detail_\(entry.id)"
            case .photoCompare(let b, let a): "compare_\(b.id)_\(a.id)"
            }
        }
    }

    // MARK: - Sheet Presentation

    func showAddWeight() {
        activeSheet = .addWeight
    }

    func showEditWeight(_ entry: WeightEntry) {
        activeSheet = .editWeight(entry)
    }

    func showPhotoCapture() {
        activeSheet = .photoCapture
    }

    func showPaywall(trigger: PaywallTrigger) {
        activeSheet = .paywall(trigger)
    }

    func dismissSheet() {
        activeSheet = nil
    }

    // MARK: - FullScreen Cover

    func showPhotoDetail(_ entry: PhotoEntry) {
        activeFullScreenCover = .photoDetail(entry)
    }

    func showPhotoCompare(before: PhotoEntry, after: PhotoEntry) {
        activeFullScreenCover = .photoCompare(before: before, after: after)
    }

    func dismissFullScreenCover() {
        activeFullScreenCover = nil
    }

    // MARK: - Deep Link Handling

    func handleDeepLink(_ url: URL) {
        guard url.scheme == "bodylog" else { return }

        switch url.host {
        case "dashboard":
            selectedTab = .dashboard
            if url.pathComponents.contains("add-weight") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.showAddWeight()
                }
            }
        default:
            break
        }
    }
}
