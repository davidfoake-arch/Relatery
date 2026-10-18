import SwiftUI
import SwiftData

/// Every key date across all relationships, soonest first.
struct UpcomingView: View {
    @Query private var keyDates: [KeyDate]
    @AppStorage(ReminderSettingsKey.isEnabled) private var remindersEnabled = ReminderSettings().isEnabled
    @State private var isShowingReminderSettings = false

    var body: some View {
        NavigationStack {
            List {
                if !remindersEnabled && !keyDates.isEmpty {
                    Section {
                        Button {
                            isShowingReminderSettings = true
                        } label: {
                            Label("Turn on reminders so you don’t miss a date", systemImage: "bell.badge")
                                .font(Theme.Fonts.secondary)
                        }
                        .foregroundStyle(Theme.accent)
                    }
                    .themedRows()
                }

                ForEach(sections, id: \.title) { section in
                    Section {
                        ForEach(section.keyDates) { keyDate in
                            if let person = keyDate.person {
                                NavigationLink(value: person) {
                                    UpcomingRow(keyDate: keyDate, person: person)
                                }
                            }
                        }
                    } header: {
                        Text(section.title).themedSectionLabel()
                    }
                    .themedRows()
                }
            }
            .themedListBackground()
            .overlay {
                if keyDates.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing Coming Up", systemImage: "calendar")
                            .font(Theme.Fonts.cardHeading)
                            .foregroundStyle(Theme.darkBrown)
                    } description: {
                        Text("Birthdays, anniversaries and special days you add to a relationship appear here.")
                            .font(Theme.Fonts.secondary)
                            .foregroundStyle(Theme.mutedBrown)
                    }
                }
            }
            .themedNavigationBar(title: "Upcoming")
            .navigationDestination(for: Person.self) { person in
                PersonDetailView(person: person)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Reminders", systemImage: remindersEnabled ? "bell.fill" : "bell") {
                        isShowingReminderSettings = true
                    }
                    // Without this the app-wide plum tint shows through as pink.
                    .tint(Theme.onPlum)
                }
            }
            .sheet(isPresented: $isShowingReminderSettings) {
                ReminderSettingsView()
            }
        }
    }

    private var sections: [(title: String, keyDates: [KeyDate])] {
        let sorted = keyDates
            .filter { $0.person != nil }
            .map { (keyDate: $0, days: $0.daysUntilNext()) }
            .sorted { $0.days < $1.days }
        let groups: [(title: String, range: ClosedRange<Int>)] = [
            ("Today", 0...0),
            ("Next 7 Days", 1...7),
            ("Next 30 Days", 8...30),
            ("Later", 31...Int.max),
        ]
        return groups.compactMap { group in
            let matching = sorted.filter { group.range.contains($0.days) }.map(\.keyDate)
            return matching.isEmpty ? nil : (group.title, matching)
        }
    }
}

private struct UpcomingRow: View {
    let keyDate: KeyDate
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(photoData: person.photoData, initials: person.initials)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.displayName)
                    .font(Theme.Fonts.personName)
                HStack(spacing: 4) {
                    Image(systemName: keyDate.kind.symbolName)
                    Text(detail)
                }
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.mutedBrown)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(keyDate.countdownText)
                    .font(isToday ? Theme.Fonts.bodyStrong : Theme.Fonts.secondary)
                    .foregroundStyle(isToday ? Theme.clay : Theme.darkBrown)
                Text(keyDate.nextOccurrence().formatted(.dateTime.day().month(.abbreviated)))
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.mutedBrown)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var isToday: Bool { keyDate.daysUntilNext() == 0 }

    /// "Birthday · Turns 36"
    private var detail: String {
        [keyDate.title, keyDate.milestoneText].compactMap { $0 }.joined(separator: " · ")
    }
}

#Preview {
    UpcomingView()
        .modelContainer(for: Person.self, inMemory: true)
}
