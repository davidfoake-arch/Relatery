import SwiftUI
import SwiftData

/// Adds or edits one dated note. Changes only apply on Save.
struct NoteEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let person: Person
    private let note: NoteEntry?

    @State private var text: String
    @State private var date: Date
    @State private var isConfirmingDelete = false
    @FocusState private var isTextFocused: Bool

    init(person: Person, note: NoteEntry? = nil) {
        self.person = person
        self.note = note
        _text = State(initialValue: note?.text ?? "")
        _date = State(initialValue: note?.date ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Something they mentioned, news, how it went…", text: $text, axis: .vertical)
                        .lineLimit(4...12)
                        .focused($isTextFocused)
                    DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                }
                .themedRows()

                if note != nil {
                    Section {
                        Button("Delete Note", role: .destructive) {
                            isConfirmingDelete = true
                        }
                        .foregroundStyle(Theme.berry)
                        .confirmationDialog("Delete this note?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                            Button("Delete", role: .destructive, action: delete)
                        }
                    }
                    .themedRows()
                }
            }
            .tint(Theme.plum)
            .themedListBackground()
            .themedNavigationBar(title: note == nil ? "New Note" : "Edit Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedText.isEmpty)
                }
            }
            .onAppear {
                if note == nil { isTextFocused = true }
            }
        }
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        let target = note ?? NoteEntry(text: trimmedText)
        if note == nil {
            target.person = person
            modelContext.insert(target)
        }
        target.text = trimmedText
        target.date = date
        dismiss()
    }

    private func delete() {
        if let note {
            modelContext.delete(note)
        }
        dismiss()
    }
}
