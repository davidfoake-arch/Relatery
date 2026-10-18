import SwiftUI
import SwiftData

/// A relationship's reminders: the everyday ones, or a plan of its own.
/// Each of its dates can then have its own plan too.
struct ReminderPlanView: View {
    let person: Person
    @AppStorage(ReminderSettingsKey.isEnabled) private var remindersEnabled = ReminderSettings().isEnabled
    @State private var isShowingSettings = false

    var body: some View {
        List {
            if !remindersEnabled {
                Section {
                    Button("Reminders are off. Turn them on to use these.", systemImage: "bell.slash") {
                        isShowingSettings = true
                    }
                    .font(Theme.Fonts.secondary)
                    .foregroundStyle(Theme.plum)
                }
                .themedRows()
            }

            ReminderPlanSections(
                plan: Binding { person.reminderPlan } set: { person.reminderPlan = $0 },
                customToggleTitle: "Custom Reminders for \(shortName)",
                inheritedName: "everyone’s reminders",
                inheritedRules: ReminderSettings.stored().defaultRules
            )

            if !person.keyDates.isEmpty {
                Section {
                    ForEach(person.upcomingKeyDates) { keyDate in
                        NavigationLink {
                            KeyDateRemindersView(keyDate: keyDate, person: person)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: keyDate.kind.symbolName)
                                    .foregroundStyle(Theme.plum)
                                    .frame(width: 24)
                                Text(keyDate.title)
                                Spacer()
                                Text(keyDate.reminderPlan == nil ? "Same as Above" : "Own Reminders")
                                    .font(Theme.Fonts.secondary)
                                    .foregroundStyle(Theme.mutedBrown)
                            }
                        }
                    }
                } header: {
                    Text("Dates").themedSectionLabel()
                } footer: {
                    Text("Give one date its own reminders, like more notice for an anniversary.")
                        .font(Theme.Fonts.footnote)
                        .foregroundStyle(Theme.mutedBrown)
                }
                .themedRows()
            }
        }
        .tint(Theme.plum)
        .themedListBackground()
        .themedNavigationBar(title: "Reminders")
        .sheet(isPresented: $isShowingSettings) {
            ReminderSettingsView()
        }
    }

    private var shortName: String {
        person.firstName.isEmpty ? person.displayName : person.firstName
    }
}

/// One date's reminders: its relationship's, or a plan of its own.
private struct KeyDateRemindersView: View {
    let keyDate: KeyDate
    let person: Person

    var body: some View {
        List {
            ReminderPlanSections(
                plan: Binding { keyDate.reminderPlan } set: { keyDate.reminderPlan = $0 },
                customToggleTitle: "Custom Reminders for This Date",
                inheritedName: person.reminderPlan == nil
                    ? "everyone’s reminders"
                    : "\(person.firstName.isEmpty ? person.displayName : person.firstName)’s reminders",
                inheritedRules: person.reminderPlan?.rules ?? ReminderSettings.stored().defaultRules
            )
        }
        .tint(Theme.plum)
        .themedListBackground()
        .themedNavigationBar(title: keyDate.title)
    }
}

/// The switch between inherited and custom reminders, and when custom, the
/// list of reminders with ways to add, edit and remove them.
private struct ReminderPlanSections: View {
    @Binding var plan: ReminderPlan?
    let customToggleTitle: String
    /// "everyone’s reminders", for "Using everyone’s reminders: …".
    let inheritedName: String
    let inheritedRules: [ReminderRule]

    /// The rule being edited; a new rule isn't in the plan yet.
    @State private var editing: ReminderRule?
    @State private var isConfirmingPreset = false
    @State private var alarmsDenied = ReminderAlarms.isDenied
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            Toggle(customToggleTitle, isOn: isCustom)
        } footer: {
            if plan == nil {
                Text("Using \(inheritedName): \(ReminderPlan(rules: inheritedRules).summary.lowercasedFirst).")
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.mutedBrown)
            }
        }
        .themedRows()

        if let plan {
            Section {
                if plan.rules.isEmpty {
                    Text("No reminders")
                        .foregroundStyle(Theme.mutedBrown)
                }
                ForEach(plan.sortedRules) { rule in
                    Button {
                        editing = rule
                    } label: {
                        ReminderRuleRow(rule: rule)
                    }
                    .foregroundStyle(Theme.darkBrown)
                }
                .onDelete { offsets in
                    let ids = offsets.map { plan.sortedRules[$0].id }
                    self.plan?.rules.removeAll { ids.contains($0.id) }
                }
                Button("Add Reminder", systemImage: "plus.circle.fill") {
                    editing = ReminderRule(daysBefore: 1, minutesAfterMidnight: ReminderSettings.stored().minutesAfterMidnight)
                }
                .foregroundStyle(Theme.plum)
            } header: {
                Text("Reminders").themedSectionLabel()
            } footer: {
                if alarmsDenied && plan.rules.contains(where: { $0.loudness == .alarm }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Alarms are turned off for Relatery, so alarm reminders will arrive as Time Sensitive notifications instead.")
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .foregroundStyle(Theme.plum)
                    }
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.mutedBrown)
                }
            }
            .themedRows()
            .sheet(item: $editing, onDismiss: { alarmsDenied = ReminderAlarms.isDenied }) { rule in
                ReminderRuleEditor(rule: rule, isNew: !plan.rules.contains { $0.id == rule.id }, onSave: save)
            }

            Section {
                Button("Use the “Important” Set", systemImage: "star.circle") {
                    if plan.rules.isEmpty {
                        applyPreset()
                    } else {
                        isConfirmingPreset = true
                    }
                }
                .foregroundStyle(Theme.plum)
                .confirmationDialog("Replace these reminders?", isPresented: $isConfirmingPreset, titleVisibility: .visible) {
                    Button("Replace", role: .destructive, action: applyPreset)
                } message: {
                    Text("The “Important” set has reminders 2 weeks, 1 week and 2 days ahead, an alarm the day before, and one on the day.")
                }
            } footer: {
                Text("For someone you really can’t forget: plenty of notice, getting louder as the day comes.")
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.mutedBrown)
            }
            .themedRows()
        }
    }

    /// Turning custom on starts from a copy of the inherited reminders, so
    /// there's something to adjust rather than an empty list.
    private var isCustom: Binding<Bool> {
        Binding {
            plan != nil
        } set: { isOn in
            plan = isOn ? ReminderPlan(rules: inheritedRules) : nil
        }
    }

    private func applyPreset() {
        plan = .important(minutesAfterMidnight: ReminderSettings.stored().minutesAfterMidnight)
        // The set includes an alarm; ask now, while it's clear why.
        if ReminderAlarms.canAsk {
            Task {
                _ = await ReminderAlarms.requestAuthorization()
                alarmsDenied = ReminderAlarms.isDenied
            }
        }
    }

    private func save(_ rule: ReminderRule) {
        guard var updated = plan else { return }
        if let index = updated.rules.firstIndex(where: { $0.id == rule.id }) {
            updated.rules[index] = rule
        } else {
            updated.rules.append(rule)
        }
        plan = updated
    }
}

private struct ReminderRuleRow: View {
    let rule: ReminderRule

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: rule.loudness.symbolName)
                .foregroundStyle(rule.loudness == .normal ? Theme.plum : Theme.clay)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(rule.whenLabel), \(rule.timeLabel)")
                Text(detail)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.mutedBrown)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.stone)
        }
        .contentShape(Rectangle())
    }

    private var detail: String {
        rule.asksForReady ? "\(rule.loudness.title) · Keeps reminding" : rule.loudness.title
    }
}

extension String {
    /// "On the day, …" → "on the day, …", for use mid-sentence.
    var lowercasedFirst: String {
        prefix(1).lowercased() + dropFirst()
    }

    /// "on the day, …" → "On the day, …".
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}
