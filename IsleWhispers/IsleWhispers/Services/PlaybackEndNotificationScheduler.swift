import UserNotifications

@MainActor
protocol PlaybackEndNotificationScheduling: AnyObject {
    func requestAuthorization()
    func schedulePlaybackEnd(at deadline: Date)
    func cancelPlaybackEnd()
}

@MainActor
final class LocalPlaybackEndNotificationScheduler: PlaybackEndNotificationScheduling {
    static let requestIdentifier = "isleWhispers.playbackEnded"
    static let notificationTitle = "播放已结束"

    private let center: UNUserNotificationCenter
    private var generation: UUID?

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func schedulePlaybackEnd(at deadline: Date) {
        let token = UUID()
        generation = token
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            Task { @MainActor in
                guard let self, granted, self.generation == token else { return }
                let content = UNMutableNotificationContent()
                content.title = Self.notificationTitle
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: max(deadline.timeIntervalSinceNow, 1),
                    repeats: false
                )
                self.center.add(
                    UNNotificationRequest(
                        identifier: Self.requestIdentifier,
                        content: content,
                        trigger: trigger
                    )
                )
            }
        }
    }

    func cancelPlaybackEnd() {
        generation = nil
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
    }
}
