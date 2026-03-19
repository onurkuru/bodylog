import Foundation
import SwiftData

enum Pose: String, Codable, CaseIterable, Identifiable {
    case front = "Front"
    case side = "Side"
    case back = "Back"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .front: "person.fill"
        case .side: "person.fill.turn.right"
        case .back: "person.fill.turn.left"
        }
    }
}

@Model
final class PhotoEntry {
    var id: UUID
    var date: Date
    var fileName: String      // e.g. "photo_uuid.jpg" — stored in Documents/photos/
    var thumbnailName: String  // e.g. "thumb_uuid.jpg" — stored in Documents/thumbs/
    var pose: Pose
    var note: String?

    init(
        date: Date = .now,
        fileName: String,
        thumbnailName: String,
        pose: Pose,
        note: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.fileName = fileName
        self.thumbnailName = thumbnailName
        self.pose = pose
        self.note = note
    }
}
