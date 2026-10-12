import Foundation
import SwiftData

@Model
final class Person {
    var firstName: String = ""
    var lastName: String = ""
    /// Free-form description of who they are to you, e.g. "Sister" or "College friend".
    var relationship: String = ""
    var notes: String = ""
    @Attribute(.externalStorage) var photoData: Data?
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \KeyDate.person)
    var keyDates: [KeyDate] = []

    init(firstName: String = "", lastName: String = "", relationship: String = "", notes: String = "", photoData: Data? = nil) {
        self.firstName = firstName
        self.lastName = lastName
        self.relationship = relationship
        self.notes = notes
        self.photoData = photoData
    }

    var displayName: String {
        let name = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? "No Name" : name
    }

    var initials: String {
        let letters = [firstName, lastName].compactMap { $0.trimmingCharacters(in: .whitespaces).first }
        return String(letters).uppercased()
    }

    /// Key dates ordered by which one comes up next.
    var upcomingKeyDates: [KeyDate] {
        keyDates.sorted { $0.nextOccurrence() < $1.nextOccurrence() }
    }
}
