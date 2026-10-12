import SwiftUI
import SwiftData

struct ContentView: View {
    private enum Tab {
        case relationships
        case upcoming
    }

    @Environment(\.scenePhase) private var scenePhase
    @Query private var keyDates: [KeyDate]
    @AppStorage(ReminderSettingsKey.isEnabled) private var remindersEnabled = ReminderSettings().isEnabled
    @AppStorage(ReminderSettingsKey.remindsOnDay) private var remindsOnDay = ReminderSettings().remindsOnDay
    @AppStorage(ReminderSettingsKey.advanceDays) private var advanceDays = ReminderSettings().advanceDays
    @AppStorage(ReminderSettingsKey.minutesAfterMidnight) private var minutesAfterMidnight = ReminderSettings().minutesAfterMidnight
    @State private var tab = Tab.relationships

    private var scheduler = ReminderScheduler.shared

    var body: some View {
        TabView(selection: $tab) {
            PeopleListView()
                .tabItem { Label("Relationships", systemImage: "person.2.fill") }
                .tag(Tab.relationships)
            UpcomingView()
                .tabItem { Label("Upcoming", systemImage: "calendar") }
                .tag(Tab.upcoming)
        }
        // Rebuild the reminders whenever anything they depend on changes: a
        // date, a name, a setting, permission — or simply the app being
        // opened on a later day.
        .task(id: reminderInputs) {
            guard scenePhase == .active else { return }
            await scheduler.reschedule(for: keyDates, settings: .stored())
        }
        .onChange(of: scheduler.didOpenFromReminder) {
            guard scheduler.didOpenFromReminder else { return }
            tab = .upcoming
            scheduler.didOpenFromReminder = false
        }
    }

    /// Everything the reminder plan is built from, as one comparable value.
    private var reminderInputs: [String] {
        let settings = "\(remindersEnabled)|\(remindsOnDay)|\(advanceDays)|\(minutesAfterMidnight)"
        let state = "\(scenePhase)|\(scheduler.authorization.rawValue)"
        let dates = keyDates
            .map { "\($0.person?.displayName ?? "")|\($0.title)|\($0.month)|\($0.day)|\($0.year ?? 0)" }
            .sorted()
        return [settings, state] + dates
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Person.self, inMemory: true)
}
