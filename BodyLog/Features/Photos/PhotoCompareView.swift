import SwiftUI
import SwiftData

struct PhotoCompareView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(EntitlementManager.self) private var entitlementManager
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PhotoEntry.date, order: .forward) private var allPhotos: [PhotoEntry]
    @Query private var weightEntries: [WeightEntry]
    @Query private var settingsArray: [UserSettings]

    let beforeEntry: PhotoEntry
    let afterEntry: PhotoEntry

    @State private var currentBefore: PhotoEntry?
    @State private var currentAfter: PhotoEntry?
    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    @State private var dividerPosition: CGFloat = 0.5
    @State private var isDragging = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var showUpgradeHint = false
    @State private var upgradeHintTask: Task<Void, Never>?
    @State private var selectedPose: Pose? = nil // nil = all poses

    private var unit: WeightUnit { settingsArray.first?.unitPreference ?? .kg }

    // Filtered photos by pose
    private var filteredPhotos: [PhotoEntry] {
        if let pose = selectedPose {
            return allPhotos.filter { $0.pose == pose }
        }
        return allPhotos
    }

    private var beforePhotos: [PhotoEntry] { filteredPhotos }
    private var afterPhotos: [PhotoEntry] { filteredPhotos }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                // Photo comparison area
                GeometryReader { geometry in
                    ZStack {
                        if let before = beforeImage, let after = afterImage {
                            comparisonView(before: before, after: after, size: geometry.size)
                        } else {
                            ProgressView().tint(.white)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }

                // Pose filter
                poseFilter

                // Date selectors
                dateSelectors

                // Bottom metadata
                bottomMetadata

                if showUpgradeHint && !entitlementManager.isPro {
                    upgradeHint
                }
            }
        }
        .onAppear {
            currentBefore = beforeEntry
            currentAfter = afterEntry
            loadImages()
        }
        .onDisappear {
            upgradeHintTask?.cancel()
            RatingManager.markCompareUsed()
            RatingManager.requestIfEligible(entryCount: weightEntries.count)
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage { ShareSheet(items: [image]) }
        }
        .onChange(of: currentBefore?.id) { loadImages() }
        .onChange(of: currentAfter?.id) { loadImages() }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Text("Compare")
                .font(BLTheme.bodyBold())
                .foregroundStyle(.white)
            Spacer()
            Button { shareComparison() } label: {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Comparison View (Hero)

    @ViewBuilder
    private func comparisonView(before: UIImage, after: UIImage, size: CGSize) -> some View {
        let dividerX = size.width * dividerPosition

        ZStack {
            // AFTER image (full, behind)
            Image(uiImage: after)
                .resizable().scaledToFill()
                .frame(width: size.width, height: size.height).clipped()

            // BEFORE image (clipped to left of divider)
            Image(uiImage: before)
                .resizable().scaledToFill()
                .frame(width: size.width, height: size.height).clipped()
                .mask(
                    HStack(spacing: 0) {
                        Rectangle().frame(width: dividerX)
                        Spacer(minLength: 0)
                    }
                )

            // Labels
            VStack {
                HStack {
                    Text("BEFORE")
                        .font(.caption.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(.leading, 12)
                        .opacity(dividerPosition > 0.15 ? 1 : 0)
                    Spacer()
                    Text("AFTER")
                        .font(.caption.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(.trailing, 12)
                        .opacity(dividerPosition < 0.85 ? 1 : 0)
                }
                .padding(.top, 12)
                Spacer()
            }

            // Divider handle
            DividerHandle(isDragging: isDragging)
                .position(x: dividerX, y: size.height / 2)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            dividerPosition = min(max(value.location.x / size.width, 0.02), 0.98)
                        }
                        .onEnded { _ in isDragging = false }
                )
        }
        .contentShape(Rectangle())
    }

    // MARK: - Pose Filter

    private var poseFilter: some View {
        HStack(spacing: 0) {
            poseTab("All", pose: nil)
            ForEach(Pose.allCases) { pose in
                poseTab(pose.rawValue, pose: pose)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: BLTheme.radiusPill))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func poseTab(_ label: String, pose: Pose?) -> some View {
        Button {
            selectedPose = pose
            // Reset selections if current ones don't match new filter
            if let pose {
                if currentBefore?.pose != pose {
                    currentBefore = filteredPhotos.first
                }
                if currentAfter?.pose != pose {
                    currentAfter = filteredPhotos.last
                }
            }
        } label: {
            Text(label)
                .font(BLTheme.caption(12))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(selectedPose == pose ? BLTheme.accent : Color.clear)
                .foregroundStyle(selectedPose == pose ? .white : .white.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: BLTheme.radiusPill))
        }
    }

    // MARK: - Date Selectors

    private var dateSelectors: some View {
        HStack(spacing: 12) {
            // Before selector
            dateSelector(
                label: "Before",
                current: currentBefore,
                photos: beforePhotos.filter { $0.id != currentAfter?.id },
                onChange: { photo in
                    if canSelect(photo) { currentBefore = photo }
                }
            )

            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))

            // After selector
            dateSelector(
                label: "After",
                current: currentAfter,
                photos: afterPhotos.filter { $0.id != currentBefore?.id },
                onChange: { photo in
                    if canSelect(photo) { currentAfter = photo }
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func dateSelector(label: String, current: PhotoEntry?, photos: [PhotoEntry], onChange: @escaping (PhotoEntry) -> Void) -> some View {
        Menu {
            ForEach(photos) { photo in
                Button {
                    onChange(photo)
                } label: {
                    HStack {
                        Text(photo.date.shortFormatted)
                        if let w = photo.linkedWeight {
                            Text("— \(w.formattedWithUnit(unit))")
                        }
                        Text("(\(photo.pose.rawValue))")
                        if photo.id == current?.id {
                            Image(systemName: "checkmark")
                        }
                        if !canSelect(photo) {
                            Image(systemName: "lock.fill")
                        }
                    }
                }
                .disabled(!canSelect(photo))
            }
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(BLTheme.caption(10))
                    .foregroundStyle(.white.opacity(0.5))
                Text(current?.date.shortFormatted ?? "—")
                    .font(BLTheme.bodyBold(14))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    /// Free users can only select the 2 most recent photos
    private func canSelect(_ photo: PhotoEntry) -> Bool {
        if entitlementManager.isPro { return true }
        let sorted = filteredPhotos.sorted { $0.date > $1.date }
        let recentTwo = sorted.prefix(2)
        return recentTwo.contains(where: { $0.id == photo.id })
    }

    // MARK: - Bottom Metadata

    private var bottomMetadata: some View {
        HStack {
            VStack(spacing: 2) {
                Text(currentBefore?.date.shortFormatted ?? "—")
                    .font(.caption.bold()).foregroundStyle(.white)
                if let w = currentBefore?.linkedWeight {
                    Text(w.formattedWithUnit(unit))
                        .font(.caption.bold()).foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 32)

            VStack(spacing: 2) {
                Text(currentAfter?.date.shortFormatted ?? "—")
                    .font(.caption.bold()).foregroundStyle(.white)
                if let w = currentAfter?.linkedWeight {
                    Text(w.formattedWithUnit(unit))
                        .font(.caption.bold()).foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity)

            // Weight delta
            if let bw = currentBefore?.linkedWeight, let aw = currentAfter?.linkedWeight {
                let delta = aw - bw
                Text("\(delta >= 0 ? "+" : "")\(delta.formattedWithUnit(unit))")
                    .font(.caption.bold())
                    .foregroundStyle(delta <= 0 ? BLTheme.success : BLTheme.danger)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.5))
    }

    // MARK: - Upgrade Hint

    private var upgradeHint: some View {
        HStack {
            Image(systemName: "lock.fill").font(.caption)
            Text("Upgrade to Pro to compare any photos").font(.caption)
            Spacer()
            Button("Upgrade") {
                appViewModel.showPaywall(trigger: .photoLimit)
            }
            .font(.caption.bold())
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(BLTheme.accent.opacity(0.9))
    }

    // MARK: - Actions

    private func loadImages() {
        let beforeName = currentBefore?.fileName ?? beforeEntry.fileName
        let afterName = currentAfter?.fileName ?? afterEntry.fileName

        Task.detached(priority: .userInitiated) {
            let before = PhotoStorageManager.shared.loadFullPhoto(named: beforeName)
            let after = PhotoStorageManager.shared.loadFullPhoto(named: afterName)
            await MainActor.run {
                beforeImage = before
                afterImage = after
            }
        }

        if !entitlementManager.isPro {
            upgradeHintTask?.cancel()
            upgradeHintTask = Task {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                // Max 3 times total
                let count = UserDefaults.standard.integer(forKey: "upgradeHintCount")
                guard count < 3 else { return }
                UserDefaults.standard.set(count + 1, forKey: "upgradeHintCount")
                withAnimation { showUpgradeHint = true }
            }
        }
    }

    @MainActor
    private func shareComparison() {
        guard let before = beforeImage, let after = afterImage else { return }
        let renderer = ImageRenderer(content:
            ComparisonShareView(
                before: before, after: after,
                beforeDate: currentBefore?.date.shortFormatted ?? "",
                afterDate: currentAfter?.date.shortFormatted ?? "",
                beforeWeight: currentBefore?.linkedWeight,
                afterWeight: currentAfter?.linkedWeight,
                unit: unit,
                showWatermark: !entitlementManager.isPro
            )
        )
        renderer.scale = 2.0
        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
    }
}

// MARK: - Divider Handle

private struct DividerHandle: View {
    let isDragging: Bool
    var body: some View {
        ZStack {
            Rectangle().fill(.white).frame(width: 2)
                .shadow(color: .black.opacity(0.5), radius: 4)
            Circle().fill(.white)
                .frame(width: isDragging ? 44 : 36, height: isDragging ? 44 : 36)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                .overlay {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.gray)
                }
        }
        .animation(.spring(response: 0.3), value: isDragging)
    }
}

// MARK: - Share View

private struct ComparisonShareView: View {
    let before: UIImage
    let after: UIImage
    let beforeDate: String
    let afterDate: String
    let beforeWeight: Double?
    let afterWeight: Double?
    let unit: WeightUnit
    let showWatermark: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                VStack(spacing: 4) {
                    Image(uiImage: before).resizable().scaledToFill()
                        .frame(width: 300, height: 400).clipped()
                    Text(beforeDate).font(.caption.bold()).foregroundStyle(.white)
                    if let w = beforeWeight {
                        Text(w.formattedWithUnit(unit)).font(.caption2).foregroundStyle(.white.opacity(0.7))
                    }
                }
                VStack(spacing: 4) {
                    Image(uiImage: after).resizable().scaledToFill()
                        .frame(width: 300, height: 400).clipped()
                    Text(afterDate).font(.caption.bold()).foregroundStyle(.white)
                    if let w = afterWeight {
                        Text(w.formattedWithUnit(unit)).font(.caption2).foregroundStyle(.white.opacity(0.7))
                    }
                }
            }

            // Weight delta
            if let bw = beforeWeight, let aw = afterWeight {
                let delta = aw - bw
                Text("\(delta >= 0 ? "+" : "")\(delta.formattedWithUnit(unit))")
                    .font(.caption.bold())
                    .foregroundStyle(delta <= 0 ? .green : .red)
                    .padding(.top, 6)
            }

            if showWatermark {
                Text("Made with BodyLog")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 8)
            }
        }
        .padding(8)
        .background(.black)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
