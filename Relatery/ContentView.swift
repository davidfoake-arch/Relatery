import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        PeopleListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Person.self, inMemory: true)
}
