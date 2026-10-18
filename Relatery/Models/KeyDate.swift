import Foundation
import SwiftData
import CryptoKit

enum KeyDateKind: String, Codable, CaseIterable, Identifiable {
    case birthday
    // Stored as "anniversary", the name this kind had before the two
    // anniversaries were told apart.
    case weddingAnniversary = "anniversary"
    case datingAnniversary
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .birthday: "Birthday"
        case .weddingAnniversary: "Wedding Anniversary"
        case .datingAnniversary: "Dating Anniversary"
        case .custom: "Special Day"
        }
    }

    /// `title` split in two for menus, which are too narrow for "Wedding
    /// Anniversary" on one line and hyphenate it mid-word. Shown as a menu
    /// item's title and subtitle.
    var menuTitle: (title: String, subtitle: String?) {
        switch self {
        case .weddingAnniversary: ("Wedding", "Anniversary")
        case .datingAnniversary: ("Dating", "Anniversary")
        case .birthday, .custom: (title, nil)
        }
    }

    var symbolName: String {
        switch self {
        case .birthday: "birthday.cake.fill"
        case .weddingAnniversary: "heart.circle.fill"
        case .datingAnniversary: "heart.fill"
        case .custom: "star.fill"
        }
    }

    /// A relationship has at most one of each kind, except custom days,
    /// which the user names and can add as many of as they like.
    var allowsMultiple: Bool { self == .custom }
}

/// A day that recurs every year. The year is optional, like birthdays in Contacts.
@Model
final class KeyDate {
    var kind: KeyDateKind = KeyDateKind.custom
    /// User-provided name, used for custom days only.
    var label: String = ""
    var month: Int = 1
    var day: Int = 1
    var year: Int?
    var person: Person?
    /// Gifts meant for this date. Removing the date leaves the gifts,
    /// without an occasion.
    @Relationship(deleteRule: .nullify, inverse: \GiftIdea.occasion)
    var giftIdeas: [GiftIdea] = []
    /// This date's own reminders, replacing its relationship's. Nil to use
    /// the relationship's (see `reminderPlan`).
    var reminderPlanData: Data?

    init(kind: KeyDateKind, label: String = "", month: Int, day: Int, year: Int? = nil) {
        self.kind = kind
        self.label = label
        self.month = month
        self.day = day
        self.year = year
    }

    var reminderPlan: ReminderPlan? {
        get { ReminderPlan.decode(reminderPlanData) }
        set { reminderPlanData = ReminderPlan.encode(newValue) }
    }

    /// The reminders that apply to this date: its own plan, else its
    /// relationship's, else the everyday settings.
    func reminderRules(settings: ReminderSettings) -> [ReminderRule] {
        (reminderPlan ?? person?.reminderPlan)?.rules ?? settings.defaultRules
    }

    /// A short, stable name for this date, for remembering which reminders
    /// have been answered with "I'm Ready" across app launches.
    var reminderKey: String {
        guard let data = try? JSONEncoder().encode(persistentModelID) else { return "" }
        return SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    var title: String {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? kind.title : trimmed
    }

    var formattedDate: String {
        Self.formattedDate(month: month, day: day, year: year)
    }

    /// "12 October", or "12 October 1990" when the year is known.
    static func formattedDate(month: Int, day: Int, year: Int?) -> String {
        // 2000 is a leap year, so Feb 29 survives when the year is unknown.
        let components = DateComponents(year: year ?? 2000, month: month, day: day)
        guard let date = Calendar.current.date(from: components) else { return "" }
        if year == nil {
            return date.formatted(.dateTime.month(.wide).day())
        }
        return date.formatted(.dateTime.month(.wide).day().year())
    }

    /// The next time this day comes around, today included.
    func nextOccurrence(after reference: Date = .now, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: reference)
        let currentYear = calendar.component(.year, from: today)
        // A date whose original year is still ahead (e.g. an upcoming wedding) first occurs then.
        let startYear = max(currentYear, year ?? currentYear)
        for candidateYear in startYear...(startYear + 1) {
            if let date = occurrence(in: candidateYear, calendar: calendar), date >= today {
                return date
            }
        }
        return today
    }

    func daysUntilNext(from reference: Date = .now, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: reference)
        let next = nextOccurrence(after: reference, calendar: calendar)
        return calendar.dateComponents([.day], from: today, to: next).day ?? 0
    }

    var countdownText: String {
        switch daysUntilNext() {
        case 0: "Today"
        case 1: "Tomorrow"
        case let days: "in \(days) days"
        }
    }

    /// "Turns 30" / "10 years" for the next occurrence, when the original year is known.
    var milestoneText: String? {
        milestoneText(on: nextOccurrence())
    }

    /// The same, for a given occurrence of this day.
    func milestoneText(on occurrence: Date, calendar: Calendar = .current) -> String? {
        guard let year else { return nil }
        let count = calendar.component(.year, from: occurrence) - year
        guard count > 0 else { return nil }
        switch kind {
        case .birthday: return "Turns \(count)"
        case .weddingAnniversary, .datingAnniversary, .custom: return count == 1 ? "1 year" : "\(count) years"
        }
    }

    private func occurrence(in year: Int, calendar: Calendar) -> Date? {
        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { return nil }
        // Feb 29 falls back to Feb 28 in non-leap years.
        return calendar.date(from: DateComponents(year: year, month: month, day: min(day, dayRange.count)))
    }
}
