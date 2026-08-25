import AVFoundation
import MediaPlayer
import UIKit

extension Notification.Name {
    static let audioPlayerStateDidChange = Notification.Name("audioPlayerStateDidChange")
}

enum AudioPlayerRemoteCommand: Sendable {
    case play
    case pause
    case togglePlayback
    case previous
    case next
}

@MainActor
final class AudioPlayerService: NSObject, AVAudioPlayerDelegate {
    private nonisolated struct RemoteCommandRegistration {
        let command: MPRemoteCommand
        let target: Any
    }

    static let shared = AudioPlayerService()
    static let selectedSoundDefaultsKey = "selectedSoundIndex"

    private(set) var state: PlaybackState
    private(set) var sleepTimerState = SleepTimerState()
    private var player: AVAudioPlayer?
    private(set) var statusMessage = "准备就绪"

    var selectedIndex: Int { state.selectedIndex }
    var currentSound: Sound { Sound.catalog[selectedIndex] }
    var isPlaying: Bool { state.isPlaying }
    var sleepTimerOption: SleepTimerOption { sleepTimerState.option }

    private let defaults: UserDefaults
    private let configureSystemIntegration: Bool
    private let resourceBundle: Bundle
    private let notificationCenter: NotificationCenter
    private let nowProvider: () -> Date
    private let shouldObserveSystemNotifications: Bool
    private var sleepTimer: Timer?
    private var shouldResumeAfterInterruption = false
    private(set) var ownsPlaybackSession = false
    private(set) var audioSessionIsActive = false
    private var systemNotificationObservers: [NSObjectProtocol] = []
    private var remoteCommandRegistrations: [RemoteCommandRegistration] = []

    init(
        defaults: UserDefaults = .standard,
        configureSystemIntegration: Bool = true,
        resourceBundle: Bundle = .main,
        notificationCenter: NotificationCenter = .default,
        observeSystemNotifications: Bool? = nil,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        let restoredIndex = defaults.object(forKey: Self.selectedSoundDefaultsKey) as? Int
        let selectedIndex = restoredIndex.flatMap { Sound.catalog.indices.contains($0) ? $0 : nil } ?? 2

        self.defaults = defaults
        self.configureSystemIntegration = configureSystemIntegration
        self.resourceBundle = resourceBundle
        self.notificationCenter = notificationCenter
        self.shouldObserveSystemNotifications =
            observeSystemNotifications ?? configureSystemIntegration
        self.nowProvider = nowProvider
        state = PlaybackState(selectedIndex: selectedIndex, isPlaying: false)
        super.init()

        prepareSelectedSound()

        if shouldObserveSystemNotifications {
            registerSystemNotificationObservers()
        }
        if configureSystemIntegration {
            configureAudioSession()
            registerRemoteCommands()
        }
    }

    deinit {
        sleepTimer?.invalidate()
        for observer in systemNotificationObservers {
            notificationCenter.removeObserver(observer)
        }
        for registration in remoteCommandRegistrations {
            registration.command.removeTarget(registration.target)
        }
    }

    func selectSound(at index: Int) {
        let shouldContinue = isPlaying
        state.select(index: index, count: Sound.catalog.count)
        defaults.set(selectedIndex, forKey: Self.selectedSoundDefaultsKey)
        prepareSelectedSound()
        if shouldContinue { play() }
        publishState()
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func play() {
        _ = attemptPlay()
    }

    @discardableResult
    private func attemptPlay(preservingInterruptionIntent: Bool = false) -> Bool {
        if !preservingInterruptionIntent {
            shouldResumeAfterInterruption = false
        }
        guard !expireSleepTimerIfNeeded() else { return false }

        if player == nil {
            prepareSelectedSound()
        }

        guard let player else {
            state.isPlaying = false
            releaseSystemPlaybackOwnership()
            publishState()
            return false
        }

        if configureSystemIntegration {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                audioSessionIsActive = true
            } catch {
                state.isPlaying = false
                statusMessage = "音频会话不可用"
                releaseSystemPlaybackOwnership()
                publishState()
                return false
            }
        }

        state.isPlaying = player.play()
        statusMessage = state.isPlaying ? "准备就绪" : "音频播放失败"
        if state.isPlaying {
            ownsPlaybackSession = true
        } else {
            releaseSystemPlaybackOwnership()
        }
        publishState()
        return state.isPlaying
    }

    func pause() {
        stopPlayback(releasingSystemOwnership: true, cancellingInterruptionResume: true)
    }

    func previous() {
        selectSound(at: selectedIndex - 1)
    }

    func next() {
        selectSound(at: selectedIndex + 1)
    }

    func retry() {
        prepareSelectedSound()
        publishState()
    }

    func performRemoteCommand(_ command: AudioPlayerRemoteCommand) -> MPRemoteCommandHandlerStatus {
        switch command {
        case .play:
            play()
            return playbackCommandStatus()
        case .pause:
            pause()
            return .success
        case .togglePlayback:
            let shouldPlay = !isPlaying
            togglePlayback()
            return shouldPlay ? playbackCommandStatus() : .success
        case .previous:
            return performSelectionCommand(previous)
        case .next:
            return performSelectionCommand(next)
        }
    }

    nonisolated func handleRemoteCommand(_ command: AudioPlayerRemoteCommand) -> MPRemoteCommandHandlerStatus {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                performRemoteCommand(command)
            }
        }

        return DispatchQueue.main.sync {
            performRemoteCommand(command)
        }
    }

    func setSleepTimer(_ option: SleepTimerOption) {
        sleepTimer?.invalidate()

        let now = nowProvider()
        sleepTimerState.schedule(option, now: now)
        if let deadline = sleepTimerState.deadline {
            armSleepTimer(after: deadline.timeIntervalSince(now))
        }
        publishState()
    }

    func reconcileSleepTimer() {
        sleepTimer?.invalidate()

        let now = nowProvider()
        if sleepTimerState.isExpired(at: now) {
            sleepTimerState.schedule(.unlimited, now: now)
            stopPlayback(releasingSystemOwnership: true, cancellingInterruptionResume: true)
        } else if let deadline = sleepTimerState.deadline {
            armSleepTimer(after: deadline.timeIntervalSince(now))
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        self.player = nil
        state.isPlaying = false
        statusMessage = "音频解码失败"
        shouldResumeAfterInterruption = false
        releaseSystemPlaybackOwnership()
        publishState()
    }

    private func prepareSelectedSound() {
        player?.stop()
        player = nil
        state.isPlaying = false

        let url = resourceBundle.url(
            forResource: currentSound.audioResource,
            withExtension: "caf",
            subdirectory: "Audio"
        ) ?? resourceBundle.url(forResource: currentSound.audioResource, withExtension: "caf")

        guard let url else {
            statusMessage = "音频资源不可用"
            return
        }

        do {
            let preparedPlayer = try AVAudioPlayer(contentsOf: url)
            preparedPlayer.delegate = self
            preparedPlayer.numberOfLoops = -1
            guard preparedPlayer.prepareToPlay() else {
                statusMessage = "音频解码失败"
                return
            }
            player = preparedPlayer
            statusMessage = "准备就绪"
        } catch {
            statusMessage = "音频解码失败"
        }
    }

    private func performSelectionCommand(_ action: () -> Void) -> MPRemoteCommandHandlerStatus {
        let shouldContinuePlaying = isPlaying
        action()
        guard player != nil else { return .noSuchContent }
        return shouldContinuePlaying && !isPlaying ? .commandFailed : .success
    }

    private func playbackCommandStatus() -> MPRemoteCommandHandlerStatus {
        guard player != nil else { return .noSuchContent }
        return isPlaying ? .success : .commandFailed
    }

    private func armSleepTimer(after interval: TimeInterval) {
        sleepTimer = Timer.scheduledTimer(
            timeInterval: max(interval, 0),
            target: self,
            selector: #selector(handleSleepTimerFired),
            userInfo: nil,
            repeats: false
        )
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        } catch {
            statusMessage = "音频会话不可用"
        }
    }

    private func registerSystemNotificationObservers() {
        let notificationObject: Any? = configureSystemIntegration
            ? AVAudioSession.sharedInstance()
            : nil
        systemNotificationObservers.append(notificationCenter.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.reconcileSleepTimer()
            }
        })
        systemNotificationObservers.append(notificationCenter.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: notificationObject,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.handleAudioSessionInterruption(notification)
            }
        })
        systemNotificationObservers.append(notificationCenter.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: notificationObject,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.handleAudioRouteChange(notification)
            }
        })
    }

    private func registerRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        register(commandCenter.playCommand, action: .play)
        register(commandCenter.pauseCommand, action: .pause)
        register(commandCenter.togglePlayPauseCommand, action: .togglePlayback)
        register(commandCenter.previousTrackCommand, action: .previous)
        register(commandCenter.nextTrackCommand, action: .next)
    }

    private func register(_ command: MPRemoteCommand, action: AudioPlayerRemoteCommand) {
        let target = command.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            return self.handleRemoteCommand(action)
        }
        remoteCommandRegistrations.append(.init(command: command, target: target))
    }

    private func publishState() {
        if configureSystemIntegration, ownsPlaybackSession {
            updateNowPlayingInfo()
        }
        notificationCenter.post(name: .audioPlayerStateDidChange, object: self)
    }

    private func updateNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: currentSound.title,
            MPMediaItemPropertyArtist: currentSound.subtitle,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
    }

    @objc private func handleSleepTimerFired() {
        reconcileSleepTimer()
    }

    func handleAudioSessionInterruption(_ notification: Notification) {
        guard
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else { return }

        switch type {
        case .began:
            shouldResumeAfterInterruption = isPlaying
            stopPlayback(
                releasingSystemOwnership: false,
                cancellingInterruptionResume: false
            )
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            let shouldResume = shouldResumeAfterInterruption && options.contains(.shouldResume)
            guard !expireSleepTimerIfNeeded() else { return }
            shouldResumeAfterInterruption = false
            if shouldResume {
                _ = attemptPlay(preservingInterruptionIntent: true)
            } else {
                releaseSystemPlaybackOwnership()
            }
        @unknown default:
            break
        }
    }

    func handleAudioRouteChange(_ notification: Notification) {
        guard
            let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable
        else { return }

        stopPlayback(releasingSystemOwnership: true, cancellingInterruptionResume: true)
    }

    @discardableResult
    private func expireSleepTimerIfNeeded() -> Bool {
        let now = nowProvider()
        guard sleepTimerState.isExpired(at: now) else { return false }

        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerState.schedule(.unlimited, now: now)
        stopPlayback(releasingSystemOwnership: true, cancellingInterruptionResume: true)
        return true
    }

    private func stopPlayback(
        releasingSystemOwnership: Bool,
        cancellingInterruptionResume: Bool
    ) {
        player?.pause()
        state.isPlaying = false
        if cancellingInterruptionResume {
            shouldResumeAfterInterruption = false
        }
        if releasingSystemOwnership {
            releaseSystemPlaybackOwnership()
        }
        publishState()
    }

    private func releaseSystemPlaybackOwnership() {
        ownsPlaybackSession = false
        guard configureSystemIntegration else { return }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        guard audioSessionIsActive else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            // A system interruption can already have deactivated the session.
        }
        audioSessionIsActive = false
    }
}
