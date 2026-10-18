import Foundation
import Observation
import UserNotifications
import BackgroundTasks
import SwiftData
import os

/// Hands the planned reminders to iOS, and listens for the user tapping one.
///
/// Reminders are local notifications (and, for those set to Alarm, AlarmKit
/// alarms): the phone delivers them itself, with no server involved, even
/// when the app isn't running.
@Observable
final class ReminderScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderScheduler()

    /// The background task that tops up the queue between app launches.
    /// Also listed under BGTaskSchedulerPermittedIdentifiers in Info.plist.
    static let refreshTaskID = "com.david.Relatery.refreshReminders"

    /// Whether iOS will let the app show notifications.
    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    /// Set when a reminder is tapped; the root view shows Upcoming and clears it.
    var didOpenFromReminder = false

    private let center = UNUserNotificationCenter.current()
    private let log = Logger(subsystem: "Relatery", category: "Reminders")

    // Notification buttons for reminders that keep coming back.
    private enum Action {
        static let category = "keepReminding"
        static let ready = "ready"
        static let later = "later"
    }
    /// Snoozed reminders survive the queue being rebuilt; everything else
    /// is replaced.
    private static let snoozePrefix = "snooze-"
    nonisolated private static let occurrenceInfoKey = "occurrence"
    private static let followUpInfoKey = "followUp"

    /// Call once at launch, so taps on a reminder reach the app.
    func start() {
        center.delegate = self
        let ready = UNNotificationAction(identifier: Action.ready, title: "I’m Ready", options: [])
        let later = UNNotificationAction(identifier: Action.later, title: "Remind Me in 1 Hour", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Action.category, actions: [ready, later], intentIdentifiers: [])
        ])
    }

    func refreshAuthorization() async {
        authorization = await center.notificationSettings().authorizationStatus
    }

    /// Shows the system permission prompt the first time; afterwards iOS
    /// answers with the earlier choice. Returns whether reminders can be shown.
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        await refreshAuthorization()
        return granted
    }

    /// Replaces everything that's waiting with a fresh plan. Clearing first
    /// keeps this simple: there's never an old reminder to hunt down after a
    /// date is edited or a relationship deleted.
    func reschedule(for keyDates: [KeyDate], settings: ReminderSettings) async {
        await refreshAuthorization()
        let plan = ReminderPlanner.plan(for: keyDates, settings: settings, answered: ReminderAnswers.all())

        // Alarms first: any that can't be set (no permission, or AlarmKit's
        // limit) go out as Time Sensitive notifications instead.
        let alarms = plan.filter { $0.loudness == .alarm }
        let unscheduledAlarms = await ReminderAlarms.replace(with: alarms)
        let notifications = (plan.filter { $0.loudness != .alarm } + unscheduledAlarms)
            .sorted { $0.fireDate < $1.fireDate }

        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { !$0.hasPrefix(Self.snoozePrefix) })
        if authorization == .authorized || authorization == .provisional {
            for (index, reminder) in notifications.enumerated() {
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                await add(UNNotificationRequest(identifier: "reminder-\(index)", content: content(for: reminder), trigger: trigger))
                log.debug("Notification \(reminder.fireDate) \(reminder.loudness.rawValue) \(String(describing: reminder.kind)) ready=\(reminder.asksForReady): \(reminder.title), \(reminder.body)")
            }
            log.info("Scheduled \(notifications.count) notifications")
        }
        await Self.requestBackgroundRefresh()
    }

    /// Rebuilds the queue while the app is in the background, so reminders
    /// keep coming even if it isn't opened for a long while.
    func refreshInBackground(container: ModelContainer) async {
        let context = ModelContext(container)
        guard let keyDates = try? context.fetch(FetchDescriptor<KeyDate>()) else { return }
        await reschedule(for: keyDates, settings: .stored())
    }

    /// Asks iOS to wake the app in about half a day. iOS decides when, or
    /// whether; the safety-net reminder covers the case where it doesn't.
    static func requestBackgroundRefresh() async {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = .now.addingTimeInterval(12 * 60 * 60)
        do {
            if #available(iOS 27, *) {
                try await BGTaskScheduler.shared.submitTaskRequest(request)
            } else {
                try BGTaskScheduler.shared.submit(request)
            }
        } catch {
            // Expected in the Simulator, which doesn't run background tasks.
            Logger(subsystem: "Relatery", category: "Reminders").info("Background refresh not scheduled: \(error.localizedDescription)")
        }
    }

    private func content(for reminder: PlannedReminder) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        if reminder.loudness >= .timeSensitive {
            content.interruptionLevel = .timeSensitive
        }
        if reminder.asksForReady {
            content.categoryIdentifier = Action.category
        }
        if let key = reminder.occurrenceKey {
            content.userInfo = [Self.occurrenceInfoKey: key, Self.followUpInfoKey: reminder.kind == .followUp]
        }
        return content
    }

    private func add(_ request: UNNotificationRequest) async {
        do {
            try await center.add(request)
        } catch {
            log.error("Couldn't schedule a reminder: \(error.localizedDescription)")
        }
    }

    // MARK: - Answering a reminder

    /// "I'm Ready": no more follow-ups or snoozes for this occurrence, now
    /// or after the queue is rebuilt. Later reminders from other rules still
    /// come.
    private func markReady(_ occurrenceKey: String) async {
        ReminderAnswers.markReady(occurrenceKey)
        let pending = await center.pendingNotificationRequests()
        let repeats = pending.filter {
            $0.content.userInfo[Self.occurrenceInfoKey] as? String == occurrenceKey
                && ($0.content.userInfo[Self.followUpInfoKey] as? Bool == true || $0.identifier.hasPrefix(Self.snoozePrefix))
        }
        center.removePendingNotificationRequests(withIdentifiers: repeats.map(\.identifier))
    }

    /// "Remind Me in 1 Hour": the same reminder again, an hour from now.
    private func snooze(_ content: UNNotificationContent) async {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60, repeats: false)
        await add(UNNotificationRequest(identifier: Self.snoozePrefix + UUID().uuidString, content: content, trigger: trigger))
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Without this, a reminder that arrives while the app is open is not shown.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let content = response.notification.request.content
        let occurrenceKey = content.userInfo[Self.occurrenceInfoKey] as? String
        switch response.actionIdentifier {
        case Action.ready:
            if let occurrenceKey { await markReady(occurrenceKey) }
        case Action.later:
            await snooze(content)
        default:
            await MainActor.run { didOpenFromReminder = true }
        }
    }
}
