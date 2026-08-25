import AVFoundation
import MediaPlayer
import UIKit

extension Notification.Name {
    static let audioPlayerStateDidChange = Notification.Name("audioPlayerStateDidChange")
}

@MainActor
final class AudioPlayerService: NSObject, AVAudioPlayerDelegate {
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
    private var sleepTimer: Timer?
    private var wasPlayingBeforeInterruption = false

    init(
        defaults: UserDefaults = .standard,
        configureSystemIntegration: Bool = true
    ) {
        let restoredIndex = defaults.object(forKey: Self.selectedSoundDefaultsKey) as? Int
        let selectedIndex = restoredIndex.flatMap { Sound.catalog.indices.contains($0) ? $0 : nil } ?? 2

        self.defaults = defaults
        self.configureSystemIntegration = configureSystemIntegration
        state = PlaybackState(selectedIndex: selectedIndex, isPlaying: false)
        super.init()

        prepareSelectedSound()

        if configureSystemIntegration {
            configureAudioSession()
            observeSystemNotifications()
            registerRemoteCommands()
            updateNowPlayingInfo()
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
        if player == nil {
            prepareSelectedSound()
        }

        guard let player else {
            state.isPlaying = false
            publishState()
            return
        }

        if configureSystemIntegration {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                state.isPlaying = false
                statusMessage = "音频会话不可用"
                publishState()
                return
            }
        }

        state.isPlaying = player.play()
        statusMessage = state.isPlaying ? "准备就绪" : "音频播放失败"
        publishState()
    }

    func pause() {
        player?.pause()
        state.isPlaying = false
        publishState()
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

    func setSleepTimer(_ option: SleepTimerOption) {
        sleepTimer?.invalidate()

        let now = Date()
        sleepTimerState.schedule(option, now: now)
        if let deadline = sleepTimerState.deadline {
            armSleepTimer(after: deadline.timeIntervalSince(now))
        }
        publishState()
    }

    func reconcileSleepTimer() {
        sleepTimer?.invalidate()

        let now = Date()
        if sleepTimerState.isExpired(at: now) {
            sleepTimerState.schedule(.unlimited, now: now)
            pause()
        } else if let deadline = sleepTimerState.deadline {
            armSleepTimer(after: deadline.timeIntervalSince(now))
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        self.player = nil
        state.isPlaying = false
        statusMessage = "音频解码失败"
        publishState()
    }

    private func prepareSelectedSound() {
        player?.stop()
        player = nil
        state.isPlaying = false

        let url = Bundle.main.url(
            forResource: currentSound.audioResource,
            withExtension: "caf",
            subdirectory: "Audio"
        ) ?? Bundle.main.url(forResource: currentSound.audioResource, withExtension: "caf")

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

    private func observeSystemNotifications() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        center.addObserver(
            self,
            selector: #selector(handleAudioRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    private func registerRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.performOnMainActor { $0.play() }
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.performOnMainActor { $0.pause() }
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.performOnMainActor { $0.togglePlayback() }
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.performOnMainActor { $0.previous() }
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.performOnMainActor { $0.next() }
            return .success
        }
    }

    nonisolated private func performOnMainActor(_ action: @escaping @MainActor (AudioPlayerService) -> Void) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            action(self)
        }
    }

    private func publishState() {
        if configureSystemIntegration {
            updateNowPlayingInfo()
        }
        NotificationCenter.default.post(name: .audioPlayerStateDidChange, object: self)
    }

    private func updateNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: currentSound.title,
            MPMediaItemPropertyArtist: currentSound.subtitle,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
    }

    @objc private func handleDidBecomeActive() {
        reconcileSleepTimer()
    }

    @objc private func handleSleepTimerFired() {
        reconcileSleepTimer()
    }

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else { return }

        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            pause()
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            if wasPlayingBeforeInterruption, options.contains(.shouldResume) {
                play()
            }
            wasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    @objc private func handleAudioRouteChange(_ notification: Notification) {
        guard
            let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable
        else { return }

        pause()
    }
}
