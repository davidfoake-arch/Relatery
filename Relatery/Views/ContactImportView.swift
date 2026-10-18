import SwiftUI
import SwiftData

/// The contacts the user picked, shown before anything is added: what each
/// one brings, a relationship type for each, and a box to leave anyone out.
/// Nothing is saved until the Add button.
struct ContactImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allPeople: [Person]

    let cards: [ContactCard]
    @State private var excluded: Set<ContactCard.ID> = []
    @State private var types: [ContactCard.ID: String] = [:]

    var body: some View {
        NavigationStack {
            List {
                if !newCards.isEmpty {
                    Section {
                        ForEach(newCards) { card in
                            ContactImportRow(
                                card: card,
                                isIncluded: includedBinding(for: card),
                                type: typeBinding(for: card),
                                customTypes: customTypes
                            )
                        }
                    } footer: {
                        Text("Dates come from Contacts and can be changed afterwards.")
                            .font(Theme.Fonts.footnote)
                            .foregroundStyle(Theme.mutedBrown)
                    }
                    .themedRows()
                }

                if !alreadyAdded.isEmpty {
                    Section {
                        ForEach(alreadyAdded) { card in
                            HStack(spacing: 12) {
                                AvatarView(photoData: card.photoData, initials: card.initials)
                                Text(card.displayName)
                                    .font(Theme.Fonts.personName)
                            }
                            .opacity(0.5)
                        }
                    } header: {
                        Text("Already Added").themedSectionLabel()
                    } footer: {
                        Text("These are already in Relatery, so they’ll be left as they are.")
                            .font(Theme.Fonts.footnote)
                            .foregroundStyle(Theme.mutedBrown)
                    }
                    .themedRows()
                }
            }
            .themedListBackground()
            .themedNavigationBar(title: "Add from Contacts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                addButton
            }
        }
    }

    private var addButton: some View {
        let count = selectedCards.count
        return Button(action: add) {
            Text(count == 0 ? "Add Relationships" : count == 1 ? "Add 1 Relationship" : "Add \(count) Relationships")
                .font(Theme.Fonts.bodyStrong)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.clay)
        .foregroundStyle(Theme.cream)
        .disabled(count == 0)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Which cards are which

    private var existingIdentifiers: Set<String> {
        Set(allPeople.compactMap(\.contactIdentifier))
    }

    private var newCards: [ContactCard] {
        cards.filter { !existingIdentifiers.contains($0.id) }
    }

    private var alreadyAdded: [ContactCard] {
        cards.filter { existingIdentifiers.contains($0.id) }
    }

    private var selectedCards: [ContactCard] {
        newCards.filter { !excluded.contains($0.id) }
    }

    /// Types the user has typed on other relationships, offered alongside
    /// the built-in ones.
    private var customTypes: [String] {
        Set(allPeople.map(\.relationship))
            .filter { !$0.isEmpty && !RelationshipType.presets.contains($0) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func includedBinding(for card: ContactCard) -> Binding<Bool> {
        Binding {
            !excluded.contains(card.id)
        } set: { isIncluded in
            if isIncluded { excluded.remove(card.id) } else { excluded.insert(card.id) }
        }
    }

    private func typeBinding(for card: ContactCard) -> Binding<String> {
        Binding { types[card.id] ?? "" } set: { types[card.id] = $0 }
    }

    // MARK: - Adding

    private func add() {
        for card in selectedCards {
            let person = Person(
                firstName: card.firstName,
                lastName: card.lastName,
                relationship: types[card.id] ?? "",
                photoData: card.photoData
            )
            person.contactIdentifier = card.id
            modelContext.insert(person)
            for date in card.dates {
                let keyDate = KeyDate(kind: date.kind, label: date.label, month: date.month, day: date.day, year: date.year)
                keyDate.person = person
                modelContext.insert(keyDate)
            }
        }
        dismiss()
    }
}

private struct ContactImportRow: View {
    let card: ContactCard
    @Binding var isIncluded: Bool
    @Binding var type: String
    let customTypes: [String]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // The whole left side toggles the person in or out; the type
            // menu below is its own control.
            Button {
                isIncluded.toggle()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                        .font(Theme.Fonts.cardHeading)
                        .foregroundStyle(isIncluded ? Theme.plum : Theme.stone)
                    AvatarView(photoData: card.photoData, initials: card.initials)
                        .opacity(isIncluded ? 1 : 0.5)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(card.displayName)
            .accessibilityValue(isIncluded ? "Will be added" : "Left out")
            .accessibilityAddTraits(isIncluded ? .isSelected : [])

            VStack(alignment: .leading, spacing: 4) {
                Text(card.displayName)
                    .font(Theme.Fonts.personName)
                if card.dates.isEmpty {
                    Text("No dates in Contacts")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.mutedBrown)
                } else {
                    // Not Labels: in a list row those leave a wide gap after the icon.
                    ForEach(card.dates, id: \.self) { date in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: date.kind.symbolName)
                                .frame(width: 16)
                            Text(date.summary)
                        }
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.mutedBrown)
                    }
                }
                typeMenu
                    .padding(.top, 2)
            }
            .opacity(isIncluded ? 1 : 0.5)
        }
        .padding(.vertical, 4)
    }

    private var typeMenu: some View {
        Menu {
            Picker("Type", selection: $type) {
                Text("None").tag("")
                ForEach(RelationshipType.presets, id: \.self) { Text($0).tag($0) }
                if !customTypes.isEmpty {
                    Section("Your Types") {
                        ForEach(customTypes, id: \.self) { Text($0).tag($0) }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(type.isEmpty ? "Choose Type" : type)
                Image(systemName: "chevron.up.chevron.down")
                    .font(Theme.Fonts.caption)
            }
            .font(Theme.Fonts.secondary)
            .foregroundStyle(Theme.plum)
        }
        .disabled(!isIncluded)
        .accessibilityLabel("Relationship type, \(type.isEmpty ? "none" : type)")
    }
}
