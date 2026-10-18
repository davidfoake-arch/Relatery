import Foundation

/// How hard a reminder tries to get attention.
enum ReminderLoudness: String, Codable, CaseIterable, Identifiable, Comparable {
    /// An ordinary notification: silenced by Focus, quiet in Silent mode.
    case normal
    /// Breaks through Focus (if allowed in Settings) and stays on the Lock
    /// Screen longer.
    case timeSensitive
    /// A real alarm, via AlarmKit: rings through Silent mode and Focus.
    case alarm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "Notification"
        case .timeSensitive: "Time Sensitive"
        case .alarm: "Alarm"
        }
    }

    var detail: String {
        switch self {
        case .normal: "Stays quiet during a Focus or in Silent mode."
        case .timeSensitive: "Gets through a Focus and stays on the Lock Screen."
        case .alarm: "Rings through Silent mode and Focus, like the Clock app."
        }
    }

    var symbolName: String {
        switch self {
        case .normal: "bell"
        case .timeSensitive: "bell.badge"
        case .alarm: "alarm"
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

/// One reminder in a plan: how far ahead, at what time, and how loudly.
struct ReminderRule: Codable, Hashable, Identifiable {
    var id = UUID()
    /// 0 for the day itself.
    var daysBefore: Int
    /// The time of day, as minutes after midnight.
    var minutesAfterMidnight: Int
    var loudness: ReminderLoudness = .normal
    /// Comes back until "I'm Ready" is tapped. Not used for alarms, which
    /// ring until they're stopped.
    var keepsReminding = false

    static let leadChoices = [0, 1, 2, 3, 7, 14, 21, 30]

    var asksForReady: Bool {
        keepsReminding && loudness != .alarm
    }

    var whenLabel: String {
        Self.whenLabel(daysBefore)
    }

    static func whenLabel(_ days: Int) -> String {
        switch days {
        case 0: "On the day"
        case 1: "The day before"
        case 7: "1 week before"
        case 14: "2 weeks before"
        case 21: "3 weeks before"
        case 30: "1 month before"
        default: "\(days) days before"
        }
    }

    var timeLabel: String {
        let start = Calendar.current.startOfDay(for: .now)
        let date = Calendar.current.date(byAdding: .minute, value: minutesAfterMidnight, to: start) ?? start
        return date.formatted(date: .omitted, time: .shortened)
    }
}

/// A list of reminders that replaces the everyday ones, for a relationship or
/// for a single date. An empty plan means no reminders at all.
struct ReminderPlan: Codable, Hashable {
    var rules: [ReminderRule] = []

    /// Earliest reminder first.
    var sortedRules: [ReminderRule] {
        rules.sorted { ($0.daysBefore, -$0.minutesAfterMidnight) > ($1.daysBefore, -$1.minutesAfterMidnight) }
    }

    /// A starting point for someone you really can't forget: plenty of
    /// notice, getting louder as the day comes.
    static func important(minutesAfterMidnight: Int) -> ReminderPlan {
        ReminderPlan(rules: [
            ReminderRule(daysBefore: 14, minutesAfterMidnight: minutesAfterMidnight, loudness: .timeSensitive, keepsReminding: true),
            ReminderRule(daysBefore: 7, minutesAfterMidnight: minutesAfterMidnight, loudness: .timeSensitive, keepsReminding: true),
            ReminderRule(daysBefore: 2, minutesAfterMidnight: minutesAfterMidnight, loudness: .timeSensitive, keepsReminding: true),
            ReminderRule(daysBefore: 1, minutesAfterMidnight: minutesAfterMidnight, loudness: .alarm),
            ReminderRule(daysBefore: 0, minutesAfterMidnight: minutesAfterMidnight, loudness: .timeSensitive),
        ])
    }

    /// "On the day, 1 week before" — for summaries.
    var summary: String {
        let rules = sortedRules
        guard !rules.isEmpty else { return "No reminders" }
        return rules.map(\.whenLabel).joined(separator: ", ").lowercased().capitalizedFirst
    }

    // MARK: - Storage

    /// Plans are stored as JSON in a `Data` property rather than as a
    /// SwiftData attribute of their own; adding fields to a rule later then
    /// needs no migration.
    static func decode(_ data: Data?) -> ReminderPlan? {
        data.flatMap { try? JSONDecoder().decode(ReminderPlan.self, from: $0) }
    }

    static func encode(_ plan: ReminderPlan?) -> Data? {
        plan.flatMap { try? JSONEncoder().encode($0) }
    }
}

extension ReminderSettings {
    /// The everyday settings as rules, for anyone without a plan of their own.
    var defaultRules: [ReminderRule] {
        leadDays.map { ReminderRule(daysBefore: $0, minutesAfterMidnight: minutesAfterMidnight) }
    }
}
