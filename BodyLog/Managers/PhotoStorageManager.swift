import UIKit

/// Two-tier photo storage: full-res in Documents/photos/, thumbnails in Documents/thumbs/
/// SwiftData only stores file names — no binary data in the database.
final class PhotoStorageManager {
    static let shared = PhotoStorageManager()

    private let fileManager = FileManager.default

    private lazy var photosDirectory: URL = {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("photos", isDirectory: true)
        ensureDirectory(dir)
        return dir
    }()

    private lazy var thumbsDirectory: URL = {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("thumbs", isDirectory: true)
        ensureDirectory(dir)
        return dir
    }()

    private init() {}

    // MARK: - Save

    /// Saves a photo at two sizes. Returns (photoFileName, thumbnailFileName).
    func savePhoto(_ image: UIImage) -> (photoName: String, thumbName: String)? {
        let id = UUID().uuidString
        let photoName = "photo_\(id).jpg"
        let thumbName = "thumb_\(id).jpg"

        // Full: max 1200px long edge, JPEG 0.85
        guard let fullImage = resized(image, maxDimension: 1200),
              let fullData = fullImage.jpegData(compressionQuality: 0.85) else {
            return nil
        }

        // Thumbnail: max 300px long edge, JPEG 0.7
        guard let thumbImage = resized(image, maxDimension: 300),
              let thumbData = thumbImage.jpegData(compressionQuality: 0.7) else {
            return nil
        }

        let photoURL = photosDirectory.appendingPathComponent(photoName)
        let thumbURL = thumbsDirectory.appendingPathComponent(thumbName)

        do {
            try fullData.write(to: photoURL)
            try thumbData.write(to: thumbURL)
            return (photoName, thumbName)
        } catch {
            // Cleanup on partial failure
            try? fileManager.removeItem(at: photoURL)
            try? fileManager.removeItem(at: thumbURL)
            return nil
        }
    }

    // MARK: - Load

    func loadFullPhoto(named fileName: String) -> UIImage? {
        let url = photosDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func loadThumbnail(named fileName: String) -> UIImage? {
        let url = thumbsDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Delete

    func deletePhoto(photoName: String, thumbName: String) {
        let photoURL = photosDirectory.appendingPathComponent(photoName)
        let thumbURL = thumbsDirectory.appendingPathComponent(thumbName)
        try? fileManager.removeItem(at: photoURL)
        try? fileManager.removeItem(at: thumbURL)
    }

    // MARK: - Storage Info

    var totalPhotoSizeBytes: Int64 {
        directorySize(photosDirectory) + directorySize(thumbsDirectory)
    }

    var totalPhotoSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalPhotoSizeBytes, countStyle: .file)
    }

    // MARK: - Private Helpers

    private func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height)

        // Don't upscale
        guard ratio < 1.0 else { return image }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func ensureDirectory(_ url: URL) {
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
