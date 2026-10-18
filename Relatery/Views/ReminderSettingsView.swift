import SwiftUI

struct ReminderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(ReminderSettingsKey.isEnabled) private var isEnabled = ReminderSettings().isEnabled
    @AppStorage(ReminderSettingsKey.remindsOnDay) private var remindsOnDay = ReminderSettings().remindsOnDay
    @AppStorage(ReminderSettingsKey.advanceDays) private var advanceDays = ReminderSettings().advanceDays
    @AppStorage(ReminderSettingsKey.minutesAfterMidnight) private var minutesAfterMidnight = ReminderSettings().minutesAfterMidnight

    private var scheduler = ReminderScheduler.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Reminders", isOn: $isEnabled)
                } footer: {
                    Text("Get a notification for birthdays, anniversaries and special days.")
                        .font(Theme.Fonts.footnote)
                        .foregroundStyle(Theme.mutedBrown)
                }
                .themedRows()

                if isEnabled && scheduler.authorization == .denied {
                    Section {
                        Text("Notifications are turned off for Relatery, so reminders can’t be shown.")
                            .font(Theme.Fonts.secondary)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                openURL(url)
                            }
                        }
                        .foregroundStyle(Theme.accent)
                    }
                    .themedRows()
                }

                if isEnabled {
                    Section {
                        Toggle("On the Day", isOn: $remindsOnDay)
                        Picker("Heads-Up", selection: $advanceDays) {
                            ForEach(ReminderSettings.advanceChoices, id: \.self) { days in
                                Text(ReminderSettings.advanceLabel(days)).tag(days)
                            }
                        }
                        DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                    } header: {
                        Text("When").themedSectionLabel()
                    } footer: {
                        Text("A heads-up gives you time to find a gift or make a plan.")
                            .font(Theme.Fonts.footnote)
                            .foregroundStyle(Theme.mutedBrown)
                    }
                    .themedRows()
                }
            }
            .tint(Theme.accent)
            .themedListBackground()
            .themedNavigationBar(title: "Reminders")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await scheduler.refreshAuthorization() }
            .onChange(of: isEnabled) {
                guard isEnabled else { return }
                // Turning reminders on is the moment to ask iOS for permission.
                Task { _ = await scheduler.requestAuthorization() }
            }
        }
    }

    /// The reminder time as a `Date` today, which is what `DatePicker` edits.
    private var time: Binding<Date> {
        Binding {
            let startOfDay = Calendar.current.startOfDay(for: .now)
            return Calendar.current.date(byAdding: .minute, value: minutesAfterMidnight, to: startOfDay) ?? .now
        } set: { newValue in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            minutesAfterMidnight = (components.hour ?? 9) * 60 + (components.minute ?? 0)
        }
    }
}

#Preview {
    ReminderSettingsView()
}
