import SwiftUI
import SwiftData

struct PeopleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Person.firstName), SortDescriptor(\Person.lastName)]) private var people: [Person]
    @State private var searchText = ""
    @State private var isAddingPerson = false
    @State private var contactImport: ContactImport?

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections, id: \.letter) { section in
                    Section {
                        ForEach(section.people) { person in
                            NavigationLink(value: person) {
                                PersonRow(person: person)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                modelContext.delete(section.people[index])
                            }
                        }
                    } header: {
                        Text(section.letter).themedSectionLabel()
                    }
                    .themedRows()
                }
            }
            .themedListBackground()
            .overlay {
                if people.isEmpty {
                    ContentUnavailableView {
                        Label("No Relationships Yet", systemImage: "person.2")
                            .font(Theme.Fonts.cardHeading)
                            .foregroundStyle(Theme.darkBrown)
                    } description: {
                        Text("Add the people who matter to you and keep track of their special days.")
                            .font(Theme.Fonts.secondary)
                            .foregroundStyle(Theme.mutedBrown)
                    } actions: {
                        Button("Add Relationship") { isAddingPerson = true }
                            .font(Theme.Fonts.bodyStrong)
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.clayFill)
                            .foregroundStyle(Theme.onPlum)
                        Button("Add from Contacts", action: pickContacts)
                            .font(Theme.Fonts.bodyStrong)
                            .foregroundStyle(Theme.accent)
                    }
                } else if sections.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .themedNavigationBar(title: "Relationships")
            .navigationDestination(for: Person.self) { person in
                PersonDetailView(person: person)
            }
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu("Add Relationship", systemImage: "plus") {
                        Button("New Relationship", systemImage: "square.and.pencil") { isAddingPerson = true }
                        Button("Add from Contacts", systemImage: "person.crop.circle.badge.plus", action: pickContacts)
                    }
                }
            }
            .sheet(isPresented: $isAddingPerson) {
                PersonEditorView()
            }
            .sheet(item: $contactImport) { contactImport in
                ContactImportView(cards: contactImport.cards)
            }
        }
    }

    /// Opens Apple's contact picker, then the review screen for whoever was
    /// picked. Picking nobody, or cancelling, does nothing.
    private func pickContacts() {
        Task {
            let contacts = await ContactPicker.pickContacts()
            guard !contacts.isEmpty else { return }
            contactImport = ContactImport(cards: contacts.map(ContactCard.init))
        }
    }

    private var sections: [(letter: String, people: [Person])] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let filtered = query.isEmpty ? people : people.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
                || $0.relationship.localizedCaseInsensitiveContains(query)
        }
        let grouped = Dictionary(grouping: filtered) { person -> String in
            guard let first = person.displayName.first, first.isLetter else { return "#" }
            return String(first).uppercased()
        }
        return grouped
            .map { (letter: $0.key, people: $0.value.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }) }
            .sorted { lhs, rhs in
                // Keep the "#" bucket at the bottom, like Contacts.
                if lhs.letter == "#" { return false }
                if rhs.letter == "#" { return true }
                return lhs.letter < rhs.letter
            }
    }
}

/// One round of picking from Contacts, for the review sheet.
private struct ContactImport: Identifiable {
    let id = UUID()
    let cards: [ContactCard]
}

private struct PersonRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(photoData: person.photoData, initials: person.initials)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.displayName)
                    .font(Theme.Fonts.personName)
                if !person.relationship.isEmpty {
                    Text(person.relationship)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.mutedBrown)
                }
            }
            Spacer()
            if let next = person.upcomingKeyDates.first, next.daysUntilNext() <= 30 {
                Label(next.countdownText, systemImage: next.kind.symbolName)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(next.daysUntilNext() == 0 ? Theme.clay : Theme.accent)
            }
        }
    }
}

#Preview {
    PeopleListView()
        .modelContainer(for: Person.self, inMemory: true)
}
