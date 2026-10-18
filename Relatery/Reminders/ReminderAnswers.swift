import Foundation

/// The occurrences the user has answered with "I'm Ready", so their
/// follow-ups stop — including after the queue is rebuilt from scratch.
/// Kept in UserDefaults as occurrence key → when it was answered.
enum ReminderAnswers {
    private static let key = "reminderAnswers"

    static func all(in defaults: UserDefaults = .standard) -> Set<String> {
        Set(stored(in: defaults).keys)
    }

    static func markReady(_ occurrenceKey: String, in defaults: UserDefaults = .standard) {
        var answers = stored(in: defaults)
        answers[occurrenceKey] = Date.now.timeIntervalSince1970
        // An answer only matters until its occurrence is over; drop any older
        // than a year so the list doesn't grow forever.
        let yearAgo = Date.now.addingTimeInterval(-366 * 24 * 60 * 60).timeIntervalSince1970
        defaults.set(answers.filter { $0.value > yearAgo }, forKey: key)
    }

    private static func stored(in defaults: UserDefaults) -> [String: Double] {
        defaults.dictionary(forKey: key) as? [String: Double] ?? [:]
    }
}
