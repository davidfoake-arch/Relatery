import SwiftUI

/// Adds or edits one reminder in a plan: when, what time, how loudly, and
/// whether it keeps coming back. Changes only apply on Save.
struct ReminderRuleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var rule: ReminderRule
    @State private var alarmsDenied = ReminderAlarms.isDenied
    let isNew: Bool
    let onSave: (ReminderRule) -> Void

    init(rule: ReminderRule, isNew: Bool, onSave: @escaping (ReminderRule) -> Void) {
        _rule = State(initialValue: rule)
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("When", selection: $rule.daysBefore) {
                        ForEach(ReminderRule.leadChoices, id: \.self) { days in
                            Text(ReminderRule.whenLabel(days)).tag(days)
                        }
                    }
                    DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                }
                .themedRows()

                Section {
                    Picker("How", selection: $rule.loudness) {
                        ForEach(ReminderLoudness.allCases) { loudness in
                            HStack(spacing: 12) {
                                Image(systemName: loudness.symbolName)
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(loudness.title)
                                    Text(loudness.detail)
                                        .font(Theme.Fonts.caption)
                                        .foregroundStyle(Theme.mutedBrown)
                                }
                            }
                            .tag(loudness)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("How").themedSectionLabel()
                } footer: {
                    if rule.loudness == .alarm && alarmsDenied {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Alarms are turned off for Relatery, so this will arrive as a Time Sensitive notification instead.")
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }
                            .foregroundStyle(Theme.accent)
                        }
                        .font(Theme.Fonts.footnote)
                        .foregroundStyle(Theme.mutedBrown)
                    }
                }
                .themedRows()

                if rule.loudness != .alarm {
                    Section {
                        Toggle("Keep Reminding Me", isOn: $rule.keepsReminding)
                    } footer: {
                        Text("Comes back up to \(ReminderPlanner.followUpCount) times until you tap “I’m Ready” on the notification.")
                            .font(Theme.Fonts.footnote)
                            .foregroundStyle(Theme.mutedBrown)
                    }
                    .themedRows()
                }
            }
            .tint(Theme.accent)
            .themedListBackground()
            .themedNavigationBar(title: isNew ? "New Reminder" : "Edit Reminder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(rule)
                        dismiss()
                    }
                }
            }
            .onChange(of: rule.loudness) {
                // Choosing Alarm is the moment to ask for permission.
                guard rule.loudness == .alarm, ReminderAlarms.canAsk else { return }
                Task {
                    _ = await ReminderAlarms.requestAuthorization()
                    alarmsDenied = ReminderAlarms.isDenied
                }
            }
        }
    }

    /// The reminder time as a `Date` today, which is what `DatePicker` edits.
    private var time: Binding<Date> {
        Binding {
            let startOfDay = Calendar.current.startOfDay(for: .now)
            return Calendar.current.date(byAdding: .minute, value: rule.minutesAfterMidnight, to: startOfDay) ?? .now
        } set: { newValue in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            rule.minutesAfterMidnight = (components.hour ?? 9) * 60 + (components.minute ?? 0)
        }
    }
}
