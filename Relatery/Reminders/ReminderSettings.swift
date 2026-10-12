import Foundation

/// The user's reminder preferences. They apply to every key date.
struct ReminderSettings: Equatable {
    /// Master switch. Off until the user turns reminders on.
    var isEnabled = false
    /// A reminder on the day itself.
    var remindsOnDay = true
    /// A second, earlier reminder this many days ahead; 0 for none.
    var advanceDays = 7
    /// When reminders arrive, as minutes after midnight. 9:00 by default.
    var minutesAfterMidnight = 9 * 60

    static let advanceChoices = [0, 1, 2, 3, 7, 14, 30]

    /// How far ahead of each occurrence a reminder is sent, in days.
    var leadDays: [Int] {
        var leads: [Int] = []
        if advanceDays > 0 { leads.append(advanceDays) }
        if remindsOnDay { leads.append(0) }
        return leads
    }

    static func advanceLabel(_ days: Int) -> String {
        switch days {
        case 0: "None"
        case 1: "1 day before"
        case 7: "1 week before"
        case 14: "2 weeks before"
        case 30: "1 month before"
        default: "\(days) days before"
        }
    }
}

// MARK: - Storage

/// The UserDefaults keys the settings are kept under. `@AppStorage` in the
/// settings screen uses the same keys, so the two always agree.
enum ReminderSettingsKey {
    static let isEnabled = "remindersEnabled"
    static let remindsOnDay = "remindersOnDay"
    static let advanceDays = "remindersAdvanceDays"
    static let minutesAfterMidnight = "remindersMinutesAfterMidnight"
}

extension ReminderSettings {
    /// Reads the stored settings, falling back to the defaults above for
    /// anything never set.
    static func stored(in defaults: UserDefaults = .standard) -> ReminderSettings {
        var settings = ReminderSettings()
        if let value = defaults.object(forKey: ReminderSettingsKey.isEnabled) as? Bool { settings.isEnabled = value }
        if let value = defaults.object(forKey: ReminderSettingsKey.remindsOnDay) as? Bool { settings.remindsOnDay = value }
        if let value = defaults.object(forKey: ReminderSettingsKey.advanceDays) as? Int { settings.advanceDays = value }
        if let value = defaults.object(forKey: ReminderSettingsKey.minutesAfterMidnight) as? Int { settings.minutesAfterMidnight = value }
        return settings
    }
}
