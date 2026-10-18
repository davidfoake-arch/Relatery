import SwiftUI
import SwiftData

struct PersonDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let person: Person
    @State private var isEditing = false
    @State private var isConfirmingDelete = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    AvatarView(photoData: person.photoData, initials: person.initials, size: 112)
                    Text(person.displayName)
                        .font(Theme.Fonts.profileName)
                        .multilineTextAlignment(.center)
                    if !person.relationship.isEmpty {
                        Text(person.relationship)
                            .font(Theme.Fonts.summaryLine)
                            .foregroundStyle(Theme.mutedBrown)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {
                if person.keyDates.isEmpty {
                    Button("Add a Birthday or Special Day", systemImage: "calendar.badge.plus") {
                        isEditing = true
                    }
                    .foregroundStyle(Theme.plum)
                } else {
                    ForEach(person.upcomingKeyDates) { keyDate in
                        KeyDateRow(keyDate: keyDate)
                    }
                }
            } header: {
                Text("Key Dates").themedSectionLabel()
            }
            .themedRows()

            Section {
                NavigationLink {
                    ReminderPlanView(person: person)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: hasOwnReminders ? "bell.badge.fill" : "bell")
                            .foregroundStyle(Theme.plum)
                            .frame(width: 28)
                        Text("Reminders")
                        Spacer()
                        Text(hasOwnReminders ? "Custom" : "Everyday")
                            .font(Theme.Fonts.secondary)
                            .foregroundStyle(Theme.mutedBrown)
                    }
                }
            }
            .themedRows()

            if !person.notes.isEmpty {
                Section {
                    Text(person.notes)
                } header: {
                    Text("Notes").themedSectionLabel()
                }
                .themedRows()
            }

            Section {
                // The dialog is attached to the button that opens it: it is
                // drawn as a popover pointing at whatever view it's attached to.
                Button("Delete Relationship", role: .destructive) {
                    isConfirmingDelete = true
                }
                .foregroundStyle(Theme.berry)
                .confirmationDialog("Delete \(person.displayName)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        modelContext.delete(person)
                        dismiss()
                    }
                } message: {
                    Text("This relationship and its key dates will be removed.")
                }
            }
            .themedRows()
        }
        .themedListBackground()
        .themedNavigationBar(title: person.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            PersonEditorView(person: person)
        }
    }

    /// A plan of their own, or one on any of their dates.
    private var hasOwnReminders: Bool {
        person.reminderPlan != nil || person.keyDates.contains { $0.reminderPlan != nil }
    }
}

private struct KeyDateRow: View {
    let keyDate: KeyDate

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: keyDate.kind.symbolName)
                .foregroundStyle(Theme.plum)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(keyDate.title)
                    .font(Theme.Fonts.personName)
                Text(keyDate.formattedDate)
                    .font(Theme.Fonts.secondary)
                    .foregroundStyle(Theme.mutedBrown)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(keyDate.countdownText)
                    .font(keyDate.daysUntilNext() == 0 ? Theme.Fonts.bodyStrong : Theme.Fonts.body)
                    .foregroundStyle(keyDate.daysUntilNext() == 0 ? Theme.clay : Theme.darkBrown)
                if let milestone = keyDate.milestoneText {
                    Text(milestone)
                        .font(Theme.Fonts.secondary)
                        .foregroundStyle(Theme.mutedBrown)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
