import SwiftUI
import PhotosUI
import SwiftData

struct PhotoCaptureSheet: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]

    @State private var selectedPose: Pose = .front
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedImage: UIImage?
    @State private var note: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Pose Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pose")
                        .font(.headline)

                    Picker("Pose", selection: $selectedPose) {
                        ForEach(Pose.allCases) { pose in
                            Label(pose.rawValue, systemImage: pose.systemImage)
                                .tag(pose)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 16)

                // Image Preview or Source Selection
                if let image = selectedImage {
                    imagePreview(image)
                } else {
                    sourceSelection
                }

                Spacer()

                // Save Button (only when image selected)
                if selectedImage != nil {
                    VStack(spacing: 12) {
                        TextField("Add a note (optional)", text: $note)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 16)

                        Button(action: save) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Save Photo")
                                }
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 24)
                        .disabled(isSaving)
                    }
                    .padding(.bottom, 16)
                }
            }
            .padding(.top, 16)
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView(image: $selectedImage)
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: Binding(
                    get: { nil as PhotosPickerItem? },
                    set: { item in
                        if let item {
                            loadImage(from: item)
                        }
                    }
                ),
                matching: .images
            )
        }
    }

    // MARK: - Source Selection

    private var sourceSelection: some View {
        HStack(spacing: 16) {
            SourceButton(
                icon: "camera.fill",
                title: "Camera",
                action: { showCamera = true }
            )

            SourceButton(
                icon: "photo.on.rectangle",
                title: "Library",
                action: { showPhotoPicker = true }
            )
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Image Preview

    @ViewBuilder
    private func imagePreview(_ image: UIImage) -> some View {
        VStack(spacing: 8) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 350)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)

            Button {
                selectedImage = nil
            } label: {
                Label("Retake", systemImage: "arrow.counterclockwise")
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Load & Save

    private func loadImage(from item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = image
                }
            }
        }
    }

    private func save() {
        guard let image = selectedImage else { return }
        isSaving = true

        let capturedPose = selectedPose
        let capturedNote = note.isEmpty ? nil : note
        // Find today's weight to link with this photo
        let todayWeight = weightEntries.first(where: { $0.date.isToday })?.weight
            ?? weightEntries.first?.weight // fallback to most recent

        Task.detached(priority: .userInitiated) {
            guard let result = PhotoStorageManager.shared.savePhoto(image) else {
                await MainActor.run { isSaving = false }
                return
            }

            await MainActor.run {
                let entry = PhotoEntry(
                    date: .now,
                    fileName: result.photoName,
                    thumbnailName: result.thumbName,
                    pose: capturedPose,
                    linkedWeight: todayWeight,
                    note: capturedNote
                )
                modelContext.insert(entry)
                isSaving = false

                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                dismiss()
            }
        }
    }
}

// MARK: - Source Button

private struct SourceButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                Text(title)
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Camera View (UIImagePickerController wrapper)

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
