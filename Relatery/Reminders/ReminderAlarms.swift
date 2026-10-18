import AlarmKit
import SwiftUI
import os

/// Reminders set to Alarm, handed to AlarmKit. An alarm rings through Silent
/// mode and Focus and shows full screen, like the Clock app; it rings until
/// it's stopped, so it has no "I'm Ready" or snooze.
///
/// A snooze ("Repeat") button would need a countdown presentation, which in
/// turn needs a widget extension; without one, Apple warns, the system may
/// dismiss alarms and fail to alert.
enum ReminderAlarms {
    private static let manager = AlarmManager.shared
    private static let log = Logger(subsystem: "Relatery", category: "Alarms")

    static var authorization: AlarmManager.AuthorizationState {
        manager.authorizationState
    }

    /// The user said no to alarms (they can change it in Settings).
    static var isDenied: Bool { authorization == .denied }

    /// Nobody has been asked yet.
    static var canAsk: Bool { authorization == .notDetermined }

    /// Shows the system prompt the first time; afterwards iOS answers with
    /// the earlier choice.
    static func requestAuthorization() async -> Bool {
        (try? await manager.requestAuthorization()) == .authorized
    }

    /// Cancels Relatery's waiting alarms and schedules these instead.
    /// Returns the ones that couldn't be scheduled, so they can go out as
    /// Time Sensitive notifications rather than not at all.
    static func replace(with reminders: [PlannedReminder]) async -> [PlannedReminder] {
        // Only alarms still waiting: one ringing right now is left alone.
        for alarm in (try? manager.alarms) ?? [] where alarm.state == .scheduled {
            try? manager.cancel(id: alarm.id)
        }
        // Permission is only ever asked for from the screens where alarms
        // are chosen. Asking here as well, while one of those prompts is
        // up, makes AlarmKit refuse both.
        guard authorization == .authorized else { return reminders }

        for (index, reminder) in reminders.enumerated() {
            let alert = alertPresentation(title: LocalizedStringResource("\(reminder.title): \(reminder.body)"))
            let attributes = AlarmAttributes<ReminderAlarmMetadata>(
                presentation: AlarmPresentation(alert: alert),
                tintColor: Theme.plum
            )
            do {
                _ = try await manager.schedule(id: UUID(), configuration: .alarm(schedule: .fixed(reminder.fireDate), attributes: attributes))
                log.debug("Alarm \(reminder.fireDate): \(reminder.title), \(reminder.body)")
            } catch {
                log.error("Couldn't schedule an alarm: \(error.localizedDescription)")
                return Array(reminders[index...])
            }
        }
        log.info("Scheduled \(reminders.count) alarms")
        return []
    }
}

extension ReminderAlarms {
    /// iOS 26.0 needs a Stop button described by the app; from 26.1 the
    /// system provides its own and that initialiser is deprecated.
    fileprivate static func alertPresentation(title: LocalizedStringResource) -> AlarmPresentation.Alert {
        if #available(iOS 26.1, *) {
            return AlarmPresentation.Alert(title: title)
        } else {
            return AlarmPresentation.Alert(
                title: title,
                stopButton: AlarmButton(text: "Stop", textColor: Theme.cream, systemImageName: "stop.circle")
            )
        }
    }
}

/// AlarmKit needs a metadata type; Relatery's alarms carry none.
struct ReminderAlarmMetadata: AlarmMetadata {}
