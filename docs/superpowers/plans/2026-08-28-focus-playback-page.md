# Focus Playback Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a full-screen iPhone focus playback page that starts from Home, synchronizes audio with a pausable 15/30/60-minute countdown, switches sounds through a half-sheet library, and sends one local notification when a finite countdown ends.

**Architecture:** Keep `AudioPlayerService` as the only owner of selected sound, playback, and sleep-timer state. Extend its timer state machine to preserve exact paused remaining time and an explicit expired state, inject one local-notification scheduler into the service, and render those shared states from a new `FocusPlaybackViewController`; Home remains the presentation and recent-history coordinator.

**Tech Stack:** Swift 5, UIKit, Auto Layout, SnapKit 5.7 through CocoaPods, AVFoundation, MediaPlayer, UserNotifications, XCTest, iOS 15+

**Spec:** `docs/superpowers/specs/2026-08-28-focus-playback-page-design.md`

## Global Constraints

- Minimum deployment target remains iOS 15.0.
- The application supports iPhone only and `UIInterfaceOrientationPortrait` only.
- Use UIKit and programmatic SnapKit constraints; do not add another dependency.
- Keep one shared `AudioPlayerService`; do not create another audio player or persist the focus-session countdown.
- Keep all 15 existing CAF sounds and matching PNG backgrounds without renaming them.
- Keep `AVAudioPlayer.numberOfLoops = -1` and existing background/Now Playing integration.
- Countdown choices remain exactly unlimited, 15, 30, and 60 minutes.
- Home and Library must still show no audio progress, elapsed duration, or total duration; only the focus page may show the approved countdown.
- A paused finite countdown preserves exact seconds and schedules no notification until playback resumes.
- Closing the focus page pauses audio, clears the timer to unlimited, cancels notification delivery, and keeps the selected sound.
- Preserve unrelated working-tree changes and use explicit `git add` paths for every commit.

---

## File Map

### Countdown and notification domain

- Modify `IsleWhispers/IsleWhispers/Playback/PlaybackState.swift`: replace the deadline-only sleep timer with explicit unlimited, running, paused, and expired phases.
- Create `IsleWhispers/IsleWhispers/Services/PlaybackEndNotificationScheduler.swift`: request notification authorization and maintain one pending “播放已结束” request.
- Modify `IsleWhispers/IsleWhispers/Services/AudioPlayerService.swift`: synchronize play/pause, exact remaining time, timer expiry, and notification scheduling.
- Modify `IsleWhispers/IsleWhispers/AppDelegate.swift`: install the notification-center delegate and allow foreground banner/sound presentation.

### Focus playback UI and coordination

- Create `IsleWhispers/IsleWhispers/ViewControllers/FocusPlaybackViewController.swift`: full-screen artwork, title, countdown picker, play/pause/close controls, and half-sheet sound picker.
- Modify `IsleWhispers/IsleWhispers/ViewControllers/HomeViewController.swift`: make the central button start if needed and present the focus page; route sheet selection through the existing single selection/recent flow.

### Tests

- Modify `IsleWhispersTests/PlaybackStateTests.swift`: pure countdown phase and exact-time tests.
- Modify `IsleWhispersTests/AudioPlayerPersistenceTests.swift`: service timer/remote-control/notification scheduling tests and updated expired-state expectations.
- Create `IsleWhispersTests/PlaybackEndNotificationSchedulerTests.swift`: scheduler constants and foreground notification options.
- Create `IsleWhispersTests/FocusPlaybackViewControllerTests.swift`: layout, countdown rendering, controls, close cleanup, and sound-sheet behavior.
- Modify `IsleWhispersTests/HomeViewControllerTests.swift`: Home entry, autoplay, already-playing presentation, and recent-sound coordination.

The project uses `PBXFileSystemSynchronizedRootGroup`, so newly created Swift files are discovered automatically; do not edit `project.pbxproj` for file membership.

---

### Task 1: Exact pausable countdown state machine

**Files:**
- Modify: `IsleWhispers/IsleWhispers/Playback/PlaybackState.swift`
- Modify: `IsleWhispersTests/PlaybackStateTests.swift`

**Interfaces:**
- Consumes: existing `SleepTimerOption` cases `.unlimited`, `.minutes15`, `.minutes30`, `.minutes60`.
- Produces: `SleepTimerPhase`, `SleepTimerState.phase`, `deadline`, `remainingTime(at:)`, `pause(at:)`, `resume(at:)`, and `expireIfNeeded(at:)`.

- [ ] **Step 1: Write failing phase-transition tests**

Append these tests to `PlaybackStateTests`:

```swift
func testFiniteSleepTimerPausesAndResumesWithExactRemainingTime() {
    let start = Date(timeIntervalSince1970: 1_000)
    var state = SleepTimerState()

    state.schedule(.minutes15, now: start)
    XCTAssertEqual(state.phase, .running(deadline: start.addingTimeInterval(900)))
    XCTAssertEqual(state.remainingTime(at: start.addingTimeInterval(100)), 800)

    state.pause(at: start.addingTimeInterval(100))
    XCTAssertEqual(state.phase, .paused(remaining: 800))
    XCTAssertNil(state.deadline)

    state.resume(at: Date(timeIntervalSince1970: 2_000))
    XCTAssertEqual(state.phase, .running(deadline: Date(timeIntervalSince1970: 2_800)))
}

func testExpiredSleepTimerKeepsFiniteOptionAndZeroRemaining() {
    let start = Date(timeIntervalSince1970: 1_000)
    var state = SleepTimerState()
    state.schedule(.minutes15, now: start)

    XCTAssertTrue(state.expireIfNeeded(at: start.addingTimeInterval(900)))
    XCTAssertEqual(state.option, .minutes15)
    XCTAssertEqual(state.phase, .expired)
    XCTAssertEqual(state.remainingTime(at: start.addingTimeInterval(901)), 0)
    XCTAssertFalse(state.expireIfNeeded(at: start.addingTimeInterval(902)))

    state.resume(at: start.addingTimeInterval(903))
    XCTAssertEqual(state.phase, .expired)
}

func testUnlimitedSleepTimerHasNoRemainingTime() {
    var state = SleepTimerState()
    state.schedule(.unlimited, now: Date(timeIntervalSince1970: 1_000))
    XCTAssertEqual(state.phase, .unlimited)
    XCTAssertNil(state.deadline)
    XCTAssertNil(state.remainingTime(at: Date(timeIntervalSince1970: 2_000)))
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:IsleWhispersTests/PlaybackStateTests \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because `SleepTimerPhase`, `phase`, `remainingTime(at:)`, `pause(at:)`, `resume(at:)`, and `expireIfNeeded(at:)` do not exist.

- [ ] **Step 3: Replace the deadline-only timer state with the explicit state machine**

Keep `SleepTimerOption` unchanged and replace `SleepTimerState` with:

```swift
enum SleepTimerPhase: Equatable {
    case unlimited
    case running(deadline: Date)
    case paused(remaining: TimeInterval)
    case expired
}

struct SleepTimerState: Equatable {
    private(set) var option: SleepTimerOption = .unlimited
    private(set) var phase: SleepTimerPhase = .unlimited

    var deadline: Date? {
        guard case let .running(deadline) = phase else { return nil }
        return deadline
    }

    mutating func schedule(_ option: SleepTimerOption, now: Date) {
        self.option = option
        phase = option == .unlimited
            ? .unlimited
            : .running(deadline: now.addingTimeInterval(TimeInterval(option.rawValue * 60)))
    }

    func remainingTime(at date: Date) -> TimeInterval? {
        switch phase {
        case .unlimited:
            return nil
        case let .running(deadline):
            return max(deadline.timeIntervalSince(date), 0)
        case let .paused(remaining):
            return max(remaining, 0)
        case .expired:
            return 0
        }
    }

    mutating func pause(at date: Date) {
        guard case let .running(deadline) = phase else { return }
        let remaining = max(deadline.timeIntervalSince(date), 0)
        phase = remaining > 0 ? .paused(remaining: remaining) : .expired
    }

    mutating func resume(at date: Date) {
        guard case let .paused(remaining) = phase, remaining > 0 else { return }
        phase = .running(deadline: date.addingTimeInterval(remaining))
    }

    @discardableResult
    mutating func expireIfNeeded(at date: Date) -> Bool {
        guard case let .running(deadline) = phase, date >= deadline else { return false }
        phase = .expired
        return true
    }

    func isExpired(at date: Date) -> Bool {
        if case .expired = phase { return true }
        guard case let .running(deadline) = phase else { return false }
        return date >= deadline
    }
}
```

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run the Step 2 command again.

Expected: all `PlaybackStateTests` pass, including exact `800`-second pause/resume preservation and stable `.expired` state.

- [ ] **Step 5: Commit the state-machine slice**

```bash
git add IsleWhispers/IsleWhispers/Playback/PlaybackState.swift \
  IsleWhispersTests/PlaybackStateTests.swift
git commit -m "feat: add pausable playback countdown state"
```

---

### Task 2: Audio-service timer lifecycle and local notification scheduling

**Files:**
- Create: `IsleWhispers/IsleWhispers/Services/PlaybackEndNotificationScheduler.swift`
- Modify: `IsleWhispers/IsleWhispers/Services/AudioPlayerService.swift`
- Modify: `IsleWhispers/IsleWhispers/AppDelegate.swift`
- Modify: `IsleWhispersTests/AudioPlayerPersistenceTests.swift`
- Create: `IsleWhispersTests/PlaybackEndNotificationSchedulerTests.swift`

**Interfaces:**
- Consumes: Task 1 `SleepTimerState` and `SleepTimerPhase`.
- Produces: `PlaybackEndNotificationScheduling.requestAuthorization()`, `schedulePlaybackEnd(at:)`, `cancelPlaybackEnd()`, `AudioPlayerService.sleepTimerPhase`, `sleepTimerRemaining`, `clearSleepTimer()`, and `AppDelegate.foregroundNotificationOptions`.

- [ ] **Step 1: Add the notification protocol, spy, and failing service tests**

Add this test-only spy at the bottom of `AudioPlayerPersistenceTests.swift`:

```swift
@MainActor
private final class PlaybackEndNotificationSchedulerSpy: PlaybackEndNotificationScheduling {
    private(set) var authorizationRequestCount = 0
    private(set) var scheduledDate: Date?
    var allowsScheduling = true

    func requestAuthorization() {
        authorizationRequestCount += 1
    }

    func schedulePlaybackEnd(at deadline: Date) {
        if allowsScheduling {
            scheduledDate = deadline
        }
    }

    func cancelPlaybackEnd() {
        scheduledDate = nil
    }
}
```

Add these focused tests, using an isolated `UserDefaults` suite and an injected mutable `now` closure:

```swift
@MainActor
func testPlayingFiniteTimerPausesAndReschedulesOneNotification() {
    let suite = "AudioTimerTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    var now = Date(timeIntervalSince1970: 1_000)
    let scheduler = PlaybackEndNotificationSchedulerSpy()
    let service = AudioPlayerService(
        defaults: defaults,
        configureSystemIntegration: false,
        nowProvider: { now },
        notificationScheduler: scheduler
    )
    service.play()
    service.setSleepTimer(.minutes15)

    XCTAssertEqual(scheduler.authorizationRequestCount, 1)
    XCTAssertEqual(scheduler.scheduledDate, Date(timeIntervalSince1970: 1_900))

    now = Date(timeIntervalSince1970: 1_100)
    service.pause()
    XCTAssertEqual(service.sleepTimerPhase, .paused(remaining: 800))
    XCTAssertNil(scheduler.scheduledDate)

    now = Date(timeIntervalSince1970: 2_000)
    service.play()
    XCTAssertEqual(service.sleepTimerPhase, .running(deadline: Date(timeIntervalSince1970: 2_800)))
    XCTAssertEqual(scheduler.scheduledDate, Date(timeIntervalSince1970: 2_800))
}

@MainActor
func testFiniteTimerSelectedWhilePausedWaitsToScheduleUntilPlayback() {
    let (service, defaults, suite, scheduler) = makeTimerService(now: Date(timeIntervalSince1970: 1_000))
    defer { defaults.removePersistentDomain(forName: suite) }

    service.setSleepTimer(.minutes15)
    XCTAssertEqual(service.sleepTimerPhase, .paused(remaining: 900))
    XCTAssertEqual(scheduler.authorizationRequestCount, 1)
    XCTAssertNil(scheduler.scheduledDate)

    service.play()
    XCTAssertEqual(service.sleepTimerPhase, .running(deadline: Date(timeIntervalSince1970: 1_900)))
    XCTAssertEqual(scheduler.scheduledDate, Date(timeIntervalSince1970: 1_900))
}

@MainActor
func testTimerExpiryPausesOnceAndKeepsZeroState() {
    let suite = "AudioTimerTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    var now = Date(timeIntervalSince1970: 1_000)
    let scheduler = PlaybackEndNotificationSchedulerSpy()
    let service = AudioPlayerService(
        defaults: defaults,
        configureSystemIntegration: false,
        nowProvider: { now },
        notificationScheduler: scheduler
    )
    service.play()
    service.setSleepTimer(.minutes15)
    now = Date(timeIntervalSince1970: 1_900)

    service.reconcileSleepTimer()
    service.reconcileSleepTimer()

    XCTAssertFalse(service.isPlaying)
    XCTAssertEqual(service.sleepTimerOption, .minutes15)
    XCTAssertEqual(service.sleepTimerPhase, .expired)
    XCTAssertEqual(service.sleepTimerRemaining, 0)
    XCTAssertEqual(scheduler.scheduledDate, Date(timeIntervalSince1970: 1_900))
}

@MainActor
func testChangingFiniteTimerReplacesDeadlineAndRemoteCommandsPauseIt() {
    let suite = "AudioTimerTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    var now = Date(timeIntervalSince1970: 1_000)
    let scheduler = PlaybackEndNotificationSchedulerSpy()
    let service = AudioPlayerService(
        defaults: defaults,
        configureSystemIntegration: false,
        nowProvider: { now },
        notificationScheduler: scheduler
    )
    service.play()
    service.setSleepTimer(.minutes15)
    now = Date(timeIntervalSince1970: 1_100)
    service.setSleepTimer(.minutes30)
    XCTAssertEqual(scheduler.scheduledDate, Date(timeIntervalSince1970: 2_900))

    XCTAssertEqual(service.performRemoteCommand(.pause), .success)
    XCTAssertEqual(service.sleepTimerPhase, .paused(remaining: 1_800))
    XCTAssertNil(scheduler.scheduledDate)
    XCTAssertEqual(service.performRemoteCommand(.play), .success)
    XCTAssertEqual(service.sleepTimerPhase, .running(deadline: Date(timeIntervalSince1970: 2_900)))
}

@MainActor
func testDeniedNotificationSchedulingDoesNotBlockTimerExpiry() {
    let suite = "AudioTimerTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    var now = Date(timeIntervalSince1970: 1_000)
    let scheduler = PlaybackEndNotificationSchedulerSpy()
    scheduler.allowsScheduling = false
    let service = AudioPlayerService(
        defaults: defaults,
        configureSystemIntegration: false,
        nowProvider: { now },
        notificationScheduler: scheduler
    )
    service.play()
    service.setSleepTimer(.minutes15)
    now = Date(timeIntervalSince1970: 1_900)
    service.reconcileSleepTimer()

    XCTAssertFalse(service.isPlaying)
    XCTAssertEqual(service.sleepTimerPhase, .expired)
    XCTAssertNil(scheduler.scheduledDate)
}
```

Implement `makeTimerService(now:)` beside the existing `makeService()` so it returns the service, defaults, suite name, and scheduler spy. Update the two old expiry assertions that expected `.unlimited` to expect the original finite option plus `.expired`; retain the assertion that the first remote play at a newly expired deadline fails, then add a second remote play assertion that succeeds from the stable expired state.

- [ ] **Step 2: Run the focused service tests and verify RED**

Run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:IsleWhispersTests/AudioPlayerPersistenceTests \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because the notification protocol, injected scheduler, service phase/remaining properties, and pause/resume integration do not exist.

- [ ] **Step 3: Create the production local-notification scheduler**

Create `PlaybackEndNotificationScheduler.swift` with this exact public surface and fixed request identity:

```swift
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
```

The generation token prevents a stale authorization callback from restoring a notification after pause, time change, or close.

- [ ] **Step 4: Integrate timer phases and the scheduler into `AudioPlayerService`**

Change shared construction and initialization to:

```swift
static let shared = AudioPlayerService(
    notificationScheduler: LocalPlaybackEndNotificationScheduler()
)

private let notificationScheduler: PlaybackEndNotificationScheduling?

init(
    defaults: UserDefaults = .standard,
    configureSystemIntegration: Bool = true,
    resourceBundle: Bundle = .main,
    notificationCenter: NotificationCenter = .default,
    observeSystemNotifications: Bool? = nil,
    nowProvider: @escaping () -> Date = Date.init,
    notificationScheduler: PlaybackEndNotificationScheduling? = nil
) {
    self.notificationScheduler = notificationScheduler
}

var sleepTimerPhase: SleepTimerPhase { sleepTimerState.phase }
var sleepTimerRemaining: TimeInterval? {
    sleepTimerState.remainingTime(at: nowProvider())
}
```

Add the new stored-property assignment alongside the existing `defaults`, `resourceBundle`, `notificationCenter`, and `nowProvider` assignments; leave every other current initializer statement unchanged.

Replace the timer mutations with three private helpers:

```swift
private func replaceSleepTimerSchedule() {
    sleepTimer?.invalidate()
    sleepTimer = nil
    notificationScheduler?.cancelPlaybackEnd()
    guard let deadline = sleepTimerState.deadline else { return }
    armSleepTimer(after: deadline.timeIntervalSince(nowProvider()))
    notificationScheduler?.schedulePlaybackEnd(at: deadline)
}

private func pauseSleepTimerIfNeeded() {
    sleepTimerState.pause(at: nowProvider())
    replaceSleepTimerSchedule()
}

private func resumeSleepTimerIfNeeded() {
    sleepTimerState.resume(at: nowProvider())
    replaceSleepTimerSchedule()
}
```

Apply these exact behavior changes:

- `setSleepTimer(_:)` schedules the option, requests authorization for every finite selection, immediately pauses the newly scheduled timer when `isPlaying == false`, replaces the internal/notification schedule, then publishes once.
- `clearSleepTimer()` calls `setSleepTimer(.unlimited)`.
- `pause()` calls `pauseSleepTimerIfNeeded()` before the existing `stopPlayback(...)`.
- `play()` resumes a paused timer before `attemptPlay()`; if playback fails after that resume, pause the timer again so a failed audio start cannot consume countdown time.
- `selectAndPlay(at:)` prepares the selected sound and calls `play()` so a paused countdown resumes when sheet selection auto-plays.
- `expireSleepTimerIfNeeded()` uses `sleepTimerState.expireIfNeeded(at:)`, invalidates only the in-process `Timer`, stops playback, and leaves the phase `.expired` instead of scheduling `.unlimited`. Do not cancel the local notification at expiry: it may be racing with delivery at the same deadline and must remain eligible to appear.
- `reconcileSleepTimer()` stops once on a newly expired running timer, rearms only a still-running deadline, and leaves paused/expired/unlimited states unarmed.
- Keep interruption-resume behavior unchanged; remote `.pause`, `.play`, and `.togglePlayback` already route through the public methods and therefore share countdown behavior.

- [ ] **Step 5: Enable foreground banner and sound presentation**

Import `UserNotifications`, make `AppDelegate` conform to `UNUserNotificationCenterDelegate`, assign `UNUserNotificationCenter.current().delegate = self` in `didFinishLaunchingWithOptions`, and add:

```swift
static let foregroundNotificationOptions: UNNotificationPresentationOptions = [.banner, .sound]

func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
) {
    completionHandler(Self.foregroundNotificationOptions)
}
```

- [ ] **Step 6: Add scheduler-contract tests and verify GREEN**

Create `PlaybackEndNotificationSchedulerTests.swift`:

```swift
import UserNotifications
import XCTest
@testable import IsleWhispers

final class PlaybackEndNotificationSchedulerTests: XCTestCase {
    func testPlaybackEndNotificationUsesStableIdentityAndCopy() {
        XCTAssertEqual(
            LocalPlaybackEndNotificationScheduler.requestIdentifier,
            "isleWhispers.playbackEnded"
        )
        XCTAssertEqual(LocalPlaybackEndNotificationScheduler.notificationTitle, "播放已结束")
    }

    func testForegroundPlaybackEndNotificationUsesBannerAndSound() {
        let options = AppDelegate.foregroundNotificationOptions
        XCTAssertTrue(options.contains(.banner))
        XCTAssertTrue(options.contains(.sound))
    }
}
```

Run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:IsleWhispersTests/PlaybackStateTests \
  -only-testing:IsleWhispersTests/AudioPlayerPersistenceTests \
  -only-testing:IsleWhispersTests/PlaybackEndNotificationSchedulerTests \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: all countdown, service, remote command, scheduler contract, and foreground-option tests pass.

- [ ] **Step 7: Commit the service and notification slice**

```bash
git add IsleWhispers/IsleWhispers/Services/PlaybackEndNotificationScheduler.swift \
  IsleWhispers/IsleWhispers/Services/AudioPlayerService.swift \
  IsleWhispers/IsleWhispers/AppDelegate.swift \
  IsleWhispersTests/AudioPlayerPersistenceTests.swift \
  IsleWhispersTests/PlaybackEndNotificationSchedulerTests.swift
git commit -m "feat: synchronize playback countdown notifications"
```

---

### Task 3: Full-screen focus playback UI and controls

**Files:**
- Create: `IsleWhispers/IsleWhispers/ViewControllers/FocusPlaybackViewController.swift`
- Create: `IsleWhispersTests/FocusPlaybackViewControllerTests.swift`

**Interfaces:**
- Consumes: shared `AudioPlayerService`, `SoundArtwork.image(for:)`, `SoundLibraryViewController`, `AppTheme`, and Task 2 timer APIs.
- Produces: `FocusPlaybackViewController.init(playerService:onSelectSound:)`, `countdownTextForTesting`, `refreshForTesting()`, and `selectTimerForTesting(_:)`.

- [ ] **Step 1: Write failing rendering and control tests**

Create `FocusPlaybackViewControllerTests.swift` with an isolated service context and recursive view helpers. Add these behaviors:

```swift
@MainActor
func testPlayingPageShowsArtworkCountdownAndNoCloseButton() throws {
    let context = makeFocusContext()
    defer { context.cleanup() }
    context.service.play()
    context.service.setSleepTimer(.minutes15)
    layout(context.controller, size: CGSize(width: 390, height: 844))

    XCTAssertEqual(findLabel(identifier: "focusSoundTitle", in: context.controller.view)?.text,
                   context.service.currentSound.title)
    XCTAssertEqual(findLabel(identifier: "focusCountdown", in: context.controller.view)?.text, "15:00")
    XCTAssertNotNil(findButton(label: "暂停播放", in: context.controller.view))
    XCTAssertNil(findButton(label: "关闭播放页", in: context.controller.view))
    let blur = try XCTUnwrap(findSubview(UIVisualEffectView.self, in: context.controller.view))
    XCTAssertLessThanOrEqual(blur.alpha, 0.20)
}

@MainActor
func testPauseShowsCloseAndResumeContinuesExactCountdown() throws {
    let context = makeFocusContext()
    defer { context.cleanup() }
    context.service.play()
    context.service.setSleepTimer(.minutes15)
    layout(context.controller, size: CGSize(width: 375, height: 667))

    findButton(label: "暂停播放", in: context.controller.view)?.sendActions(for: .touchUpInside)
    XCTAssertFalse(context.service.isPlaying)
    XCTAssertNotNil(findButton(label: "继续播放", in: context.controller.view))
    XCTAssertNotNil(findButton(label: "关闭播放页", in: context.controller.view))

    findButton(label: "继续播放", in: context.controller.view)?.sendActions(for: .touchUpInside)
    XCTAssertTrue(context.service.isPlaying)
    XCTAssertNil(findButton(label: "关闭播放页", in: context.controller.view))
}

@MainActor
func testUnlimitedAndExpiredCountdownCopy() {
    let context = makeFocusContext()
    defer { context.cleanup() }
    context.controller.loadViewIfNeeded()
    XCTAssertEqual(context.controller.countdownTextForTesting, "∞")

    context.service.play()
    context.controller.selectTimerForTesting(.minutes15)
    context.advanceNow(by: 900)
    context.service.reconcileSleepTimer()
    context.controller.refreshForTesting()

    XCTAssertEqual(context.controller.countdownTextForTesting, "00:00")
    XCTAssertFalse(context.service.isPlaying)
}

@MainActor
func testAudioFailureShowsStatusRetryAndClose() throws {
    let context = makeFocusContext(resourceBundle: Bundle(for: FocusPlaybackViewControllerTests.self))
    defer { context.cleanup() }
    context.service.play()
    layout(context.controller, size: CGSize(width: 390, height: 844))

    XCTAssertEqual(findLabel(identifier: "focusStatus", in: context.controller.view)?.text,
                   "音频资源不可用")
    XCTAssertNotNil(findButton(label: "重试播放", in: context.controller.view))
    XCTAssertNotNil(findButton(label: "关闭播放页", in: context.controller.view))
}
```

The context stores a mutable clock shared with `AudioPlayerService`; `advanceNow(by:)` changes that clock without waiting in real time. Its `onSelectSound` closure must execute the real shared flow used by this isolated test:

```swift
let controller = FocusPlaybackViewController(
    playerService: service,
    onSelectSound: { index in
        service.selectAndPlay(at: index)
        store.record(Sound.catalog[index])
    }
)
```

Define a scheduler spy inside this test file with the same protocol methods as Task 2 so close cleanup can inspect `scheduledDate`. Add a layout assertion at both `375x667` and `430x932` that all views with identifiers `focusSoundTitle`, `focusSoundPicker`, `focusCountdown`, and `focusPrimaryControl` remain inside the safe-area frame after three layout passes.

- [ ] **Step 2: Run the focused UI tests and verify RED**

Run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:IsleWhispersTests/FocusPlaybackViewControllerTests \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because `FocusPlaybackViewController` and its testing surfaces do not exist.

- [ ] **Step 3: Build the full-screen visual hierarchy with SnapKit**

Create a final `FocusPlaybackViewController` with:

```swift
final class FocusPlaybackViewController: UIViewController {
    private let playerService: AudioPlayerService
    private let onSelectSound: (Int) -> Void
    private let backgroundImageView = UIImageView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let overlayView = UIView()
    private let titleLabel = UILabel()
    private let soundPickerButton = UIButton(type: .system)
    private let countdownButton = UIButton(type: .system)
    private let primaryControlButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private var displayTimer: Timer?
    private var displayedBackgroundResource: String?

    init(playerService: AudioPlayerService, onSelectSound: @escaping (Int) -> Void) {
        self.playerService = playerService
        self.onSelectSound = onSelectSound
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
}
```

Configure `backgroundImageView.contentMode = .scaleAspectFill`, `clipsToBounds = true`, `blurView.alpha = 0.14`, and a black overlay near 0.24 alpha. Pin all three background layers to the full view. Pin title/sound-picker to the top safe area and countdown/control group to the bottom safe area using 20-point horizontal insets; place `statusLabel` and `retryButton` above that bottom group. Use at least 56x56 touch targets, dynamic fonts, white foreground, and accessibility identifiers named in Step 1 plus `focusStatus` for the error label.

Use `AppTheme.font(.largeTitle, weight: .regular)` for the countdown with a larger transform or explicit scaled font only when it still honors Dynamic Type. Give the countdown button accessibility label `"设置倒计时"` and a value of `"不限时"`, `"剩余…"`, or `"倒计时已结束"`.

Set every label and button title label to `adjustsFontForContentSizeCategory = true`. Add an accessibility layout test by hosting the controller as a child, applying `UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)` with `setOverrideTraitCollection(_:forChild:)`, and verifying the top and bottom control groups remain inside a scroll-free `375x667` safe area without intersecting each other.

- [ ] **Step 4: Implement rendering, ticking, timer selection, and controls**

Use these exact formatting and state rules:

```swift
private func countdownText() -> String {
    guard let remaining = playerService.sleepTimerRemaining else { return "∞" }
    let total = Int(ceil(max(remaining, 0)))
    return String(format: "%02d:%02d", total / 60, total % 60)
}

private func render() {
    let sound = playerService.currentSound
    titleLabel.text = sound.title
    updateBackground(for: sound)
    countdownButton.setTitle(countdownText(), for: .normal)

    let playing = playerService.isPlaying
    primaryControlButton.accessibilityLabel = playing ? "暂停播放" : "继续播放"
    primaryControlButton.setImage(UIImage(systemName: playing ? "pause.fill" : "play.fill"), for: .normal)
    closeButton.isHidden = playing
    closeButton.accessibilityElementsHidden = playing
    let hasError = playerService.statusMessage != "准备就绪"
    statusLabel.text = hasError ? playerService.statusMessage : nil
    statusLabel.isHidden = !hasError
    retryButton.isHidden = !hasError
    updateDisplayTimer()
}

@objc private func didTapPrimaryControl() {
    playerService.isPlaying ? playerService.pause() : playerService.play()
}

@objc private func didTapClose() {
    playerService.clearSleepTimer()
    playerService.pause()
    dismiss(animated: true)
}

@objc private func didTapRetry() {
    playerService.retry()
    playerService.play()
}
```

Implement `updateBackground(for:)` so it does nothing for an unchanged `backgroundResource`, otherwise loads `SoundArtwork.image(for:)` and applies a 0.20-second `.transitionCrossDissolve`. When `UIAccessibility.isReduceMotionEnabled` is true, assign the image without animation. In `traitCollectionDidChange`, raise the overlay alpha to about 0.38 for `.high` accessibility contrast and restore it to 0.24 for normal contrast.

`updateDisplayTimer()` keeps one repeating one-second timer only for `.running`; each tick updates the countdown text from the service deadline. In `viewWillAppear`, start rendering; in `viewDidDisappear` and `deinit`, invalidate the timer. Observe `.audioPlayerStateDidChange` for this exact service and remove the observer in `deinit`.

`didTapCountdown` presents an iPhone action sheet with exactly four actions: `不限时`, `15 分钟`, `30 分钟`, `60 分钟`, plus `取消`. Every option calls one shared `selectTimer(_:)`; expose `selectTimerForTesting(_:)` as an internal wrapper and `countdownTextForTesting`/`refreshForTesting()` as read-only testing surfaces.

- [ ] **Step 5: Run Focus UI tests and verify GREEN**

Run the Step 2 command again.

Expected: rendering, low blur, safe-area layout, exact countdown formatting, pause/resume, close visibility, unlimited, and expired-state tests pass.

- [ ] **Step 6: Commit the standalone focus UI**

```bash
git add IsleWhispers/IsleWhispers/ViewControllers/FocusPlaybackViewController.swift \
  IsleWhispersTests/FocusPlaybackViewControllerTests.swift
git commit -m "feat: add full-screen focus playback controls"
```

---

### Task 4: Home entry, half-sheet sound switching, and end-to-end cleanup

**Files:**
- Modify: `IsleWhispers/IsleWhispers/ViewControllers/FocusPlaybackViewController.swift`
- Modify: `IsleWhispers/IsleWhispers/ViewControllers/HomeViewController.swift`
- Modify: `IsleWhispersTests/FocusPlaybackViewControllerTests.swift`
- Modify: `IsleWhispersTests/HomeViewControllerTests.swift`

**Interfaces:**
- Consumes: Task 3 `FocusPlaybackViewController.init(playerService:onSelectSound:)` and existing `HomeViewController.selectAndPlaySound(at:animated:)`.
- Produces: Home central-button focus presentation and a page-sheet `SoundLibraryViewController` whose selection uses the existing audio/recent/carousel flow.

- [ ] **Step 1: Write failing Home-entry and sheet-selection tests**

Update the old initial-play Home test to install the controller in a `390x844` key `UIWindow`, lay it out, and find the button by `"开始播放并打开播放页"`, then assert:

```swift
play.sendActions(for: .touchUpInside)

XCTAssertTrue(context.service.isPlaying)
XCTAssertEqual(context.store.recentSounds.map(\.id), [Sound.catalog[2].id])
let focus = try XCTUnwrap(context.controller.presentedViewController as? FocusPlaybackViewController)
XCTAssertEqual(focus.modalPresentationStyle, .fullScreen)
```

Add an already-playing test that registers an `.audioPlayerStateDidChange` observer after `service.play()`, taps the Home button labeled `"打开播放页"`, and asserts the focus page is presented with zero additional service notifications. This proves presentation does not restart the audio.

Add this sheet selection flow to `FocusPlaybackViewControllerTests`:

```swift
let switchButton = try XCTUnwrap(findButton(labelPrefix: "切换声音", in: controller.view))
switchButton.sendActions(for: .touchUpInside)
let navigation = try XCTUnwrap(controller.presentedViewController as? UINavigationController)
let library = try XCTUnwrap(navigation.viewControllers.first as? SoundLibraryViewController)
library.selectItemForTesting(section: 1, item: 2)

XCTAssertEqual(service.currentSound.title, "游艇")
XCTAssertTrue(service.isPlaying)
XCTAssertEqual(store.recentSounds.first?.id, service.currentSound.id)
XCTAssertTrue(waitForDismissal(of: controller))
```

Finally present the focus controller in a `UIWindow`, start a finite timer, pause, tap `"关闭播放页"`, wait for dismissal, and assert audio is paused, `sleepTimerPhase == .unlimited`, `sleepTimerOption == .unlimited`, the scheduler spy has no scheduled date, and `selectedIndex` is unchanged.

- [ ] **Step 2: Run Home and Focus tests and verify RED**

Run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:IsleWhispersTests/HomeViewControllerTests \
  -only-testing:IsleWhispersTests/FocusPlaybackViewControllerTests \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: Home still toggles playback instead of presenting, and the Focus sound-picker button does not yet present a sheet.

- [ ] **Step 3: Change the Home central button into the focus-page entry**

Replace `didTapPlayPause` with `didTapOpenFocusPlayback` in the target registration and implementation:

```swift
@objc private func didTapOpenFocusPlayback() {
    if !playerService.isPlaying {
        playerService.play()
    }
    guard presentedViewController == nil else { return }

    let controller = FocusPlaybackViewController(
        playerService: playerService,
        onSelectSound: { [weak self] index in
            self?.selectAndPlaySound(at: index, animated: false)
        }
    )
    controller.modalPresentationStyle = .fullScreen
    present(controller, animated: true)
}
```

Present even when `play()` reports an audio-resource failure; the focus page then exposes its status, retry, and close controls instead of leaving the user on Home with no explanation.

In `render()`, avoid a pause symbol for a button that opens another page:

```swift
let isPlaying = playerService.isPlaying
let symbol = isPlaying ? "waveform" : "play.fill"
let configuration = AppTheme.symbolConfiguration(pointSize: 24, weight: .bold)
playPauseButton.setImage(UIImage(systemName: symbol, withConfiguration: configuration), for: .normal)
playPauseButton.accessibilityLabel = isPlaying
    ? "打开播放页"
    : "开始播放并打开播放页"
```

Update existing Home tests that intentionally tap the old `"播放"` button to use the stopped-state label, while tests that need only audio setup may continue to call `service.play()` directly.

- [ ] **Step 4: Present and coordinate the reusable half-sheet library**

In `FocusPlaybackViewController`, add the sound-picker target and implement:

```swift
@objc private func didTapSoundPicker() {
    let library = SoundLibraryViewController(selectedSoundID: playerService.currentSound.id)
    let navigation = UINavigationController(rootViewController: library)
    library.navigationItem.rightBarButtonItem = UIBarButtonItem(
        systemItem: .close,
        primaryAction: UIAction { [weak navigation] _ in
            navigation?.dismiss(animated: true)
        }
    )
    library.onSelect = { [weak self, weak navigation] index in
        self?.onSelectSound(index)
        navigation?.dismiss(animated: true)
    }
    navigation.modalPresentationStyle = .pageSheet
    if let sheet = navigation.sheetPresentationController {
        sheet.detents = [.medium(), .large()]
        sheet.prefersGrabberVisible = true
    }
    present(navigation, animated: true)
}
```

Set the picker accessibility label during every `render()` to `"切换声音，当前\(sound.title)"`. Because `onSelectSound` routes to Home’s existing `selectAndPlaySound`, it automatically updates audio, recent history, carousel position, and the second Tab selection without adding another coordinator.

- [ ] **Step 5: Run the focused and adjacent suites and verify GREEN**

Run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:IsleWhispersTests/HomeViewControllerTests \
  -only-testing:IsleWhispersTests/FocusPlaybackViewControllerTests \
  -only-testing:IsleWhispersTests/SoundLibraryViewControllerTests \
  -only-testing:IsleWhispersTests/RootTabBarControllerTests \
  -only-testing:IsleWhispersTests/AudioPlayerPersistenceTests \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: Home entry/autoplay, already-playing presentation, sheet selection/dismissal, exact timer preservation, close cleanup, library grouping, root coordination, and service lifecycle all pass.

- [ ] **Step 6: Commit the integrated flow**

```bash
git add IsleWhispers/IsleWhispers/ViewControllers/FocusPlaybackViewController.swift \
  IsleWhispers/IsleWhispers/ViewControllers/HomeViewController.swift \
  IsleWhispersTests/FocusPlaybackViewControllerTests.swift \
  IsleWhispersTests/HomeViewControllerTests.swift
git commit -m "feat: open focus player and switch sounds"
```

---

## Final Verification

- [ ] **Step 1: Run the complete test suite**

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: every test passes with zero failures and zero skips.

- [ ] **Step 2: Run a clean generic simulator build**

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'generic/platform=iOS Simulator' \
  clean build CODE_SIGNING_ALLOWED=NO
```

Expected: `CLEAN SUCCEEDED` and `BUILD SUCCEEDED`.

- [ ] **Step 3: Verify static product constraints and the scoped diff**

```bash
rg -n "numberOfLoops = -1" IsleWhispers/IsleWhispers/Services/AudioPlayerService.swift
rg -n "UIProgressView|elapsedTimeLabel|durationLabel|currentTimeLabel" IsleWhispers/IsleWhispers/ViewControllers/HomeViewController.swift \
  IsleWhispers/IsleWhispers/ViewControllers/SoundLibraryViewController.swift
git diff --check 30d67ff..HEAD
git status --short
```

Expected: looping remains `-1`; Home/Library contain no progress or duration UI; the branch diff has no whitespace errors; the working tree is clean.

- [ ] **Step 4: Perform simulator interaction checks**

On both a 375x667-class and a 430x932-class iPhone simulator in portrait:

1. Tap the Home central button and confirm immediate audio plus full-screen presentation.
2. Select 15 minutes, pause, confirm the displayed seconds freeze, then resume and confirm they continue from the frozen value.
3. Open the right-top sheet, choose a different sound, confirm automatic playback, background/title change, recent-history update, and automatic sheet dismissal.
4. Pause and close; reopen from Home and confirm the countdown is `∞` while the selected sound remains.
5. Temporarily drive a test countdown to expiry and confirm `00:00`, paused audio, visible close button, and one foreground notification banner.
6. Deny notification permission and confirm countdown expiry still pauses audio without blocking or error UI.

- [ ] **Step 5: Record physical-device-only boundaries**

Verify on a real iPhone, or explicitly mark each item pending without claiming simulator evidence covers it: notification delivery while locked/backgrounded, exact audio-stop timing while the app is suspended, control-center pause/resume, route removal, and phone-call interruption. Keep notification-delivery evidence separate from audio-stop evidence because a delivered local notification does not execute app pause code.
