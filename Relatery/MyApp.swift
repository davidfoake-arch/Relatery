import SwiftUI
import SwiftData

@main struct MyApp: App {
    /// Created here rather than with `.modelContainer(for:)` so the
    /// background reminder refresh can read the same store.
    private let container: ModelContainer

    init() {
        Theme.verifyFonts()
        Theme.applyUIKitAppearance()
        ReminderScheduler.shared.start()
        do {
            container = try ModelContainer(for: Person.self)
        } catch {
            fatalError("Couldn't open the data store: \(error)")
        }
        LegacyNotes.migrate(in: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Colours the selected tab. Screens set their own colours
                // for everything else.
                .tint(Theme.accent)
        }
        .modelContainer(container)
        .backgroundTask(.appRefresh(ReminderScheduler.refreshTaskID)) { [container] in
            await ReminderScheduler.shared.refreshInBackground(container: container)
        }
    }
}
