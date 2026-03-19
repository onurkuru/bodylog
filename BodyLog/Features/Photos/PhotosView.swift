import SwiftUI
import SwiftData

struct PhotosView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(EntitlementManager.self) private var entitlementManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PhotoEntry.date, order: .reverse) private var photos: [PhotoEntry]
    @Query private var settingsArray: [UserSettings]

    @State private var selectedPose: Pose? = nil

    private var unit: WeightUnit { settingsArray.first?.unitPreference ?? .kg }
    private var displayedPhotos: [PhotoEntry] {
        guard let pose = selectedPose else { return photos }
        return photos.filter { $0.pose == pose }
    }
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

                        // Pose filter
                        poseFilterBar

                        // Grid
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(displayedPhotos) { photo in
                                PhotoGridCell(photo: photo, unit: unit)
                                    .onTapGesture {
                                        appViewModel.showPhotoDetail(photo)
                                    }
                                    .onLongPressGesture {
                                        // Filter to same pose as tapped photo
                                        let samePose = photos.filter { $0.pose == photo.pose }
                                        guard samePose.count >= 2 else { return }
                                        // samePose is newest-first (from @Query reverse order)
                                        let oldest = samePose.last!
                                        let after = photo.id == oldest.id ? samePose.first! : photo
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

    private var poseFilterBar: some View {
        HStack(spacing: 6) {
            poseChip("All", pose: nil)
            ForEach(Pose.allCases) { pose in
                poseChip(pose.rawValue, pose: pose)
            }
        }
    }

    private func poseChip(_ label: String, pose: Pose?) -> some View {
        let isSelected = selectedPose == pose
        let count = pose == nil ? photos.count : photos.filter { $0.pose == pose }.count
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedPose = pose }
        } label: {
            HStack(spacing: 4) {
                Text(label)
                if count > 0 {
                    Text("\(count)")
                        .font(BLTheme.caption(10))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : BLTheme.textTertiary)
                }
            }
            .font(BLTheme.caption(13))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .foregroundStyle(isSelected ? .white : BLTheme.textPrimary)
            .background(isSelected ? BLTheme.accent : BLTheme.cardBackground)
            .clipShape(Capsule())
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
        guard photos.count >= 2 else { return }
        // Pick most common pose, then compare oldest vs newest of that pose
        let poseCounts = Dictionary(grouping: photos, by: \.pose)
        let bestPose = poseCounts.max(by: { $0.value.count < $1.value.count })!.key
        let samePose = photos.filter { $0.pose == bestPose }
        guard samePose.count >= 2, let newest = samePose.first, let oldest = samePose.last else { return }
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
        let name = photo.thumbnailName // capture on main actor
        loadTask = Task.detached(priority: .userInitiated) {
            let image = PhotoStorageManager.shared.loadThumbnail(named: name)
            guard !Task.isCancelled else { return }
            await MainActor.run { thumbnail = image }
        }
    }
}
