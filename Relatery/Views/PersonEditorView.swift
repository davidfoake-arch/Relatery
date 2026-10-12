import SwiftUI
import SwiftData
import PhotosUI

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
    @State private var notes: String
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var keyDates: [KeyDateDraft]

    init(person: Person? = nil) {
        self.person = person
        _firstName = State(initialValue: person?.firstName ?? "")
        _lastName = State(initialValue: person?.lastName ?? "")
        _typeChoice = State(initialValue: person?.relationship ?? "")
        _notes = State(initialValue: person?.notes ?? "")
        _photoData = State(initialValue: person?.photoData)
        _keyDates = State(initialValue: (person?.upcomingKeyDates ?? []).map { KeyDateDraft($0) })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        AvatarView(photoData: photoData, initials: draftInitials, size: 112)
                        HStack(spacing: 20) {
                            PhotosPicker(photoData == nil ? "Add Photo" : "Change Photo", selection: $photoItem, matching: .images)
                                .foregroundStyle(Theme.plum)
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
                            Button(kind.title, systemImage: kind.symbolName) {
                                keyDates.append(KeyDateDraft(kind: kind))
                            }
                            .disabled(!availableKinds(keeping: nil).contains(kind))
                        }
                    } label: {
                        Label("Add Date", systemImage: "plus.circle.fill")
                            .foregroundStyle(Theme.plum)
                    }
                }
                .themedRows()

                Section {
                    TextField("Gift ideas, favorite things, how you met…", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("Notes").themedSectionLabel()
                }
                .themedRows()
            }
            // Pickers and the date picker take their colour from the tint.
            // Set here, on the form, so it doesn't reach the navigation bar.
            .tint(Theme.plum)
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
                Task {
                    if let data = try? await photoItem.loadTransferable(type: Data.self) {
                        photoData = Self.downscaled(data)
                    }
                }
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
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        target.photoData = photoData

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

    /// Profile photos are only shown small, so keep the stored image light.
    private static func downscaled(_ data: Data, maxDimension: CGFloat = 600) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return image.preparingThumbnail(of: size)?.jpegData(compressionQuality: 0.8) ?? data
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

private struct KeyDateEditor: View {
    @Binding var draft: KeyDateDraft
    let availableKinds: [KeyDateKind]

    var body: some View {
        Picker("Type", selection: $draft.kind) {
            ForEach(availableKinds) { kind in
                Label(kind.title, systemImage: kind.symbolName).tag(kind)
            }
        }
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
            .tint(Theme.plum)
            .onChange(of: draft.includesYear) {
                draft.day = min(draft.day, draft.daysInMonth)
                keepBirthdayInPast()
            }
            .onChange(of: draft.kind) {
                keepBirthdayInPast()
            }
    }

    private var isBirthday: Bool { draft.kind == .birthday }

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
