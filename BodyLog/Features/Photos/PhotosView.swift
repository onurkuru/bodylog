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

    // Group photos by month for timeline
    private var groupedByMonth: [(key: String, photos: [PhotoEntry])] {
        let grouped = Dictionary(grouping: displayedPhotos) { entry in
            entry.date.monthYearFormatted
        }
        // Sort by the earliest photo date in each group (newest month first)
        return grouped.map { (key: $0.key, photos: $0.value) }
            .sorted { lhs, rhs in
                guard let l = lhs.photos.first?.date, let r = rhs.photos.first?.date else { return false }
                return l > r
            }
    }

    // Day 1 vs Today data
    private var transformationPair: (before: PhotoEntry, after: PhotoEntry)? {
        // Find the best pose with at least 2 photos
        let poseCounts = Dictionary(grouping: photos, by: \.pose)
        guard let bestPose = poseCounts
            .filter({ $0.value.count >= 2 })
            .max(by: { $0.value.count < $1.value.count })?
            .key else { return nil }

        let samePose = photos.filter { $0.pose == bestPose }
        guard let newest = samePose.first, let oldest = samePose.last,
              newest.id != oldest.id else { return nil }
        return (before: oldest, after: newest)
    }

    private var daysSinceStart: Int {
        guard let oldest = photos.last else { return 0 }
        return Calendar.current.dateComponents([.day], from: oldest.date, to: .now).day ?? 0
    }

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

                        // MARK: - Day 1 vs Today Hero Card
                        if let pair = transformationPair {
                            TransformationHeroCard(
                                before: pair.before,
                                after: pair.after,
                                daysSinceStart: daysSinceStart,
                                unit: unit
                            ) {
                                appViewModel.showPhotoCompare(
                                    before: pair.before,
                                    after: pair.after
                                )
                            }
                        }

                        // Pose filter
                        poseFilterBar

                        // MARK: - Timeline
                        timelineContent
                    }
                    .padding(.horizontal, BLTheme.spacingMD)
                    .padding(.top, BLTheme.spacingSM)
                    .padding(.bottom, BLTheme.spacingXL)
                }
            }
        }
    }

    // MARK: - Timeline Content

    private var timelineContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groupedByMonth.enumerated()), id: \.element.key) { index, group in
                // Month header
                HStack(spacing: 10) {
                    // Timeline dot
                    Circle()
                        .fill(index == 0 ? BLTheme.accent : BLTheme.textTertiary)
                        .frame(width: 10, height: 10)

                    Text(group.key)
                        .font(BLTheme.bodyBold(14))
                        .foregroundStyle(index == 0 ? BLTheme.accent : BLTheme.textSecondary)
                }
                .padding(.bottom, 8)

                // Photos in this month
                HStack(alignment: .top, spacing: 0) {
                    // Timeline line
                    Rectangle()
                        .fill(BLTheme.border)
                        .frame(width: 1.5)
                        .padding(.leading, 4.25)

                    Spacer().frame(width: 16)

                    // Photo grid for this month
                    let columns = [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ]

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(group.photos) { photo in
                            PhotoGridCell(photo: photo, unit: unit)
                                .onTapGesture {
                                    appViewModel.showPhotoDetail(photo)
                                }
                                .onLongPressGesture {
                                    let samePose = photos.filter { $0.pose == photo.pose }
                                    guard samePose.count >= 2 else { return }
                                    let oldest = samePose.last!
                                    let after = photo.id == oldest.id ? samePose.first! : photo
                                    appViewModel.showPhotoCompare(before: oldest, after: after)
                                }
                        }
                    }
                }
                .padding(.bottom, BLTheme.spacingMD)
            }
        }
    }

    // MARK: - Subviews

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

    // MARK: - Actions

    private func addPhoto() {
        if !entitlementManager.isPro && photos.count >= Config.freePhotoLimit {
            appViewModel.showPaywall(trigger: .photoLimit)
            return
        }
        appViewModel.showPhotoCapture()
    }

    private func openCompare() {
        guard photos.count >= 2 else { return }
        let poseCounts = Dictionary(grouping: photos, by: \.pose)
        let bestPose = poseCounts.max(by: { $0.value.count < $1.value.count })!.key
        let samePose = photos.filter { $0.pose == bestPose }
        guard samePose.count >= 2, let newest = samePose.first, let oldest = samePose.last else { return }
        appViewModel.showPhotoCompare(before: oldest, after: newest)
    }
}

// MARK: - Transformation Hero Card (Day 1 vs Today)

struct TransformationHeroCard: View {
    let before: PhotoEntry
    let after: PhotoEntry
    let daysSinceStart: Int
    let unit: WeightUnit
    let action: () -> Void

    @State private var beforeThumb: UIImage?
    @State private var afterThumb: UIImage?

    private var weightChange: String? {
        guard let w1 = before.linkedWeight, let w2 = after.linkedWeight else { return nil }
        let diff = w2 - w1
        return diff.formattedWithSign(unit: unit)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Photos side by side
                HStack(spacing: 0) {
                    // Before
                    ZStack(alignment: .bottomLeading) {
                        photoView(beforeThumb)
                        dayLabel("Day 1", date: before.date)
                    }

                    // Divider
                    Rectangle()
                        .fill(BLTheme.accent)
                        .frame(width: 2)

                    // After
                    ZStack(alignment: .bottomTrailing) {
                        photoView(afterThumb)
                        dayLabel("Day \(daysSinceStart)", date: after.date)
                    }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: BLTheme.radiusMD, style: .continuous))

                // Stats bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your Transformation")
                            .font(BLTheme.bodyBold(14))
                            .foregroundStyle(BLTheme.textPrimary)

                        HStack(spacing: 12) {
                            Label("\(daysSinceStart) days", systemImage: "calendar")
                            if let change = weightChange {
                                Label(change, systemImage: "scalemass")
                            }
                        }
                        .font(BLTheme.caption(12))
                        .foregroundStyle(BLTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BLTheme.accent)
                }
                .padding(.horizontal, BLTheme.spacingMD)
                .padding(.vertical, 12)
            }
            .background(BLTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: BLTheme.radiusLG))
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .onAppear { loadThumbs() }
    }

    private func photoView(_ image: UIImage?) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.1))
                    .overlay { ProgressView().tint(.white) }
            }
        }
    }

    private func dayLabel(_ text: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(text)
                .font(BLTheme.bodyBold(12))
            Text(date.shortFormatted)
                .font(BLTheme.caption(10))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(8)
    }

    private func loadThumbs() {
        let bName = before.thumbnailName
        let aName = after.thumbnailName
        Task.detached(priority: .userInitiated) {
            async let b = PhotoStorageManager.shared.loadThumbnail(named: bName)
            async let a = PhotoStorageManager.shared.loadThumbnail(named: aName)
            let (bImg, aImg) = await (b, a)
            await MainActor.run {
                beforeThumb = bImg
                afterThumb = aImg
            }
        }
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
