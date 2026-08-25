# IsleWhispers Native Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Mobile-App iOS/iPadOS design as a native UIKit ambient-sound player with 15 bundled sounds, infinite looping, sleep timers, background playback, and no progress UI.

**Architecture:** Keep the existing UIKit application and replace storyboard startup with a programmatic navigation root. A single `AudioPlayerService` owns `AVAudioPlayer`, current selection, remote commands, persistence, and the sleep deadline; two adaptive view controllers render that shared state using SnapKit constraints.

**Tech Stack:** Swift 5, UIKit, Auto Layout, SnapKit 5.7 via CocoaPods, AVFoundation, MediaPlayer, XCTest, Xcode 26.3

**Spec:** `docs/superpowers/specs/2026-08-25-isle-whispers-native-player-design.md`

## Global Constraints

- Keep the existing iOS 26.2 deployment target and `TARGETED_DEVICE_FAMILY = "1,2"`.
- Use UIKit and programmatic Auto Layout; all authored layout constraints use SnapKit.
- Manage SnapKit with CocoaPods; add no other third-party dependencies.
- Bundle exactly the 15 supplied CAF sounds and their 15 matching PNG backgrounds.
- Loop the selected sound indefinitely with `AVAudioPlayer.numberOfLoops = -1`.
- Do not create a progress bar, elapsed-time label, duration label, or playback-progress timer.
- Preserve the current uncommitted/staged project work. Every commit must use explicit paths and must not stage unrelated files.
- Keep the existing `Main.storyboard` and template `ViewController.swift` files untouched; remove only their startup references.

---

## File Map

- Create `Podfile`: CocoaPods platform and SnapKit dependency.
- Create `IsleWhispers/IsleWhispers/Models/Sound.swift`: immutable sound metadata and 15-item catalog.
- Create `IsleWhispers/IsleWhispers/Playback/PlaybackState.swift`: deterministic selection and sleep-deadline state.
- Create `IsleWhispers/IsleWhispers/Services/AudioPlayerService.swift`: AVAudioPlayer, session, interruptions, routes, persistence, sleep timer, and lock-screen commands.
- Create `IsleWhispers/IsleWhispers/UI/Theme.swift`: design tokens and reusable UIKit styling helpers.
- Create `IsleWhispers/IsleWhispers/UI/PlayerControlsView.swift`: previous/play/next controls.
- Create `IsleWhispers/IsleWhispers/UI/SoundCell.swift`: selectable sound library cell.
- Create `IsleWhispers/IsleWhispers/UI/SleepTimerView.swift`: four sleep-timer choices.
- Create `IsleWhispers/IsleWhispers/ViewControllers/LibraryViewController.swift`: adaptive library and overview player.
- Create `IsleWhispers/IsleWhispers/ViewControllers/PlayerViewController.swift`: adaptive immersive player.
- Create `IsleWhispersTests/PlaybackStateTests.swift`: selection wrap and sleep-deadline tests.
- Create `IsleWhispersTests/AudioPlayerPersistenceTests.swift`: isolated UserDefaults restore tests.
- Modify `IsleWhispers/IsleWhispers/SceneDelegate.swift`: programmatic root and shared service injection.
- Modify `IsleWhispers/IsleWhispers/Info.plist`: remove scene storyboard name and add background audio mode.
- Modify `IsleWhispers/IsleWhispers.xcodeproj/project.pbxproj`: remove main storyboard build-setting key and add XCTest target.
- Copy `Mobile-App/*.caf` to `IsleWhispers/IsleWhispers/Resources/Audio/`.
- Copy `Mobile-App/assets/backgrounds/*.png` to `IsleWhispers/IsleWhispers/Resources/Backgrounds/`.
- Generate `IsleWhispers.xcworkspace/` and `Podfile.lock` with `pod install`.

---

### Task 1: CocoaPods, resources, and programmatic startup foundation

**Files:**
- Create: `Podfile`
- Create: `IsleWhispers/IsleWhispers/Resources/Audio/*.caf`
- Create: `IsleWhispers/IsleWhispers/Resources/Backgrounds/*.png`
- Modify: `IsleWhispers/IsleWhispers/Info.plist`
- Modify: `IsleWhispers/IsleWhispers.xcodeproj/project.pbxproj`
- Generate: `Podfile.lock`
- Generate: `IsleWhispers.xcworkspace/contents.xcworkspacedata`

**Interfaces:**
- Consumes: Existing `IsleWhispers` application target.
- Produces: An app target that imports `SnapKit`, launches without `Main.storyboard`, and contains all named media resources.

- [ ] **Step 1: Add the CocoaPods dependency declaration**

```ruby
platform :ios, '26.2'
use_frameworks!

target 'IsleWhispers' do
  pod 'SnapKit', '~> 5.7'
end
```

- [ ] **Step 2: Install dependencies and verify the workspace**

Run: `pod install`

Expected: `Pod installation complete!` and `IsleWhispers.xcworkspace` exists.

- [ ] **Step 3: Copy the supplied production assets without renaming them**

Create `IsleWhispers/IsleWhispers/Resources/Audio` and copy the 15 top-level `*_sound_*_1.caf` files from `/Users/db/Downloads/Mobile-App`. Create `IsleWhispers/IsleWhispers/Resources/Backgrounds` and copy all 15 PNG files from `/Users/db/Downloads/Mobile-App/assets/backgrounds`.

Run:

```bash
find IsleWhispers/IsleWhispers/Resources/Audio -name '*.caf' | wc -l
find IsleWhispers/IsleWhispers/Resources/Backgrounds -name '*.png' | wc -l
```

Expected: both commands print `15`.

- [ ] **Step 4: Remove storyboard startup references and enable background audio**

Remove `INFOPLIST_KEY_UIMainStoryboardFile = Main;` from both app-target build configurations. In `Info.plist`, remove `UISceneStoryboardFile` and add:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

- [ ] **Step 5: Verify dependency import and resource membership**

Run:

```bash
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`; the build log includes copied CAF and PNG resources.

- [ ] **Step 6: Commit only foundation paths**

```bash
git add Podfile Podfile.lock IsleWhispers.xcworkspace IsleWhispers/IsleWhispers/Info.plist IsleWhispers/IsleWhispers.xcodeproj/project.pbxproj IsleWhispers/IsleWhispers/Resources
git commit -m "build: configure native player dependencies and assets"
```

---

### Task 2: Deterministic sound catalog and playback state

**Files:**
- Create: `IsleWhispers/IsleWhispers/Models/Sound.swift`
- Create: `IsleWhispers/IsleWhispers/Playback/PlaybackState.swift`
- Create: `IsleWhispersTests/PlaybackStateTests.swift`
- Modify: `IsleWhispers/IsleWhispers.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: Bundled resource filenames from Task 1.
- Produces: `Sound`, `Sound.catalog`, `PlaybackState`, `SleepTimerOption`, and `SleepTimerState`.

- [ ] **Step 1: Add an XCTest target that imports the app module**

Add a filesystem-synchronized `IsleWhispersTests` group and `com.apple.product-type.bundle.unit-test` target to the project, with `TEST_HOST = "$(BUILT_PRODUCTS_DIR)/IsleWhispers.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/IsleWhispers"`, `BUNDLE_LOADER = "$(TEST_HOST)"`, and an app-target dependency.

- [ ] **Step 2: Write failing wraparound and timer tests**

```swift
import XCTest
@testable import IsleWhispers

final class PlaybackStateTests: XCTestCase {
    func testNextAndPreviousWrapAroundCatalog() {
        var state = PlaybackState(selectedIndex: 14, isPlaying: false)
        state.selectNext(count: 15)
        XCTAssertEqual(state.selectedIndex, 0)
        state.selectPrevious(count: 15)
        XCTAssertEqual(state.selectedIndex, 14)
    }

    func testSelectingSoundPreservesPlayingIntent() {
        var state = PlaybackState(selectedIndex: 2, isPlaying: true)
        state.select(index: 7, count: 15)
        XCTAssertEqual(state, PlaybackState(selectedIndex: 7, isPlaying: true))
    }

    func testSleepTimerExpiresAtDeadline() {
        let now = Date(timeIntervalSince1970: 1_000)
        var state = SleepTimerState()
        state.schedule(.minutes15, now: now)
        XCTAssertFalse(state.isExpired(at: now.addingTimeInterval(899)))
        XCTAssertTrue(state.isExpired(at: now.addingTimeInterval(900)))
    }
}
```

- [ ] **Step 3: Run tests and confirm the new types are missing**

Run: `xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:IsleWhispersTests/PlaybackStateTests test CODE_SIGNING_ALLOWED=NO`

Expected: FAIL because `PlaybackState` and `SleepTimerState` do not exist.

- [ ] **Step 4: Implement the 15-item catalog**

```swift
struct Sound: Equatable, Sendable {
    let title: String
    let subtitle: String
    let audioResource: String
    let backgroundResource: String

    static let catalog: [Sound] = [
        .init(title: "茶香", subtitle: "茶与安静器皿", audioResource: "0_sound_tea_1", backgroundResource: "tea"),
        .init(title: "雷声", subtitle: "低沉而遥远", audioResource: "1_sound_thunder_1", backgroundResource: "thunder"),
        .init(title: "雨声", subtitle: "均匀落在窗边", audioResource: "2_sound_rain_1", backgroundResource: "rain"),
        .init(title: "火炉", subtitle: "轻柔木柴噼啪", audioResource: "3_sound_fire_1", backgroundResource: "fire"),
        .init(title: "水流", subtitle: "舒缓连续水声", audioResource: "4_sound_water_1", backgroundResource: "water"),
        .init(title: "风声", subtitle: "空气缓慢流动", audioResource: "5_sound_wind_1", backgroundResource: "wind"),
        .init(title: "白昼", subtitle: "明亮自然环境", audioResource: "6_sound_day_1", backgroundResource: "day"),
        .init(title: "夜晚", subtitle: "深夜低噪氛围", audioResource: "7_sound_night_1", backgroundResource: "night"),
        .init(title: "河流", subtitle: "清澈而连续的水纹", audioResource: "8_sound_river_1", backgroundResource: "river"),
        .init(title: "太空", subtitle: "宽阔漂浮氛围", audioResource: "9_sound_space_1", backgroundResource: "space"),
        .init(title: "游艇", subtitle: "海面与船体轻响", audioResource: "10_sound_yacht_1", backgroundResource: "yacht"),
        .init(title: "火车", subtitle: "规律远行节奏", audioResource: "11_sound_train_1", backgroundResource: "train"),
        .init(title: "农场", subtitle: "开阔乡间声景", audioResource: "12_sound_farm_1", backgroundResource: "farm"),
        .init(title: "风铃", subtitle: "清脆稀疏回响", audioResource: "13_sound_chimes_1", backgroundResource: "chimes"),
        .init(title: "鲸歌", subtitle: "深海悠长低吟", audioResource: "14_sound_whale_1", backgroundResource: "whale")
    ]
}
```

- [ ] **Step 5: Implement deterministic selection and sleep state**

```swift
struct PlaybackState: Equatable {
    private(set) var selectedIndex: Int
    var isPlaying: Bool

    mutating func select(index: Int, count: Int) {
        guard count > 0 else { return }
        selectedIndex = (index % count + count) % count
    }

    mutating func selectNext(count: Int) { select(index: selectedIndex + 1, count: count) }
    mutating func selectPrevious(count: Int) { select(index: selectedIndex - 1, count: count) }
}

enum SleepTimerOption: Int, CaseIterable {
    case unlimited = 0, minutes15 = 15, minutes30 = 30, minutes60 = 60
}

struct SleepTimerState: Equatable {
    private(set) var option: SleepTimerOption = .unlimited
    private(set) var deadline: Date?

    mutating func schedule(_ option: SleepTimerOption, now: Date) {
        self.option = option
        deadline = option == .unlimited ? nil : now.addingTimeInterval(TimeInterval(option.rawValue * 60))
    }

    func isExpired(at date: Date) -> Bool { deadline.map { date >= $0 } ?? false }
}
```

- [ ] **Step 6: Run focused tests**

Run the Step 3 command again.

Expected: all three `PlaybackStateTests` pass.

- [ ] **Step 7: Commit the domain layer and test target**

```bash
git add IsleWhispers/IsleWhispers/Models IsleWhispers/IsleWhispers/Playback/PlaybackState.swift IsleWhispersTests IsleWhispers/IsleWhispers.xcodeproj/project.pbxproj
git commit -m "feat: add sound catalog and playback state"
```

---

### Task 3: Shared looping audio service

**Files:**
- Create: `IsleWhispers/IsleWhispers/Services/AudioPlayerService.swift`
- Create: `IsleWhispersTests/AudioPlayerPersistenceTests.swift`

**Interfaces:**
- Consumes: `Sound.catalog`, `PlaybackState`, `SleepTimerOption`, `SleepTimerState`.
- Produces: `AudioPlayerService.shared`, `currentSound`, `selectedIndex`, `isPlaying`, `sleepTimerOption`, `statusMessage`, `selectSound(at:)`, `togglePlayback()`, `play()`, `pause()`, `previous()`, `next()`, `retry()`, `setSleepTimer(_:)`, `reconcileSleepTimer()`, and `.audioPlayerStateDidChange`.

- [ ] **Step 1: Write a failing isolated persistence test**

```swift
import XCTest
@testable import IsleWhispers

final class AudioPlayerPersistenceTests: XCTestCase {
    func testRestoresLastValidSelectionWithoutAutoplay() {
        let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(11, forKey: AudioPlayerService.selectedSoundDefaultsKey)
        let service = AudioPlayerService(defaults: defaults, configureSystemIntegration: false)
        XCTAssertEqual(service.selectedIndex, 11)
        XCTAssertFalse(service.isPlaying)
        defaults.removePersistentDomain(forName: suite)
    }
}
```

- [ ] **Step 2: Run the persistence test and confirm failure**

Run: `xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:IsleWhispersTests/AudioPlayerPersistenceTests test CODE_SIGNING_ALLOWED=NO`

Expected: FAIL because `AudioPlayerService` does not exist.

- [ ] **Step 3: Implement the service state and looping player**

Create a `@MainActor final class AudioPlayerService: NSObject, AVAudioPlayerDelegate` with this public surface:

```swift
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
```

The initializer reads `selectedSoundDefaultsKey`, accepts only `Sound.catalog.indices`, falls back to index `2`, and always initializes `isPlaying` to `false`. `retry()` calls `prepareSelectedSound()` and republishes either `准备就绪` or the resource/decoder error message.

`prepareSelectedSound()` resolves `Bundle.main.url(forResource: currentSound.audioResource, withExtension: "caf", subdirectory: "Audio")`, creates `AVAudioPlayer(contentsOf:)`, sets `numberOfLoops = -1`, calls `prepareToPlay()`, and never installs a progress observer.

- [ ] **Step 4: Implement state-changing commands**

```swift
func selectSound(at index: Int) {
    let shouldContinue = isPlaying
    state.select(index: index, count: Sound.catalog.count)
    defaults.set(selectedIndex, forKey: Self.selectedSoundDefaultsKey)
    prepareSelectedSound()
    if shouldContinue { play() }
    publishState()
}

func previous() { selectSound(at: selectedIndex - 1) }
func next() { selectSound(at: selectedIndex + 1) }
func togglePlayback() { isPlaying ? pause() : play() }
```

`play()` activates the audio session, prepares missing audio, starts the player, sets `state.isPlaying` from the player result, and publishes. `pause()` pauses without resetting current time, sets `isPlaying = false`, and publishes.

- [ ] **Step 5: Implement accurate sleep deadlines**

`setSleepTimer(_:)` schedules `SleepTimerState`, replaces one `Timer`, and publishes. `reconcileSleepTimer()` pauses and resets to `.unlimited` when expired; otherwise it re-arms for the remaining deadline interval. Observe `UIApplication.didBecomeActiveNotification` and call `reconcileSleepTimer()`.

- [ ] **Step 6: Add system audio integration**

Configure `AVAudioSession.sharedInstance()` with category `.playback`, mode `.default`, and options `[]`. Observe interruption and route-change notifications. Register play, pause, toggle, previous, and next commands with `MPRemoteCommandCenter.shared()`. Update `MPNowPlayingInfoCenter.default().nowPlayingInfo` with title, subtitle, `MPNowPlayingInfoPropertyPlaybackRate`, and no elapsed/duration entries.

- [ ] **Step 7: Run focused state tests and app build**

Run:

```bash
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:IsleWhispersTests test CODE_SIGNING_ALLOWED=NO
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

Expected: tests pass and build succeeds.

- [ ] **Step 8: Commit the audio service**

```bash
git add IsleWhispers/IsleWhispers/Services/AudioPlayerService.swift IsleWhispersTests/AudioPlayerPersistenceTests.swift
git commit -m "feat: add looping background audio service"
```

---

### Task 4: Shared design system and controls

**Files:**
- Create: `IsleWhispers/IsleWhispers/UI/Theme.swift`
- Create: `IsleWhispers/IsleWhispers/UI/PlayerControlsView.swift`
- Create: `IsleWhispers/IsleWhispers/UI/SoundCell.swift`
- Create: `IsleWhispers/IsleWhispers/UI/SleepTimerView.swift`

**Interfaces:**
- Consumes: `Sound`, `SleepTimerOption`, `SnapKit`.
- Produces: `AppTheme`, `PlayerControlsView.onPrevious/onToggle/onNext`, `SoundCell.configure(sound:selected:)`, and `SleepTimerView.onSelect/configure(selected:)`.

- [ ] **Step 1: Implement design tokens**

```swift
enum AppTheme {
    static let background = UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.071, green: 0.071, blue: 0.071, alpha: 1) : UIColor(red: 0.961, green: 0.961, blue: 0.941, alpha: 1) }
    static let surface = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.10) : UIColor(white: 1, alpha: 0.72) }
    static let foreground = UIColor.label
    static let muted = UIColor.secondaryLabel
    static let accent = UIColor(red: 0.663, green: 0.769, blue: 0.851, alpha: 1)
    static let cardRadius: CGFloat = 24
    static let controlSize: CGFloat = 48
    static let primaryControlSize: CGFloat = 64
}
```

Add helpers for rounded corners, SF Symbol configuration, Dynamic Type fonts, and subtle shadows matching the design handoff.

- [ ] **Step 2: Build the reusable player controls**

Create three `UIButton`s with `backward.end.fill`, `play.fill`/`pause.fill`, and `forward.end.fill`. Constrain the primary button to 64×64, secondary buttons to 48×48, and expose closures. `configure(isPlaying:)` changes only the central image and accessibility label.

- [ ] **Step 3: Build the selectable sound cell**

Use a rounded `contentView`, wave SF Symbol, and one Dynamic Type label. `configure(sound:selected:)` sets title, accessibility label (`"\(title)：\(subtitle)"`), accent border, and selected accessibility trait.

- [ ] **Step 4: Build the timer selector**

Use four pill buttons for `.unlimited`, `.minutes15`, `.minutes30`, and `.minutes60`, with titles `不限`, `15 分钟`, `30 分钟`, and `60 分钟`. `configure(selected:)` updates colors and selected traits; selecting a button invokes `onSelect` with its option.

- [ ] **Step 5: Build and commit shared UI**

Run: `xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`

Expected: `** BUILD SUCCEEDED **`.

```bash
git add IsleWhispers/IsleWhispers/UI
git commit -m "feat: add native player design components"
```

---

### Task 5: Adaptive library screen

**Files:**
- Create: `IsleWhispers/IsleWhispers/ViewControllers/LibraryViewController.swift`

**Interfaces:**
- Consumes: `AudioPlayerService`, `PlayerControlsView`, `SoundCell`, `Sound.catalog`, and `.audioPlayerStateDidChange`.
- Produces: `LibraryViewController.init(playerService:)` and navigation to `PlayerViewController`.

- [ ] **Step 1: Build the compact iPhone hierarchy**

Create a root `UIScrollView` and vertical content stack containing:

```swift
let greetingLabel = UILabel()       // 今天 · 给自己一点安静
let titleLabel = UILabel()          // 让声音慢下来。
let compactPlayerCard = UIView()
let controlsView = PlayerControlsView()
let libraryTitleLabel = UILabel()   // 全部声音
let collectionView: UICollectionView
```

Use a three-column compositional layout for compact width. The card shows `正在播放`, a circular wave mark, current title/subtitle, and controls. Do not add progress views or time labels.

- [ ] **Step 2: Build the regular-width iPad hierarchy**

Use a horizontal workspace constrained to the safe area: a 290-point library pane on the left and a flexible player pane on the right. The library uses one-column 52-point rows. The player pane contains current title/subtitle, a large dark wave visual, controls, sleep timer, and status label.

- [ ] **Step 3: Switch layouts by effective container width**

In `viewDidLayoutSubviews`, compare `view.bounds.width` against 720 points. Rebuild constraints only when the compact/regular mode changes. Compact mode activates the scroll hierarchy; regular mode activates the two-column workspace. Do not branch on `UIDevice.current.userInterfaceIdiom`.

- [ ] **Step 4: Wire shared playback state and navigation**

Observe `.audioPlayerStateDidChange`, call `render()` on the main actor, reload selected cells, and update control icons. Cell selection calls `playerService.selectSound(at:)`, then pushes `PlayerViewController(playerService:)`. Previous/play/next closures call the service directly.

- [ ] **Step 5: Build and commit the library screen**

Run: `xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`

Expected: build succeeds without ambiguous-layout warnings in the source.

```bash
git add IsleWhispers/IsleWhispers/ViewControllers/LibraryViewController.swift
git commit -m "feat: add adaptive sound library screen"
```

---

### Task 6: Adaptive immersive player screen

**Files:**
- Create: `IsleWhispers/IsleWhispers/ViewControllers/PlayerViewController.swift`

**Interfaces:**
- Consumes: `AudioPlayerService`, `PlayerControlsView`, `SleepTimerView`, `SoundCell`, and current sound background resources.
- Produces: `PlayerViewController.init(playerService:)`.

- [ ] **Step 1: Build the immersive player surface**

Layer a full-size `UIImageView`, dark blur view, and vertical gradient beneath content. Add a rounded translucent hero panel with eyebrow `环境声 · 独立播放`, current title/subtitle, controls, status label, and retry button. Resolve the image through `Bundle.main.url(forResource: currentSound.backgroundResource, withExtension: "png", subdirectory: "Backgrounds")` and `UIImage(contentsOfFile:)`; fall back to a dark solid background.

- [ ] **Step 2: Build compact iPhone content**

Use a scroll view. Place navigation controls at the top, a minimum 548-point hero region, then timer and a three-column sound grid. The system navigation bar remains hidden on this screen; the custom back button calls `navigationController?.popViewController(animated: true)`.

- [ ] **Step 3: Build regular-width iPad content**

At widths of 720 points or greater, constrain the immersive player to the flexible left column and a 300-point sidebar to the right. Put sleep timer and a one-column sound list in the sidebar. Keep the hero panel flexible in both portrait and landscape.

- [ ] **Step 4: Wire rendering and interactions**

Observe `.audioPlayerStateDidChange`; update the background, title, subtitle, selected timer, selected sound, status, and play icon. Timer choices call `setSleepTimer(_:)`; sound choices call `selectSound(at:)` without pushing another controller. Previous/next preserve current play intent through the service.

- [ ] **Step 5: Build and commit the immersive screen**

Run: `xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`

Expected: `** BUILD SUCCEEDED **`.

```bash
git add IsleWhispers/IsleWhispers/ViewControllers/PlayerViewController.swift
git commit -m "feat: add immersive adaptive player screen"
```

---

### Task 7: Application wiring and lifecycle reconciliation

**Files:**
- Modify: `IsleWhispers/IsleWhispers/SceneDelegate.swift`
- Modify: `IsleWhispers/IsleWhispers/AppDelegate.swift`

**Interfaces:**
- Consumes: `AudioPlayerService.shared` and `LibraryViewController.init(playerService:)`.
- Produces: A window-attached navigation hierarchy and lifecycle sleep-timer correction.

- [ ] **Step 1: Replace storyboard-driven scene setup**

```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let root = LibraryViewController(playerService: .shared)
    let navigationController = UINavigationController(rootViewController: root)
    navigationController.setNavigationBarHidden(true, animated: false)
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = navigationController
    window.makeKeyAndVisible()
    self.window = window
}

func sceneDidBecomeActive(_ scene: UIScene) {
    AudioPlayerService.shared.reconcileSleepTimer()
}
```

- [ ] **Step 2: Configure global UIKit appearance without changing adjacent template behavior**

In `application(_:didFinishLaunchingWithOptions:)`, set `UIView.appearance().tintColor = AppTheme.accent` and return `true`. Do not add Core Data or networking setup.

- [ ] **Step 3: Run all tests and build**

```bash
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test CODE_SIGNING_ALLOWED=NO
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST SUCCEEDED **` and `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit lifecycle wiring**

```bash
git add IsleWhispers/IsleWhispers/SceneDelegate.swift IsleWhispers/IsleWhispers/AppDelegate.swift
git commit -m "feat: launch native ambient player"
```

---

### Task 8: Device-matrix verification and final cleanup

**Files:**
- Modify only files directly responsible for verified defects.

**Interfaces:**
- Consumes: Complete application.
- Produces: Verified iPhone/iPad build with no progress UI and correct looping behavior.

- [ ] **Step 1: Verify source-level constraints**

Run:

```bash
rg -n "UIProgressView|currentTime|duration|timeupdate|progress" IsleWhispers/IsleWhispers --glob '*.swift'
find IsleWhispers/IsleWhispers/Resources/Audio -name '*.caf' | wc -l
find IsleWhispers/IsleWhispers/Resources/Backgrounds -name '*.png' | wc -l
git diff --check
```

Expected: no playback-progress implementation matches; both resource counts are 15; `git diff --check` is clean.

- [ ] **Step 2: Run the automated suite**

Run: `xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test CODE_SIGNING_ALLOWED=NO`

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Inspect the four required layouts**

Launch and capture the library and player screens on:

- Small iPhone portrait.
- iPhone 17 Pro portrait.
- iPad portrait.
- iPad landscape and one narrow split-view width.

Confirm safe-area clearance, no horizontal overflow, 44-point controls, three-column compact sound grid, one-column iPad sound list, and the 720-point single/two-column transition.

- [ ] **Step 4: Verify audio behavior on a real device or capable simulator**

Confirm one sound loops past its natural end, previous/next wraps, switching while playing continues, switching while paused remains paused, sleep timer stops without advancing, background playback continues, lock-screen commands work, and route removal pauses.

- [ ] **Step 5: Run final status checks**

```bash
git status --short
git diff --check
git log --oneline -8
```

Expected: only intentional project changes remain, no whitespace errors, and each implementation commit has a scoped purpose.
