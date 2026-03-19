import SwiftUI
import SwiftData

struct PhotosView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(EntitlementManager.self) private var entitlementManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PhotoEntry.date, order: .reverse) private var photos: [PhotoEntry]
    @Query private var settingsArray: [UserSettings]

    private var unit: WeightUnit { settingsArray.first?.unitPreference ?? .kg }
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
                                PhotoGridCell(photo: photo, unit: unit)
                                    .onTapGesture {
                                        appViewModel.showPhotoDetail(photo)
                                    }
                                    .onLongPressGesture {
                                        // photos is sorted reverse (newest first)
                                        guard let oldest = photos.last, let newest = photos.first, photos.count >= 2 else { return }
                                        let after = photo.id == oldest.id ? newest : photo
                                        appViewModel.showPhotoCompare(before: oldest, after: after)
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
        // photos is sorted reverse (newest first)
        guard photos.count >= 2, let oldest = photos.last, let newest = photos.first else { return }
        appViewModel.showPhotoCompare(before: oldest, after: newest)
    }
}

// MARK: - Grid Cell

struct PhotoGridCell: View {
    let photo: PhotoEntry
    let unit: WeightUnit
    @State private var thumbnail: UIImage?
    @State private var loadTask: Task<Void, Never>?

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
                if let w = photo.linkedWeight {
                    Text(w.formattedWithUnit(unit))
                        .font(BLTheme.bodyBold(11))
                }
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
        .onDisappear { loadTask?.cancel() }
    }

    private func loadThumbnail() {
        guard thumbnail == nil else { return }
        loadTask = Task.detached(priority: .userInitiated) {
            let image = PhotoStorageManager.shared.loadThumbnail(named: photo.thumbnailName)
            guard !Task.isCancelled else { return }
            await MainActor.run { thumbnail = image }
        }
    }
}
