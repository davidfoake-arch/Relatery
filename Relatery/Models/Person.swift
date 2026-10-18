import Foundation
import SwiftData

/// The built-in relationship types offered in the editor. A relationship can
/// also have a type the user typed themselves; both are stored as plain text
/// in `Person.relationship`.
enum RelationshipType {
    static let presets = ["Spouse", "Partner", "Friend", "Parent", "Child", "Sibling", "Family", "Colleague", "Pet"]
}

/// One entry in the app. The interface calls these "Relationships".
@Model
final class Person {
    var firstName: String = ""
    var lastName: String = ""
    /// The type of relationship: one of `RelationshipType.presets`, a custom
    /// type the user typed, or empty for none.
    var relationship: String = ""
    var notes: String = ""
    @Attribute(.externalStorage) var photoData: Data?
    var createdAt: Date = Date.now
    /// The Contacts entry this was filled from, if any (`CNContact.identifier`).
    /// Only used to spot a contact that's already been added; nothing is kept
    /// in sync.
    var contactIdentifier: String?
    /// This relationship's own reminders, replacing the everyday ones (see
    /// `reminderPlan`). Nil to use the everyday ones.
    var reminderPlanData: Data?

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

    var reminderPlan: ReminderPlan? {
        get { ReminderPlan.decode(reminderPlanData) }
        set { reminderPlanData = ReminderPlan.encode(newValue) }
    }

    /// Key dates ordered by which one comes up next.
    var upcomingKeyDates: [KeyDate] {
        keyDates.sorted { $0.nextOccurrence() < $1.nextOccurrence() }
    }
}
