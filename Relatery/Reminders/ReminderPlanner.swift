import Foundation

/// One reminder to deliver: who and what it is about, when, and how.
struct PlannedReminder: Equatable {
    enum Kind: Equatable {
        /// A reminder from a rule.
        case reminder
        /// A repeat of one, because "I'm Ready" hasn't been tapped yet.
        case followUp
        /// The last reminder that fits in the queue, asking for the app to be
        /// opened so the rest can be scheduled.
        case safetyNet
    }

    let title: String
    let body: String
    let fireDate: Date
    var loudness: ReminderLoudness = .normal
    var kind: Kind = .reminder
    /// Which occurrence of which date this is about; "I'm Ready" marks it
    /// as answered. Nil for the safety net.
    var occurrenceKey: String?
    /// Offers "I'm Ready" and "Remind Me in 1 Hour".
    var asksForReady = false
}

/// Works out which reminders should be waiting to fire. It only decides —
/// `ReminderScheduler` hands the result to iOS — so it can be reasoned about
/// (and tested) without notifications.
enum ReminderPlanner {
    /// iOS keeps at most 64 pending notifications per app and silently drops
    /// the rest, so only the soonest are scheduled. The plan is rebuilt every
    /// time the app is opened (and now and then in the background), which
    /// tops the queue up again.
    static let limit = 60

    /// How many times a "keep reminding" reminder comes back.
    static let followUpCount = 3

    static func plan(
        for keyDates: [KeyDate],
        settings: ReminderSettings,
        answered: Set<String> = [],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [PlannedReminder] {
        guard settings.isEnabled else { return [] }
        var reminders: [PlannedReminder] = []
        for keyDate in keyDates {
            guard let name = keyDate.person?.displayName else { continue }
            let rules = keyDate.reminderRules(settings: settings)
            guard !rules.isEmpty else { continue }
            // This occurrence and the one after: a reminder for this one may
            // already have passed while one for the next is due sooner (a
            // month-ahead reminder for a date that's next week, say).
            let first = keyDate.nextOccurrence(after: now, calendar: calendar)
            guard let dayAfterFirst = calendar.date(byAdding: .day, value: 1, to: first) else { continue }
            let second = keyDate.nextOccurrence(after: dayAfterFirst, calendar: calendar)
            for occurrence in [first, second] {
                let key = occurrenceKey(keyDate, occurrence, calendar: calendar)
                for rule in rules {
                    reminders += self.reminders(
                        for: rule, keyDate: keyDate, name: name, occurrence: occurrence,
                        key: key, isAnswered: answered.contains(key), calendar: calendar
                    )
                }
            }
        }
        let upcoming = reminders.filter { $0.fireDate > now }.sorted { $0.fireDate < $1.fireDate }
        guard upcoming.count > limit else { return upcoming }

        // Too many to queue. Keep the soonest and make the last one ask for
        // the app to be opened, so later reminders aren't lost unnoticed.
        var kept = Array(upcoming.prefix(limit - 1))
        let lastDate = kept.last?.fireDate ?? now
        kept.append(PlannedReminder(
            title: "Keep Your Reminders Coming",
            body: "Open Relatery so it can schedule the reminders after this one.",
            fireDate: lastDate.addingTimeInterval(60),
            kind: .safetyNet
        ))
        return kept
    }

    /// One rule's reminder for one occurrence, plus its follow-ups.
    private static func reminders(
        for rule: ReminderRule,
        keyDate: KeyDate,
        name: String,
        occurrence: Date,
        key: String,
        isAnswered: Bool,
        calendar: Calendar
    ) -> [PlannedReminder] {
        guard let day = calendar.date(byAdding: .day, value: -rule.daysBefore, to: occurrence),
              let fireDate = calendar.date(byAdding: .minute, value: rule.minutesAfterMidnight, to: day) else { return [] }
        let body = body(for: keyDate, occurrence: occurrence, lead: rule.daysBefore, calendar: calendar)
        let reminder = PlannedReminder(
            title: name, body: body, fireDate: fireDate, loudness: rule.loudness,
            occurrenceKey: key, asksForReady: rule.asksForReady && !isAnswered
        )
        guard reminder.asksForReady else { return [reminder] }

        // Follow-ups: a day apart while there's time, two hours apart once
        // the date is close. None after the date has begun (or, for an
        // on-the-day reminder, after it's over).
        let spacing: DateComponents = rule.daysBefore >= 2 ? DateComponents(day: 1) : DateComponents(hour: 2)
        let cutoff = rule.daysBefore == 0 ? calendar.date(byAdding: .day, value: 1, to: occurrence) ?? occurrence : occurrence
        var followUps: [PlannedReminder] = []
        var date = fireDate
        for _ in 0..<followUpCount {
            guard let next = calendar.date(byAdding: spacing, to: date), next < cutoff else { break }
            date = next
            followUps.append(PlannedReminder(
                title: name, body: body, fireDate: next, loudness: rule.loudness,
                kind: .followUp, occurrenceKey: key, asksForReady: true
            ))
        }
        return [reminder] + followUps
    }

    /// "<date key>@2026-11-02": one occurrence of one date.
    static func occurrenceKey(_ keyDate: KeyDate, _ occurrence: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: occurrence)
        return String(format: "%@@%04d-%02d-%02d", keyDate.reminderKey, parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
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
        case 21: when = "in 3 weeks, on \(occurrence.formatted(style))"
        default: when = "in \(lead) days, on \(occurrence.formatted(style))"
        }
        var text = "\(keyDate.title) \(when)"
        if let milestone = keyDate.milestoneText(on: occurrence, calendar: calendar) {
            text += " · \(milestone)"
        }
        return text
    }
}
