import SwiftUI
import SwiftData

@main struct MyApp: App {
    init() {
        Theme.verifyFonts()
        Theme.applyUIKitAppearance()
        ReminderScheduler.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Colours the selected tab. Screens set their own colours
                // for everything else.
                .tint(Theme.plum)
        }
        .modelContainer(for: Person.self)
    }
}
