import Foundation
import Observation
import UserNotifications
import os

/// Hands the planned reminders to iOS, and listens for the user tapping one.
///
/// Reminders are local notifications: the phone delivers them itself, with no
/// server involved, even when the app isn't running.
@Observable
final class ReminderScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderScheduler()

    /// Whether iOS will let the app show notifications.
    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    /// Set when a reminder is tapped; the root view shows Upcoming and clears it.
    var didOpenFromReminder = false

    private let center = UNUserNotificationCenter.current()
    private let log = Logger(subsystem: "Relatery", category: "Reminders")

    /// Call once at launch, so taps on a reminder reach the app.
    func start() {
        center.delegate = self
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
        center.removeAllPendingNotificationRequests()
        guard authorization == .authorized || authorization == .provisional else { return }

        let plan = ReminderPlanner.plan(for: keyDates, settings: settings)
        for (index, reminder) in plan.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: "reminder-\(index)", content: content, trigger: trigger))
            } catch {
                log.error("Couldn't schedule a reminder: \(error.localizedDescription)")
            }
        }
        log.info("Scheduled \(plan.count) reminders")
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
        await MainActor.run { didOpenFromReminder = true }
    }
}
