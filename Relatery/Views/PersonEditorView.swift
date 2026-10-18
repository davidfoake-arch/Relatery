import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

/// Creates a new relationship, or edits an existing one. Changes only apply on Save.
struct PersonEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    private let person: Person?
    /// Everyone, so custom types used elsewhere can be offered again.
    @Query private var allPeople: [Person]

    /// The picker's value for "Custom…", which reveals a text field. It can't
    /// collide with a real type: those are trimmed, and this starts with a space.
    private static let customTypeTag = " custom"

    @State private var firstName: String
    @State private var lastName: String
    /// A relationship type, `customTypeTag`, or empty for none.
    @State private var typeChoice: String
    @State private var customType = ""
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var photoError: String?
    @State private var keyDates: [KeyDateDraft]
    /// The contact this was last filled from, if any.
    @State private var contactIdentifier: String?
    /// Set when the picked contact is already another relationship.
    @State private var duplicateContactName: String?

    init(person: Person? = nil) {
        self.person = person
        _firstName = State(initialValue: person?.firstName ?? "")
        _lastName = State(initialValue: person?.lastName ?? "")
        _typeChoice = State(initialValue: person?.relationship ?? "")
        _photoData = State(initialValue: person?.photoData)
        _keyDates = State(initialValue: (person?.upcomingKeyDates ?? []).map { KeyDateDraft($0) })
        _contactIdentifier = State(initialValue: person?.contactIdentifier)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        AvatarView(photoData: photoData, initials: draftInitials, size: 112)
                            .opacity(isLoadingPhoto ? 0.4 : 1)
                            .overlay {
                                if isLoadingPhoto {
                                    ProgressView()
                                }
                            }
                        HStack(spacing: 20) {
                            // `.current` hands over the photo as stored. The default asks
                            // Photos to convert it first, which is one more step that can fail.
                            PhotosPicker(
                                photoData == nil ? "Add Photo" : "Change Photo",
                                selection: $photoItem,
                                matching: .images,
                                preferredItemEncoding: .current
                            )
                            .foregroundStyle(Theme.accent)
                            if photoData != nil {
                                Button("Remove", role: .destructive) {
                                    photoData = nil
                                    photoItem = nil
                                }
                                .foregroundStyle(Theme.berry)
                            }
                        }
                        .font(Theme.Fonts.secondary)
                        .buttonStyle(.borderless)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("First name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last name", text: $lastName)
                        .textContentType(.familyName)
                    Button(action: fillFromContacts) {
                        Label("Fill from Contacts", systemImage: "person.crop.circle")
                            .foregroundStyle(Theme.accent)
                    }
                }
                .textInputAutocapitalization(.words)
                .themedRows()

                Section {
                    Picker("Type", selection: $typeChoice) {
                        Text("None").tag("")
                        ForEach(RelationshipType.presets, id: \.self) { type in
                            Text(type).tag(type)
                        }
                        if !customTypes.isEmpty {
                            Section("Your Types") {
                                ForEach(customTypes, id: \.self) { type in
                                    Text(type).tag(type)
                                }
                            }
                        }
                        Section {
                            Text("Custom…").tag(Self.customTypeTag)
                        }
                    }
                    if typeChoice == Self.customTypeTag {
                        TextField("Custom type (e.g. Godmother)", text: $customType)
                            .textInputAutocapitalization(.words)
                    }
                } header: {
                    Text("Relationship").themedSectionLabel()
                }
                .themedRows()

                ForEach($keyDates) { $keyDate in
                    Section {
                        KeyDateEditor(draft: $keyDate, availableKinds: availableKinds(keeping: keyDate.kind))
                        Button("Remove Date", role: .destructive) {
                            keyDates.removeAll { $0.id == keyDate.id }
                        }
                        .foregroundStyle(Theme.berry)
                    }
                    .themedRows()
                }

                Section {
                    Menu {
                        ForEach(KeyDateKind.allCases) { kind in
                            Button {
                                keyDates.append(KeyDateDraft(kind: kind))
                            } label: {
                                KeyDateKindMenuLabel(kind: kind)
                            }
                            .disabled(!availableKinds(keeping: nil).contains(kind))
                        }
                    } label: {
                        Label("Add Date", systemImage: "plus.circle.fill")
                            .foregroundStyle(Theme.accent)
                    }
                }
                .themedRows()
            }
            // Pickers and the date picker take their colour from the tint.
            // Set here, on the form, so it doesn't reach the navigation bar.
            .tint(Theme.accent)
            .themedListBackground()
            .scrollDismissesKeyboard(.interactively)
            .themedNavigationBar(title: person == nil ? "New Relationship" : "Edit Relationship")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!hasName)
                }
            }
            .onChange(of: photoItem) {
                guard let photoItem else { return }
                Task { await loadPhoto(from: photoItem) }
            }
            .alert(
                "Already Added",
                isPresented: Binding(get: { duplicateContactName != nil }, set: { if !$0 { duplicateContactName = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\(duplicateContactName ?? "That contact") is already in Relatery.")
            }
            .alert("Couldn’t Add Photo", isPresented: Binding(get: { photoError != nil }, set: { if !$0 { photoError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(photoError ?? "")
            }
        }
    }

    private var hasName: Bool {
        !(firstName + lastName).trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Types the user has typed before, on this relationship or any other.
    private var customTypes: [String] {
        var types = Set(allPeople.map(\.relationship))
        if typeChoice != Self.customTypeTag {
            types.insert(typeChoice)
        }
        return types
            .filter { !$0.isEmpty && !RelationshipType.presets.contains($0) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var chosenType: String {
        typeChoice == Self.customTypeTag ? customType.trimmingCharacters(in: .whitespaces) : typeChoice
    }

    /// The kinds a date can still be: every kind not already used by another
    /// date, plus `current`, the kind of the date being edited.
    private func availableKinds(keeping current: KeyDateKind?) -> [KeyDateKind] {
        KeyDateKind.allCases.filter { kind in
            kind.allowsMultiple || kind == current || !keyDates.contains { $0.kind == kind }
        }
    }

    private var draftInitials: String {
        String([firstName, lastName].compactMap { $0.trimmingCharacters(in: .whitespaces).first }).uppercased()
    }

    private func save() {
        let target = person ?? Person()
        if person == nil {
            modelContext.insert(target)
        }
        target.firstName = firstName.trimmingCharacters(in: .whitespaces)
        target.lastName = lastName.trimmingCharacters(in: .whitespaces)
        target.relationship = chosenType
        target.photoData = photoData
        target.contactIdentifier = contactIdentifier

        // Reconcile key dates so existing ones keep their identity.
        let kept = Set(keyDates.compactMap { $0.source?.persistentModelID })
        for existing in target.keyDates where !kept.contains(existing.persistentModelID) {
            modelContext.delete(existing)
        }
        for draft in keyDates {
            if let source = draft.source {
                draft.apply(to: source)
            } else {
                let keyDate = KeyDate(kind: draft.kind, month: draft.month, day: draft.day)
                draft.apply(to: keyDate)
                keyDate.person = target
                modelContext.insert(keyDate)
            }
        }
        dismiss()
    }

    /// Lets the user pick one contact and fills the form from it: the name,
    /// the photo if it has one, and any dates this relationship doesn't have
    /// yet. Nothing is saved until Save, as with any other edit.
    private func fillFromContacts() {
        Task {
            guard let contact = await ContactPicker.pickContact() else { return }
            let card = ContactCard(contact)
            if let other = allPeople.first(where: {
                $0.contactIdentifier == card.id && $0.persistentModelID != person?.persistentModelID
            }) {
                duplicateContactName = other.displayName
                return
            }
            if !(card.firstName + card.lastName).isEmpty {
                firstName = card.firstName
                lastName = card.lastName
            }
            if let photo = card.photoData {
                photoData = photo
                photoItem = nil
            }
            for date in card.dates where !hasDate(like: date) {
                keyDates.append(KeyDateDraft(date))
            }
            contactIdentifier = card.id
        }
    }

    /// Whether the form already has this date: the same kind, or for custom
    /// days, the same name and day.
    private func hasDate(like date: ContactCard.ImportedDate) -> Bool {
        keyDates.contains { draft in
            guard draft.kind == date.kind else { return false }
            guard date.kind.allowsMultiple else { return true }
            return draft.label == date.label && draft.month == date.month && draft.day == date.day
        }
    }

    /// Fetches the picked photo and keeps a small copy. A photo stored in
    /// iCloud has to download first, so this can take a moment or fail; either
    /// way the user is told, rather than nothing appearing to happen.
    private func loadPhoto(from item: PhotosPickerItem) async {
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        do {
            guard let picked = try await item.loadTransferable(type: PickedPhoto.self) else {
                photoError = "Photos didn’t provide that picture. If it’s stored in iCloud, check your connection and try again."
                return
            }
            guard let small = ProfilePhoto.downscaled(picked.data) else {
                photoError = "That picture is in a format Relatery can’t read."
                return
            }
            photoData = small
        } catch {
            photoError = "\(error.localizedDescription)\n\nIf the picture is stored in iCloud, check your connection and try again."
        }
    }
}

/// The picked photo's bytes, whatever image format it is stored in.
private struct PickedPhoto: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { PickedPhoto(data: $0) }
    }
}

struct KeyDateDraft: Identifiable {
    let id = UUID()
    var source: KeyDate?
    var kind: KeyDateKind
    var label = ""
    var month: Int
    var day: Int
    var year: Int
    var includesYear: Bool

    init(kind: KeyDateKind) {
        let today = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        self.kind = kind
        month = today.month ?? 1
        day = today.day ?? 1
        year = today.year ?? 2000
        includesYear = false
    }

    init(_ date: ContactCard.ImportedDate) {
        kind = date.kind
        label = date.label
        month = date.month
        day = date.day
        year = date.year ?? Calendar.current.component(.year, from: .now)
        includesYear = date.year != nil
    }

    init(_ keyDate: KeyDate) {
        source = keyDate
        kind = keyDate.kind
        label = keyDate.label
        month = keyDate.month
        day = keyDate.day
        year = keyDate.year ?? Calendar.current.component(.year, from: .now)
        includesYear = keyDate.year != nil
    }

    /// Full date, used by the date picker when the year is known.
    var date: Date {
        get { Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now }
        set {
            let components = Calendar.current.dateComponents([.year, .month, .day], from: newValue)
            year = components.year ?? year
            month = components.month ?? month
            day = components.day ?? day
        }
    }

    /// Days available in the selected month; without a year, February allows the 29th.
    var daysInMonth: Int {
        let components = DateComponents(year: includesYear ? year : 2000, month: month, day: 1)
        guard let monthStart = Calendar.current.date(from: components),
              let range = Calendar.current.range(of: .day, in: .month, for: monthStart) else { return 31 }
        return range.count
    }

    func apply(to keyDate: KeyDate) {
        keyDate.kind = kind
        keyDate.label = kind == .custom ? label.trimmingCharacters(in: .whitespaces) : ""
        keyDate.month = month
        keyDate.day = min(day, daysInMonth)
        keyDate.year = includesYear ? year : nil
    }
}

/// A date kind as the label of a menu `Button`. The views have to be loose,
/// not wrapped in a `Label`, for the second `Text` to become the item's
/// subtitle; a Picker drops the subtitle whatever the form.
private struct KeyDateKindMenuLabel: View {
    let kind: KeyDateKind

    var body: some View {
        Image(systemName: kind.symbolName)
        Text(kind.menuTitle.title)
        if let subtitle = kind.menuTitle.subtitle {
            Text(subtitle)
        }
    }
}

private struct KeyDateEditor: View {
    @Binding var draft: KeyDateDraft
    let availableKinds: [KeyDateKind]

    var body: some View {
        // A menu rather than a Picker: picker menus drop subtitles, which
        // `KeyDateKindMenuLabel` needs. Drawn to look like a picker row.
        Menu {
            ForEach(availableKinds) { kind in
                Button {
                    draft.kind = kind
                } label: {
                    KeyDateKindMenuLabel(kind: kind)
                }
                .disabled(kind == draft.kind)
            }
        } label: {
            HStack {
                Text("Type")
                    .foregroundStyle(Theme.darkBrown)
                Spacer()
                // Not a Label: in a list row that adds a wide gap after the
                // icon and moves the row separator to start under the title.
                HStack(spacing: 6) {
                    Image(systemName: draft.kind.symbolName)
                    Text(draft.kind.title)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(Theme.Fonts.footnote)
                }
                .foregroundStyle(Theme.accent)
            }
        }
        .accessibilityLabel("Type, \(draft.kind.title)")
        if draft.kind == .custom {
            TextField("Name (e.g. Graduation)", text: $draft.label)
        }
        if draft.includesYear {
            // A date of birth can't be in the future; other dates can (an
            // upcoming wedding, say).
            DatePicker(
                isBirthday ? "Date of Birth" : "Date",
                selection: $draft.date,
                in: Date.distantPast...(isBirthday ? Date.now : Date.distantFuture),
                displayedComponents: .date
            )
        } else {
            HStack {
                Text("Date")
                Spacer()
                Picker("Month", selection: $draft.month) {
                    ForEach(1...12, id: \.self) { month in
                        Text(Calendar.current.monthSymbols[month - 1]).tag(month)
                    }
                }
                Picker("Day", selection: $draft.day) {
                    ForEach(1...draft.daysInMonth, id: \.self) { day in
                        Text("\(day)").tag(day)
                    }
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .onChange(of: draft.month) {
                draft.day = min(draft.day, draft.daysInMonth)
            }
        }
        Toggle(isBirthday ? "Include Year of Birth" : "Include Year", isOn: $draft.includesYear)
            .tint(Theme.accent)
            .onChange(of: draft.includesYear) {
                startBirthYearAtAdult()
                draft.day = min(draft.day, draft.daysInMonth)
                keepBirthdayInPast()
            }
            .onChange(of: draft.kind) {
                keepBirthdayInPast()
            }
    }

    private var isBirthday: Bool { draft.kind == .birthday }

    /// A birthday with no year yet starts out on this year, which would mean
    /// scrolling back decades to reach a birth year. Start 30 years back
    /// instead, so most are a short scroll either way.
    private func startBirthYearAtAdult() {
        let thisYear = Calendar.current.component(.year, from: .now)
        if isBirthday && draft.includesYear && draft.year >= thisYear {
            draft.year = thisYear - 30
        }
    }

    /// The year starts out as this year, so a birthday later in the year
    /// would be a date of birth in the future. Step back to last year.
    private func keepBirthdayInPast() {
        if isBirthday && draft.includesYear && draft.date > .now {
            draft.year -= 1
        }
    }
}

#Preview {
    PersonEditorView()
        .modelContainer(for: Person.self, inMemory: true)
}
