import Foundation

/// One notification to deliver: who and what it is about, and when.
struct PlannedReminder: Equatable {
    let title: String
    let body: String
    let fireDate: Date
}

/// Works out which reminders should be waiting to fire. It only decides —
/// `ReminderScheduler` hands the result to iOS — so it can be reasoned about
/// (and tested) without notifications.
enum ReminderPlanner {
    /// iOS keeps at most 64 pending notifications per app and silently drops
    /// the rest, so only the soonest are scheduled. The plan is rebuilt every
    /// time the app is opened, which tops the queue up again.
    static let limit = 60

    static func plan(
        for keyDates: [KeyDate],
        settings: ReminderSettings,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [PlannedReminder] {
        guard settings.isEnabled else { return [] }
        var reminders: [PlannedReminder] = []
        for keyDate in keyDates {
            guard let name = keyDate.person?.displayName else { continue }
            for lead in settings.leadDays {
                guard let (occurrence, fireDate) = nextFiring(of: keyDate, lead: lead, settings: settings, now: now, calendar: calendar) else { continue }
                reminders.append(PlannedReminder(
                    title: name,
                    body: body(for: keyDate, occurrence: occurrence, lead: lead, calendar: calendar),
                    fireDate: fireDate
                ))
            }
        }
        return Array(reminders.sorted { $0.fireDate < $1.fireDate }.prefix(limit))
    }

    /// The first occurrence whose reminder, `lead` days ahead of it, is still
    /// in the future. Usually that's the next occurrence; it's the one after
    /// when this year's reminder time has already passed.
    private static func nextFiring(
        of keyDate: KeyDate,
        lead: Int,
        settings: ReminderSettings,
        now: Date,
        calendar: Calendar
    ) -> (occurrence: Date, fireDate: Date)? {
        var searchFrom = now
        for _ in 0..<3 {
            let occurrence = keyDate.nextOccurrence(after: searchFrom, calendar: calendar)
            if let day = calendar.date(byAdding: .day, value: -lead, to: occurrence),
               let fireDate = calendar.date(byAdding: .minute, value: settings.minutesAfterMidnight, to: day),
               fireDate > now {
                return (occurrence, fireDate)
            }
            guard let dayAfter = calendar.date(byAdding: .day, value: 1, to: occurrence) else { return nil }
            searchFrom = dayAfter
        }
        return nil
    }

    /// "Birthday today · Turns 36" / "Birthday in 1 week, on Monday 19 October · Turns 36".
    private static func body(for keyDate: KeyDate, occurrence: Date, lead: Int, calendar: Calendar) -> String {
        var style = Date.FormatStyle.dateTime.weekday(.wide).day().month(.wide)
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        let when: String
        switch lead {
        case 0: when = "today"
        case 1: when = "tomorrow"
        case 7: when = "in 1 week, on \(occurrence.formatted(style))"
        case 14: when = "in 2 weeks, on \(occurrence.formatted(style))"
        default: when = "in \(lead) days, on \(occurrence.formatted(style))"
        }
        var text = "\(keyDate.title) \(when)"
        if let milestone = keyDate.milestoneText(on: occurrence, calendar: calendar) {
            text += " · \(milestone)"
        }
        return text
    }
}
