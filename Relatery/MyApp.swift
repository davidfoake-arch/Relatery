import SwiftUI
import SwiftData

@main struct MyApp: App {
    init() {
        Theme.verifyFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Person.self)
    }
}
