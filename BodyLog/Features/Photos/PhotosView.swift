import SwiftUI
import SwiftData

struct PhotosView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(EntitlementManager.self) private var entitlementManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PhotoEntry.date, order: .reverse) private var photos: [PhotoEntry]

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ZStack {
            BLTheme.background.ignoresSafeArea()

            if photos.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: BLTheme.spacingMD) {
                        // Header
                        HStack {
                            Text("Photos")
                                .font(BLTheme.headlineSerif(28))
                                .foregroundStyle(BLTheme.textPrimary)
                            Spacer()

                            if photos.count >= 2 {
                                BLCircleButton(icon: "rectangle.on.rectangle") {
                                    openCompare()
                                }
                            }

                            BLCircleButton(icon: "plus", filled: true) {
                                addPhoto()
                            }
                        }

                        // Photo count (free users)
                        if !entitlementManager.isPro {
                            Text("\(photos.count)/\(Config.freePhotoLimit) free photos")
                                .font(BLTheme.caption(12))
                                .foregroundStyle(BLTheme.textTertiary)
                        }

                        // Grid
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(photos) { photo in
                                PhotoGridCell(photo: photo)
                                    .onTapGesture {
                                        appViewModel.showPhotoDetail(photo)
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, BLTheme.spacingMD)
                    .padding(.top, BLTheme.spacingSM)
                    .padding(.bottom, BLTheme.spacingXL)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: BLTheme.spacingLG) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(BLTheme.textTertiary)

            Text("No progress\nphotos yet")
                .font(BLTheme.headlineSerif(28))
                .foregroundStyle(BLTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text("Take your first photo to start\ntracking your transformation")
                .font(BLTheme.body(15))
                .foregroundStyle(BLTheme.textSecondary)
                .multilineTextAlignment(.center)

            BLPrimaryButton("Add Photo") { addPhoto() }
                .padding(.horizontal, BLTheme.spacingXL)
        }
    }

    private func addPhoto() {
        if !entitlementManager.isPro && photos.count >= Config.freePhotoLimit {
            appViewModel.showPaywall(trigger: .photoLimit)
            return
        }
        appViewModel.showPhotoCapture()
    }

    private func openCompare() {
        let sorted = photos.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return }
        if entitlementManager.isPro {
            appViewModel.showPhotoCompare(before: sorted.first!, after: sorted.last!)
        } else {
            let last = sorted.suffix(2)
            appViewModel.showPhotoCompare(before: last.first!, after: last.last!)
        }
    }
}

// MARK: - Grid Cell

struct PhotoGridCell: View {
    let photo: PhotoEntry
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(minHeight: 200)
                    .clipped()
            } else {
                Rectangle()
                    .fill(BLTheme.cardBackground)
                    .frame(minHeight: 200)
                    .overlay { ProgressView().tint(BLTheme.textTertiary) }
            }

            // Overlay
            VStack(alignment: .leading, spacing: 2) {
                Text(photo.date.shortFormatted)
                    .font(BLTheme.bodyBold(12))
                Text(photo.pose.rawValue)
                    .font(BLTheme.caption(10))
            }
            .foregroundStyle(.white)
            .padding(8)
            .background(.ultraThinMaterial.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: BLTheme.radiusMD))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        Task.detached(priority: .userInitiated) {
            let image = PhotoStorageManager.shared.loadThumbnail(named: photo.thumbnailName)
            await MainActor.run { thumbnail = image }
        }
    }
}
