import Foundation
import SwiftData

/// A named workspace within Pursuit: its own applications, generated content,
/// and resume/template folder. Lets more than one job seeker (or one person
/// running more than one search) share the same installed app without their
/// data mixing.
@Model
final class Profile {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}
