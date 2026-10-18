import SwiftUI
import SwiftData

/// Adds or edits one gift idea. Changes only apply on Save.
struct GiftIdeaEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let person: Person
    private let gift: GiftIdea?

    @State private var title: String
    @State private var price: Decimal?
    @State private var link: String
    @State private var status: GiftStatus
    @State private var occasion: KeyDate?
    @State private var isConfirmingDelete = false
    @FocusState private var isTitleFocused: Bool

    init(person: Person, gift: GiftIdea? = nil) {
        self.person = person
        self.gift = gift
        _title = State(initialValue: gift?.title ?? "")
        _price = State(initialValue: gift?.price)
        _link = State(initialValue: gift?.link ?? "")
        _status = State(initialValue: gift?.status ?? .idea)
        // A new idea is for the next date coming up, which is usually right.
        _occasion = State(initialValue: gift == nil ? person.upcomingKeyDates.first : gift?.occasion)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What is it?", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                        .textInputAutocapitalization(.sentences)
                        .focused($isTitleFocused)
                    TextField("Price", value: $price, format: .currency(code: currencyCode))
                        .keyboardType(.decimalPad)
                    TextField("Link", text: $link)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .themedRows()

                Section {
                    Picker("Status", selection: $status) {
                        ForEach(GiftStatus.allCases) { status in
                            Label(status.title, systemImage: status.symbolName).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    Picker("For", selection: $occasion) {
                        Text("Any Time").tag(KeyDate?.none)
                        ForEach(person.upcomingKeyDates) { keyDate in
                            Text(keyDate.title).tag(KeyDate?.some(keyDate))
                        }
                    }
                }
                .themedRows()

                if gift != nil {
                    Section {
                        Button("Delete Gift Idea", role: .destructive) {
                            isConfirmingDelete = true
                        }
                        .foregroundStyle(Theme.berry)
                        .confirmationDialog("Delete this gift idea?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                            Button("Delete", role: .destructive, action: delete)
                        }
                    }
                    .themedRows()
                }
            }
            .tint(Theme.plum)
            .themedListBackground()
            .scrollDismissesKeyboard(.interactively)
            .themedNavigationBar(title: gift == nil ? "New Gift Idea" : "Edit Gift Idea")
            .onAppear {
                if gift == nil { isTitleFocused = true }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
        }
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        let target = gift ?? GiftIdea(title: trimmedTitle)
        if gift == nil {
            target.person = person
            modelContext.insert(target)
        }
        target.title = trimmedTitle
        target.price = price
        target.link = link.trimmingCharacters(in: .whitespaces)
        target.occasion = occasion
        // Given today, the first time it's marked given.
        if status == .given && target.status != .given {
            target.givenOn = .now
        } else if status != .given {
            target.givenOn = nil
        }
        target.status = status
        dismiss()
    }

    private func delete() {
        if let gift {
            modelContext.delete(gift)
        }
        dismiss()
    }
}
