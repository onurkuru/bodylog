import SwiftUI
import SwiftData

struct PhotoDetailView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsArray: [UserSettings]

    let entry: PhotoEntry

    private var unit: WeightUnit { settingsArray.first?.unitPreference ?? .kg }
    @State private var fullImage: UIImage?
    @State private var showDeleteAlert = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Spacer()

                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                // Photo
                if let image = fullImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 8)
                } else {
                    ProgressView()
                        .tint(.white)
                }

                Spacer()

                // Metadata
                VStack(spacing: 8) {
                    Text(entry.date.mediumFormatted)
                        .font(.headline)
                        .foregroundStyle(.white)

                    HStack(spacing: 12) {
                        Text(entry.pose.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))

                        if let weight = entry.linkedWeight {
                            Text("•")
                                .foregroundStyle(.white.opacity(0.4))
                            Text(weight.formattedWithUnit(unit))
                                .font(.subheadline.bold())
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }

                    if let note = entry.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .alert("Delete this photo?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deletePhoto()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .onAppear {
            loadFullImage()
        }
    }

    private func loadFullImage() {
        Task.detached(priority: .userInitiated) {
            let image = PhotoStorageManager.shared.loadFullPhoto(named: entry.fileName)
            await MainActor.run {
                fullImage = image
            }
        }
    }

    private func deletePhoto() {
        PhotoStorageManager.shared.deletePhoto(
            photoName: entry.fileName,
            thumbName: entry.thumbnailName
        )
        modelContext.delete(entry)
        dismiss()
    }
}
