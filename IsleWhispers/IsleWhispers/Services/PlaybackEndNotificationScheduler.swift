import UserNotifications

@MainActor
protocol PlaybackEndNotificationScheduling: AnyObject {
    func requestAuthorization()
    func schedulePlaybackEnd(at deadline: Date)
    func cancelPlaybackEnd()
}

@MainActor
protocol PlaybackEndUserNotificationCenter: AnyObject {
    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping @Sendable (Bool, Error?) -> Void
    )
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?
    )
}

extension UNUserNotificationCenter: PlaybackEndUserNotificationCenter {}

@MainActor
final class LocalPlaybackEndNotificationScheduler: PlaybackEndNotificationScheduling {
    static let requestIdentifier = "isleWhispers.playbackEnded"

    private let center: PlaybackEndUserNotificationCenter
    private let localizationBundle: Bundle
    private var generation: UUID?

    init(
        center: PlaybackEndUserNotificationCenter = UNUserNotificationCenter.current(),
        localizationBundle: Bundle = .main
    ) {
        self.center = center
        self.localizationBundle = localizationBundle
    }

    static func notificationTitle(bundle: Bundle = .main) -> String {
        L10n.text("notification.playback_ended.title", bundle: bundle)
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
                content.title = Self.notificationTitle(bundle: self.localizationBundle)
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
                    ),
                    withCompletionHandler: nil
                )
            }
        }
    }

    func cancelPlaybackEnd() {
        generation = nil
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
    }
}
