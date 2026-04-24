import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let dailyReminderIdentifier = "daily-focus-reminder"
    private let countdownReminderPrefix = "countdown-event-reminder-"

    /// 注册为 UNUserNotificationCenter delegate，确保前台也能显示通知横幅
    func setup() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// 检查权限状态后再调度，避免首次安装时的异步竞争
    func scheduleIfAuthorized(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self?.scheduleDailyReminder(hour: hour, minute: minute)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    guard granted else { return }
                    self?.scheduleDailyReminder(hour: hour, minute: minute)
                }
            default:
                // 用户已明确拒绝，不做任何操作
                break
            }
        }
    }

    func scheduleDailyReminder(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.focus.title", comment: "")
        content.body = NSLocalizedString("notification.focus.body", comment: "")
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: dailyReminderIdentifier, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])
    }

    func scheduleCountdownReminderIfAuthorized(eventID: UUID, title: String, date: Date) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self?.scheduleCountdownReminder(eventID: eventID, title: title, date: date)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    guard granted else { return }
                    self?.scheduleCountdownReminder(eventID: eventID, title: title, date: date)
                }
            default:
                break
            }
        }
    }

    func scheduleCountdownReminder(eventID: UUID, title: String, date: Date) {
        let center = UNUserNotificationCenter.current()
        let identifier = countdownReminderIdentifier(for: eventID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.countdown.today.title", comment: "")
        content.body = String(format: NSLocalizedString("notification.countdown.today.body", comment: ""), title)
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelCountdownReminder(eventID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [countdownReminderIdentifier(for: eventID)]
        )
    }

    func cancelAllCountdownReminders(completion: (() -> Void)? = nil) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { [countdownReminderPrefix] requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(countdownReminderPrefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
            completion?()
        }
    }

    private func countdownReminderIdentifier(for eventID: UUID) -> String {
        countdownReminderPrefix + eventID.uuidString
    }
}
