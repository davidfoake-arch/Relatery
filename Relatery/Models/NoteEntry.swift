import Foundation
import SwiftData

/// One dated note about a relationship: something they mentioned, news,
/// how a visit went.
@Model
final class NoteEntry {
    var text: String = ""
    var date: Date = Date.now
    var person: Person?

    init(text: String, date: Date = .now) {
        self.text = text
        self.date = date
    }
}

/// Relationships used to have a single free-text notes field. Each one
/// becomes a first dated note, once, so nothing is lost.
enum LegacyNotes {
    static func migrate(in context: ModelContext) {
        let descriptor = FetchDescriptor<Person>(predicate: #Predicate { !$0.notes.isEmpty })
        guard let people = try? context.fetch(descriptor), !people.isEmpty else { return }
        for person in people {
            let note = NoteEntry(text: person.notes, date: person.createdAt)
            note.person = person
            context.insert(note)
            person.notes = ""
        }
        try? context.save()
    }
}
