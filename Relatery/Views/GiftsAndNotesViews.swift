import SwiftUI
import SwiftData

/// What the profile's gift and note rows open, as one sheet.
enum ProfileSheet: Identifiable {
    case newGift
    case gift(GiftIdea)
    case newNote
    case note(NoteEntry)

    var id: String {
        switch self {
        case .newGift: "newGift"
        case .gift(let gift): "gift-\(gift.persistentModelID.hashValue)"
        case .newNote: "newNote"
        case .note(let note): "note-\(note.persistentModelID.hashValue)"
        }
    }

    @ViewBuilder
    func view(for person: Person) -> some View {
        switch self {
        case .newGift: GiftIdeaEditor(person: person)
        case .gift(let gift): GiftIdeaEditor(person: person, gift: gift)
        case .newNote: NoteEditor(person: person)
        case .note(let note): NoteEditor(person: person, note: note)
        }
    }
}

/// The profile's Gift Ideas and Notes sections.
struct GiftsAndNotesSections: View {
    let person: Person
    @Binding var sheet: ProfileSheet?

    /// How many notes the profile shows before "All Notes".
    private let notePreviewCount = 3

    var body: some View {
        Section {
            ForEach(person.openGiftIdeas) { gift in
                Button { sheet = .gift(gift) } label: {
                    GiftRow(gift: gift)
                }
                .foregroundStyle(Theme.darkBrown)
                .swipeActions(edge: .leading) {
                    statusSwipe(for: gift)
                }
            }
            Button("Add Gift Idea", systemImage: "plus.circle.fill") { sheet = .newGift }
                .foregroundStyle(Theme.accent)
            if !person.givenGifts.isEmpty {
                NavigationLink {
                    GivenGiftsView(person: person, sheet: $sheet)
                } label: {
                    HStack {
                        Label("Given", systemImage: GiftStatus.given.symbolName)
                            .foregroundStyle(Theme.accent)
                        Spacer()
                        Text("\(person.givenGifts.count)")
                            .font(Theme.Fonts.secondary)
                            .foregroundStyle(Theme.mutedBrown)
                    }
                }
            }
        } header: {
            Text("Gift Ideas").themedSectionLabel()
        } footer: {
            if !person.openGiftIdeas.isEmpty {
                Text("Swipe right to mark a gift bought or given.")
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.mutedBrown)
            }
        }
        .themedRows()

        Section {
            ForEach(person.sortedNotes.prefix(notePreviewCount)) { note in
                Button { sheet = .note(note) } label: {
                    NoteRow(note: note)
                }
                .foregroundStyle(Theme.darkBrown)
            }
            Button("Add Note", systemImage: "square.and.pencil") { sheet = .newNote }
                .foregroundStyle(Theme.accent)
            if person.noteEntries.count > notePreviewCount {
                NavigationLink {
                    AllNotesView(person: person, sheet: $sheet)
                } label: {
                    HStack {
                        Text("All Notes")
                            .foregroundStyle(Theme.accent)
                        Spacer()
                        Text("\(person.noteEntries.count)")
                            .font(Theme.Fonts.secondary)
                            .foregroundStyle(Theme.mutedBrown)
                    }
                }
            }
        } header: {
            Text("Notes").themedSectionLabel()
        }
        .themedRows()
    }

    /// Moves an idea one step on: idea → bought → given.
    @ViewBuilder
    private func statusSwipe(for gift: GiftIdea) -> some View {
        if gift.status == .idea {
            Button("Bought", systemImage: GiftStatus.bought.symbolName) {
                gift.status = .bought
            }
            .tint(Theme.plum)
        }
        Button("Given", systemImage: GiftStatus.given.symbolName) {
            gift.status = .given
            gift.givenOn = .now
        }
        .tint(Theme.clayFill)
    }
}

struct GiftRow: View {
    let gift: GiftIdea
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: gift.status.symbolName)
                .foregroundStyle(gift.status == .bought ? Theme.clay : Theme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(gift.title)
                    .multilineTextAlignment(.leading)
                let detail = [gift.status == .bought ? "Bought" : nil, gift.detailLine.isEmpty ? nil : gift.detailLine]
                    .compactMap { $0 }
                    .joined(separator: " · ")
                if !detail.isEmpty {
                    Text(detail)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.mutedBrown)
                }
            }
            Spacer()
            if let url = gift.url {
                // Its own button, so tapping the link doesn't open the editor.
                Button {
                    openURL(url)
                } label: {
                    Image(systemName: "link")
                        .foregroundStyle(Theme.accent)
                        .padding(6)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Open link")
            }
        }
        .contentShape(Rectangle())
    }
}

struct NoteRow: View {
    let note: NoteEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.date.formatted(date: .abbreviated, time: .omitted))
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.mutedBrown)
            Text(note.text)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// Every gift already given, most recent first.
private struct GivenGiftsView: View {
    let person: Person
    @Binding var sheet: ProfileSheet?

    var body: some View {
        List {
            Section {
                ForEach(person.givenGifts) { gift in
                    Button { sheet = .gift(gift) } label: {
                        GiftRow(gift: gift)
                    }
                    .foregroundStyle(Theme.darkBrown)
                }
            } footer: {
                Text("Kept so the same gift isn’t given twice.")
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.mutedBrown)
            }
            .themedRows()
        }
        .themedListBackground()
        .themedNavigationBar(title: "Given")
    }
}

/// Every note, newest first.
private struct AllNotesView: View {
    let person: Person
    @Binding var sheet: ProfileSheet?

    var body: some View {
        List {
            Section {
                ForEach(person.sortedNotes) { note in
                    Button { sheet = .note(note) } label: {
                        NoteRow(note: note)
                    }
                    .foregroundStyle(Theme.darkBrown)
                }
            }
            .themedRows()
        }
        .themedListBackground()
        .themedNavigationBar(title: "Notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Note", systemImage: "plus") { sheet = .newNote }
            }
        }
    }
}
