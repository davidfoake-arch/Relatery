import Foundation
import SwiftData

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

    init(kind: KeyDateKind, label: String = "", month: Int, day: Int, year: Int? = nil) {
        self.kind = kind
        self.label = label
        self.month = month
        self.day = day
        self.year = year
    }

    var title: String {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? kind.title : trimmed
    }

    var formattedDate: String {
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
        guard let year else { return nil }
        let nextYear = Calendar.current.component(.year, from: nextOccurrence())
        let count = nextYear - year
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
