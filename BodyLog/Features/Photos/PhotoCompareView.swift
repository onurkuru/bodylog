import SwiftUI
import SwiftData

struct PhotoCompareView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(EntitlementManager.self) private var entitlementManager
    @Environment(\.dismiss) private var dismiss

    let beforeEntry: PhotoEntry
    let afterEntry: PhotoEntry

    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    @State private var dividerPosition: CGFloat = 0.5 // 0.0 to 1.0
    @State private var isDragging = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var showUpgradeHint = false
    @State private var upgradeHintTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar

                // Photo comparison area
                GeometryReader { geometry in
                    ZStack {
                        if let before = beforeImage, let after = afterImage {
                            comparisonView(before: before, after: after, size: geometry.size)
                        } else {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }

                // Bottom metadata
                bottomMetadata

                // Inline upgrade hint (free users)
                if showUpgradeHint && !entitlementManager.isPro {
                    upgradeHint
                }
            }
        }
        .onAppear { loadImages() }
        .onDisappear { upgradeHintTask?.cancel() }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
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
                .font(.headline)
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

    // MARK: - Comparison View (Hero Component)

    @ViewBuilder
    private func comparisonView(before: UIImage, after: UIImage, size: CGSize) -> some View {
        let dividerX = size.width * dividerPosition

        ZStack {
            // AFTER image (full, behind)
            Image(uiImage: after)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()

            // BEFORE image (clipped to left of divider)
            Image(uiImage: before)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
                .mask(
                    HStack(spacing: 0) {
                        Rectangle()
                            .frame(width: dividerX)
                        Spacer(minLength: 0)
                    }
                )

            // Labels
            VStack {
                HStack {
                    Text("BEFORE")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(.leading, 12)
                        .opacity(dividerPosition > 0.15 ? 1 : 0)

                    Spacer()

                    Text("AFTER")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(.trailing, 12)
                        .opacity(dividerPosition < 0.85 ? 1 : 0)
                }
                .padding(.top, 12)

                Spacer()
            }

            // Divider line + handle
            DividerHandle(isDragging: isDragging)
                .position(x: dividerX, y: size.height / 2)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let newPosition = value.location.x / size.width
                            dividerPosition = min(max(newPosition, 0.02), 0.98)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
        }
        .contentShape(Rectangle())
    }

    // MARK: - Bottom Metadata

    private var bottomMetadata: some View {
        HStack {
            VStack(spacing: 2) {
                Text(beforeEntry.date.shortFormatted)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                if let w = beforeEntry.linkedWeight {
                    Text(String(format: "%.1f kg", w))
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.8))
                }
                Text(beforeEntry.pose.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(width: 1, height: 32)

            VStack(spacing: 2) {
                Text(afterEntry.date.shortFormatted)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                if let w = afterEntry.linkedWeight {
                    Text(String(format: "%.1f kg", w))
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.8))
                }
                Text(afterEntry.pose.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .background(.black.opacity(0.5))
    }

    // MARK: - Upgrade Hint

    private var upgradeHint: some View {
        HStack {
            Image(systemName: "lock.fill")
                .font(.caption)
            Text("Upgrade to Pro to compare any photos")
                .font(.caption)
            Spacer()
            Button("Upgrade") {
                appViewModel.showPaywall(trigger: .photoLimit)
            }
            .font(.caption.bold())
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(Color.accentColor.opacity(0.9))
    }

    // MARK: - Actions

    private func loadImages() {
        Task.detached(priority: .userInitiated) {
            let before = PhotoStorageManager.shared.loadFullPhoto(named: beforeEntry.fileName)
            let after = PhotoStorageManager.shared.loadFullPhoto(named: afterEntry.fileName)
            await MainActor.run {
                beforeImage = before
                afterImage = after
            }
        }

        // Show upgrade hint for free users after delay
        if !entitlementManager.isPro {
            upgradeHintTask = Task {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                withAnimation { showUpgradeHint = true }
            }
        }
    }

    @MainActor
    private func shareComparison() {
        guard let before = beforeImage, let after = afterImage else { return }

        let renderer = ImageRenderer(content:
            ComparisonShareView(
                before: before,
                after: after,
                beforeDate: beforeEntry.date.shortFormatted,
                afterDate: afterEntry.date.shortFormatted,
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
            // Vertical line
            Rectangle()
                .fill(.white)
                .frame(width: 2)
                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 0)

            // Handle circle
            Circle()
                .fill(.white)
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

// MARK: - Comparison Share View (for ImageRenderer)

private struct ComparisonShareView: View {
    let before: UIImage
    let after: UIImage
    let beforeDate: String
    let afterDate: String
    let showWatermark: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                VStack(spacing: 4) {
                    Image(uiImage: before)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 300, height: 400)
                        .clipped()
                    Text(beforeDate)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }

                VStack(spacing: 4) {
                    Image(uiImage: after)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 300, height: 400)
                        .clipped()
                    Text(afterDate)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
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

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
