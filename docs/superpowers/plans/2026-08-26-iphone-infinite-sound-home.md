# iPhone Infinite Sound Home Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the existing overview/player navigation with an iPhone-only portrait app containing an infinite auto-playing sound carousel, persisted recent sounds, mute control, and a grouped sound-library Tab.

**Architecture:** A `RootTabBarController` owns one shared `AudioPlayerService` and `RecentSoundsStore`, then coordinates `HomeViewController` and `SoundLibraryViewController`. The home screen delegates physical paging and recentering to `InfiniteSoundCarousel`; every selection path converges on one `selectAndPlaySound(at:)` method so audio, recent history, carousel position, and both Tabs remain synchronized.

**Tech Stack:** Swift 5, UIKit, Auto Layout, SnapKit 5.7 through CocoaPods, AVFoundation, MediaPlayer, UserDefaults, XCTest, iOS 15+

**Spec:** `docs/superpowers/specs/2026-08-26-iphone-infinite-sound-home-design.md`

## Global Constraints

- Minimum deployment target remains iOS 15.0.
- The application supports iPhone only: `TARGETED_DEVICE_FAMILY = 1` and `UIInterfaceOrientationPortrait` only.
- Use UIKit and programmatic SnapKit constraints; do not add another dependency.
- Keep all 15 existing CAF sounds and their matching PNG backgrounds without renaming them.
- Keep `AVAudioPlayer.numberOfLoops = -1`.
- Do not add a progress bar, elapsed-time label, duration label, playback-progress timer, or time-driven carousel.
- Preserve background playback, lock-screen commands, sleep timers, interruptions, route removal, and Now Playing behavior.
- Preserve unrelated working-tree changes. The currently modified `LibraryViewController`, `PlayerViewController`, and their focused tests are related predecessor UI work; remove them only in Task 8 after their approved behavior has migrated to the new screens.
- Use explicit `git add` paths for every commit. Never stage the whole working tree.

---

## File Map

### Domain and persistence

- Modify `IsleWhispers/IsleWhispers/Models/Sound.swift`: add stable identity and one of three categories to every sound.
- Create `IsleWhispers/IsleWhispers/Persistence/RecentSoundsStore.swift`: persist, filter, deduplicate, reorder, and cap six recent sound identifiers.
- Create `IsleWhispers/IsleWhispers/Playback/InfiniteCarouselIndexing.swift`: pure physical/logical index mapping for three-segment paging.
- Modify `IsleWhispers/IsleWhispers/Services/AudioPlayerService.swift`: add select-and-autoplay and session-only mute state.

### Reusable UI

- Create `IsleWhispers/IsleWhispers/UI/SoundArtwork.swift`: load bundled background images with a warm gradient fallback.
- Create `IsleWhispers/IsleWhispers/UI/SoundCarouselCell.swift`: full-height crisp artwork card with title treatment.
- Create `IsleWhispers/IsleWhispers/UI/SoundCarouselFlowLayout.swift`: centered snapping with adjacent-page peeking.
- Create `IsleWhispers/IsleWhispers/UI/InfiniteSoundCarousel.swift`: three-segment collection view, transforms, recentering, transition progress, and accessible logical navigation.
- Create `IsleWhispers/IsleWhispers/UI/RecentSoundCell.swift`: portrait capsule artwork card used by recent sounds.
- Create `IsleWhispers/IsleWhispers/UI/LibrarySoundCardCell.swift`: artwork card used by grouped library sections.
- Modify `IsleWhispers/IsleWhispers/UI/Theme.swift`: add warm screen-overlay and Tab styling tokens needed by the new screens.

### Screens and app wiring

- Create `IsleWhispers/IsleWhispers/ViewControllers/HomeViewController.swift`: full-screen home composition, single selection flow, mute, recent modal, play/pause, sleep timer, and background transition.
- Create `IsleWhispers/IsleWhispers/ViewControllers/RecentSoundsViewController.swift`: full-screen recent-sounds overlay.
- Create `IsleWhispers/IsleWhispers/ViewControllers/SoundLibraryViewController.swift`: category sections and responsive cards.
- Create `IsleWhispers/IsleWhispers/ViewControllers/RootTabBarController.swift`: two Tabs and library-to-home coordination.
- Modify `IsleWhispers/IsleWhispers/SceneDelegate.swift`: install the root Tab controller.
- Modify `IsleWhispers/IsleWhispers.xcodeproj/project.pbxproj`: iPhone-only target family and portrait-only orientation.
- Delete `IsleWhispers/IsleWhispers/ViewControllers/LibraryViewController.swift` after migration.
- Delete `IsleWhispers/IsleWhispers/ViewControllers/PlayerViewController.swift` after migration.
- Delete now-unused `IsleWhispers/IsleWhispers/UI/PlayerControlsView.swift` and `IsleWhispers/IsleWhispers/UI/SoundCell.swift` after migration.

### Tests

- Create `IsleWhispersTests/SoundCatalogGroupingTests.swift`.
- Create `IsleWhispersTests/RecentSoundsStoreTests.swift`.
- Modify `IsleWhispersTests/AudioPlayerPersistenceTests.swift`.
- Create `IsleWhispersTests/InfiniteCarouselIndexingTests.swift`.
- Create `IsleWhispersTests/InfiniteSoundCarouselTests.swift`.
- Create `IsleWhispersTests/RecentSoundsViewControllerTests.swift`.
- Create `IsleWhispersTests/SoundLibraryViewControllerTests.swift`.
- Create `IsleWhispersTests/HomeViewControllerTests.swift`.
- Create `IsleWhispersTests/RootTabBarControllerTests.swift`.
- Create `IsleWhispersTests/AppConfigurationTests.swift`.
- Delete `IsleWhispersTests/LibraryViewControllerTests.swift` after equivalent coverage migrates.
- Delete `IsleWhispersTests/PlayerViewControllerLayoutTests.swift` after equivalent coverage migrates.

---

### Task 1: Categorized catalog and recent-sounds persistence

**Files:**
- Modify: `IsleWhispers/IsleWhispers/Models/Sound.swift`
- Create: `IsleWhispers/IsleWhispers/Persistence/RecentSoundsStore.swift`
- Create: `IsleWhispersTests/SoundCatalogGroupingTests.swift`
- Create: `IsleWhispersTests/RecentSoundsStoreTests.swift`

**Interfaces:**
- Consumes: `Sound.catalog`, existing stable `audioResource` values, injectable `UserDefaults` suites.
- Produces: `SoundCategory`, `Sound.id`, `Sound.category`, `Sound.catalogByCategory`, `RecentSoundsStore.recentSounds`, and `RecentSoundsStore.record(_:)`.

- [ ] **Step 1: Write failing category and recent-history tests**

```swift
import XCTest
@testable import IsleWhispers

final class SoundCatalogGroupingTests: XCTestCase {
    func testCategoriesContainAllSoundsExactlyOnce() {
        let grouped = Sound.catalogByCategory
        XCTAssertEqual(SoundCategory.allCases, [.nature, .life, .atmosphere])
        XCTAssertEqual(grouped[.nature]?.map(\.title), [
            "雷声", "雨声", "水流", "风声", "河流", "农场", "鲸歌"
        ])
        XCTAssertEqual(grouped[.life]?.map(\.title), [
            "茶香", "火炉", "游艇", "火车", "风铃"
        ])
        XCTAssertEqual(grouped[.atmosphere]?.map(\.title), [
            "白昼", "夜晚", "太空"
        ])
        XCTAssertEqual(grouped.values.flatMap { $0 }.map(\.id).count, 15)
        XCTAssertEqual(Set(grouped.values.flatMap { $0 }.map(\.id)).count, 15)
    }
}

final class RecentSoundsStoreTests: XCTestCase {
    func testRecordsUniqueMostRecentSixAndPersistsThem() {
        let suite = "RecentSoundsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RecentSoundsStore(defaults: defaults)

        Sound.catalog.prefix(7).forEach(store.record)
        store.record(Sound.catalog[2])

        XCTAssertEqual(store.recentSounds.map(\.id), [
            Sound.catalog[2].id,
            Sound.catalog[6].id,
            Sound.catalog[5].id,
            Sound.catalog[4].id,
            Sound.catalog[3].id,
            Sound.catalog[1].id
        ])
        XCTAssertEqual(
            RecentSoundsStore(defaults: defaults).recentSounds.map(\.id),
            store.recentSounds.map(\.id)
        )
    }

    func testDropsUnknownPersistedIdentifiers() {
        let suite = "RecentSoundsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["removed-sound", Sound.catalog[4].id], forKey: RecentSoundsStore.defaultsKey)

        XCTAssertEqual(RecentSoundsStore(defaults: defaults).recentSounds.map(\.id), [Sound.catalog[4].id])
    }
}
```

- [ ] **Step 2: Run the focused tests and confirm RED**

Run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:IsleWhispersTests/SoundCatalogGroupingTests \
  -only-testing:IsleWhispersTests/RecentSoundsStoreTests \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because `SoundCategory`, `Sound.id`, `Sound.catalogByCategory`, and `RecentSoundsStore` do not exist.

- [ ] **Step 3: Add categories and stable identity to the catalog**

```swift
enum SoundCategory: String, CaseIterable, Sendable {
    case nature = "自然"
    case life = "生活"
    case atmosphere = "氛围"
}

struct Sound: Equatable, Hashable, Sendable, Identifiable {
    let title: String
    let subtitle: String
    let audioResource: String
    let backgroundResource: String
    let category: SoundCategory

    var id: String { audioResource }

    static var catalogByCategory: [SoundCategory: [Sound]] {
        Dictionary(grouping: catalog, by: \.category)
    }
}
```

Assign categories directly in the 15 existing catalog entries using the exact groups asserted in Step 1. Do not reorder `Sound.catalog`; existing selected-index persistence depends on its current order.

- [ ] **Step 4: Implement the six-item persisted recent store**

```swift
final class RecentSoundsStore {
    static let defaultsKey = "recentSoundResourceIDs"

    private let defaults: UserDefaults
    private(set) var recentSounds: [Sound]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let ids = defaults.stringArray(forKey: Self.defaultsKey) ?? []
        let byID = Dictionary(uniqueKeysWithValues: Sound.catalog.map { ($0.id, $0) })
        recentSounds = ids.compactMap { byID[$0] }
        persist()
    }

    func record(_ sound: Sound) {
        recentSounds.removeAll { $0.id == sound.id }
        recentSounds.insert(sound, at: 0)
        recentSounds = Array(recentSounds.prefix(6))
        persist()
    }

    private func persist() {
        defaults.set(recentSounds.map(\.id), forKey: Self.defaultsKey)
    }
}
```

- [ ] **Step 5: Run the focused tests and confirm GREEN**

Run the Step 2 command again.

Expected: both test classes pass with 15 unique categorized sounds and six persisted recent sounds.

- [ ] **Step 6: Commit the domain and persistence slice**

```bash
git add IsleWhispers/IsleWhispers/Models/Sound.swift \
  IsleWhispers/IsleWhispers/Persistence/RecentSoundsStore.swift \
  IsleWhispersTests/SoundCatalogGroupingTests.swift \
  IsleWhispersTests/RecentSoundsStoreTests.swift
git commit -m "feat: categorize sounds and persist recents"
```

---

### Task 2: Auto-play selection and session-only mute

**Files:**
- Modify: `IsleWhispers/IsleWhispers/Services/AudioPlayerService.swift`
- Modify: `IsleWhispersTests/AudioPlayerPersistenceTests.swift`

**Interfaces:**
- Consumes: existing `AudioPlayerService.selectSound(at:)`, `play()`, state notifications, and real bundled CAF fixtures.
- Produces: `AudioPlayerService.isMuted`, `selectAndPlay(at:)`, `setMuted(_:)`, and `toggleMuted()`.

- [ ] **Step 1: Add failing real-service tests**

```swift
@MainActor
func testSelectAndPlayStartsNewSoundEvenWhenPreviouslyPaused() {
    let (service, defaults, suite) = makeService()
    defer { defaults.removePersistentDomain(forName: suite) }

    XCTAssertFalse(service.isPlaying)
    service.selectAndPlay(at: 4)

    XCTAssertEqual(service.selectedIndex, 4)
    XCTAssertTrue(service.isPlaying)
}

@MainActor
func testMuteDoesNotPauseAndSurvivesSoundSelection() {
    let (service, defaults, suite) = makeService()
    defer { defaults.removePersistentDomain(forName: suite) }
    service.play()

    service.setMuted(true)
    XCTAssertTrue(service.isMuted)
    XCTAssertTrue(service.isPlaying)

    service.selectAndPlay(at: 7)
    XCTAssertTrue(service.isMuted)
    XCTAssertTrue(service.isPlaying)

    service.toggleMuted()
    XCTAssertFalse(service.isMuted)
    XCTAssertTrue(service.isPlaying)
}
```

Add this test helper inside `AudioPlayerPersistenceTests`:

```swift
@MainActor
private func makeService() -> (AudioPlayerService, UserDefaults, String) {
    let suite = "AudioPlayerPersistenceTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    return (
        AudioPlayerService(defaults: defaults, configureSystemIntegration: false),
        defaults,
        suite
    )
}
```

- [ ] **Step 2: Run focused tests and confirm RED**

Run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:IsleWhispersTests/AudioPlayerPersistenceTests/testSelectAndPlayStartsNewSoundEvenWhenPreviouslyPaused \
  -only-testing:IsleWhispersTests/AudioPlayerPersistenceTests/testMuteDoesNotPauseAndSurvivesSoundSelection \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because the new selection and mute APIs are missing.

- [ ] **Step 3: Implement select-and-play and mute without changing pause semantics**

Add state and APIs:

```swift
private(set) var isMuted = false

func selectAndPlay(at index: Int) {
    state.select(index: index, count: Sound.catalog.count)
    defaults.set(selectedIndex, forKey: Self.selectedSoundDefaultsKey)
    prepareSelectedSound()
    play()
}

func setMuted(_ muted: Bool) {
    guard isMuted != muted else { return }
    isMuted = muted
    player?.volume = muted ? 0 : 1
    publishState()
}

func toggleMuted() {
    setMuted(!isMuted)
}
```

Inside `prepareSelectedSound()`, set the prepared player volume before assigning it:

```swift
preparedPlayer.volume = isMuted ? 0 : 1
player = preparedPlayer
```

Keep `selectSound(at:)` unchanged for remote previous/next behavior, which must continue only when playback was already active.

- [ ] **Step 4: Run all audio-service tests**

Run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:IsleWhispersTests/AudioPlayerPersistenceTests \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: all existing interruption, route, remote-command, timer, persistence, autoplay, and mute tests pass.

- [ ] **Step 5: Commit the service slice**

```bash
git add IsleWhispers/IsleWhispers/Services/AudioPlayerService.swift \
  IsleWhispersTests/AudioPlayerPersistenceTests.swift
git commit -m "feat: add autoplay selection and mute"
```

---

### Task 3: Pure infinite-carousel index mapping

**Files:**
- Create: `IsleWhispers/IsleWhispers/Playback/InfiniteCarouselIndexing.swift`
- Create: `IsleWhispersTests/InfiniteCarouselIndexingTests.swift`

**Interfaces:**
- Consumes: a positive logical item count.
- Produces: `physicalItemCount`, `logicalIndex(for:)`, `centeredPhysicalIndex(for:)`, and `recenteredPhysicalIndex(after:)`.

- [ ] **Step 1: Write failing mapping tests**

```swift
import XCTest
@testable import IsleWhispers

final class InfiniteCarouselIndexingTests: XCTestCase {
    private let indexing = InfiniteCarouselIndexing(logicalCount: 15)

    func testMapsThreePhysicalSegmentsToLogicalCatalog() {
        XCTAssertEqual(indexing.physicalItemCount, 45)
        XCTAssertEqual(indexing.logicalIndex(for: 0), 0)
        XCTAssertEqual(indexing.logicalIndex(for: 16), 1)
        XCTAssertEqual(indexing.logicalIndex(for: 44), 14)
    }

    func testCentersLogicalIndexInMiddleSegment() {
        XCTAssertEqual(indexing.centeredPhysicalIndex(for: 0), 15)
        XCTAssertEqual(indexing.centeredPhysicalIndex(for: 14), 29)
    }

    func testOuterSegmentsRecenterToSameLogicalItem() {
        XCTAssertEqual(indexing.recenteredPhysicalIndex(after: 2), 17)
        XCTAssertNil(indexing.recenteredPhysicalIndex(after: 17))
        XCTAssertEqual(indexing.recenteredPhysicalIndex(after: 42), 27)
    }
}
```

- [ ] **Step 2: Run the test and confirm RED**

Run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:IsleWhispersTests/InfiniteCarouselIndexingTests \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because `InfiniteCarouselIndexing` does not exist.

- [ ] **Step 3: Implement the mapper**

```swift
struct InfiniteCarouselIndexing: Equatable {
    let logicalCount: Int

    init(logicalCount: Int) {
        precondition(logicalCount > 0)
        self.logicalCount = logicalCount
    }

    var physicalItemCount: Int { logicalCount * 3 }

    func logicalIndex(for physicalIndex: Int) -> Int {
        (physicalIndex % logicalCount + logicalCount) % logicalCount
    }

    func centeredPhysicalIndex(for logicalIndex: Int) -> Int {
        logicalCount + self.logicalIndex(for: logicalIndex)
    }

    func recenteredPhysicalIndex(after physicalIndex: Int) -> Int? {
        guard physicalIndex < logicalCount || physicalIndex >= logicalCount * 2 else {
            return nil
        }
        return centeredPhysicalIndex(for: logicalIndex(for: physicalIndex))
    }
}
```

- [ ] **Step 4: Run the test and confirm GREEN**

Run the Step 2 command again.

Expected: all three mapping tests pass.

- [ ] **Step 5: Commit the pure paging model**

```bash
git add IsleWhispers/IsleWhispers/Playback/InfiniteCarouselIndexing.swift \
  IsleWhispersTests/InfiniteCarouselIndexingTests.swift
git commit -m "feat: add infinite carousel indexing"
```

---

### Task 4: Infinite carousel UI, snapping, and transition callbacks

**Files:**
- Create: `IsleWhispers/IsleWhispers/UI/SoundArtwork.swift`
- Create: `IsleWhispers/IsleWhispers/UI/SoundCarouselCell.swift`
- Create: `IsleWhispers/IsleWhispers/UI/SoundCarouselFlowLayout.swift`
- Create: `IsleWhispers/IsleWhispers/UI/InfiniteSoundCarousel.swift`
- Create: `IsleWhispersTests/InfiniteSoundCarouselTests.swift`

**Interfaces:**
- Consumes: `Sound.catalog` and `InfiniteCarouselIndexing`.
- Produces: `InfiniteSoundCarousel.onSettled`, `onTransition`, `displayedLogicalIndex`, `setSelectedSound(index:animated:)`, and `settle(onPhysicalIndex:)`.

- [ ] **Step 1: Write failing carousel behavior tests**

```swift
import XCTest
@testable import IsleWhispers

final class InfiniteSoundCarouselTests: XCTestCase {
    @MainActor
    func testUsesThreeSegmentsAndCentersSelectedSound() throws {
        let carousel = InfiniteSoundCarousel(sounds: Sound.catalog, selectedIndex: 2)
        carousel.frame = CGRect(x: 0, y: 0, width: 390, height: 520)
        carousel.layoutIfNeeded()

        XCTAssertEqual(carousel.physicalItemCount, 45)
        XCTAssertEqual(carousel.displayedLogicalIndex, 2)
        XCTAssertEqual(carousel.centeredPhysicalIndex, 17)
    }

    @MainActor
    func testSettlingNewSoundReportsOnceAndRecentersOuterSegment() {
        let carousel = InfiniteSoundCarousel(sounds: Sound.catalog, selectedIndex: 2)
        var settled: [Int] = []
        carousel.onSettled = { settled.append($0) }

        carousel.settle(onPhysicalIndex: 4)
        XCTAssertEqual(settled, [4])
        XCTAssertEqual(carousel.centeredPhysicalIndex, 19)

        carousel.settle(onPhysicalIndex: 19)
        XCTAssertEqual(settled, [4])
    }

    @MainActor
    func testExposesOneLogicalAccessibilityElementInsteadOfDuplicates() {
        let carousel = InfiniteSoundCarousel(sounds: Sound.catalog, selectedIndex: 2)
        XCTAssertTrue(carousel.isAccessibilityElement)
        XCTAssertEqual(carousel.accessibilityValue, "雨声，3 / 15")
        XCTAssertTrue(carousel.collectionAccessibilityElementsHidden)
    }
}
```

- [ ] **Step 2: Run focused tests and confirm RED**

Run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:IsleWhispersTests/InfiniteSoundCarouselTests \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because the carousel and its UI collaborators do not exist.

- [ ] **Step 3: Add artwork loading with a deterministic fallback**

```swift
enum SoundArtwork {
    static func image(for sound: Sound, bundle: Bundle = .main) -> UIImage? {
        let url = bundle.url(
            forResource: sound.backgroundResource,
            withExtension: "png",
            subdirectory: "Backgrounds"
        ) ?? bundle.url(forResource: sound.backgroundResource, withExtension: "png")
        return url.flatMap { UIImage(contentsOfFile: $0.path) }
    }

    static let fallbackColors = [
        UIColor(red: 0.73, green: 0.55, blue: 0.56, alpha: 1).cgColor,
        UIColor(red: 0.98, green: 0.91, blue: 0.79, alpha: 1).cgColor
    ]
}
```

The cells and screens use `fallbackColors` in a `CAGradientLayer` whenever `image(for:)` returns `nil`.

- [ ] **Step 4: Implement the centered flow layout and card cell**

`SoundCarouselFlowLayout` uses a 28pt total horizontal reveal and 12pt spacing:

```swift
final class SoundCarouselFlowLayout: UICollectionViewFlowLayout {
    override func prepare() {
        super.prepare()
        guard let collectionView else { return }
        scrollDirection = .horizontal
        minimumLineSpacing = 12
        let width = max(collectionView.bounds.width - 56, 1)
        itemSize = CGSize(width: width, height: collectionView.bounds.height)
        sectionInset = UIEdgeInsets(top: 0, left: 28, bottom: 0, right: 28)
    }

    override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint,
        withScrollingVelocity velocity: CGPoint
    ) -> CGPoint {
        guard let collectionView else { return proposedContentOffset }
        let target = CGRect(
            x: proposedContentOffset.x,
            y: 0,
            width: collectionView.bounds.width,
            height: collectionView.bounds.height
        )
        let centerX = proposedContentOffset.x + collectionView.bounds.width / 2
        let attributes = super.layoutAttributesForElements(in: target) ?? []
        let nearest = attributes.min { abs($0.center.x - centerX) < abs($1.center.x - centerX) }
        return CGPoint(x: (nearest?.center.x ?? centerX) - collectionView.bounds.width / 2, y: 0)
    }
}
```

`SoundCarouselCell.configure(sound:)` loads crisp artwork with `.scaleAspectFill`, clips to a 30pt continuous corner radius, overlays a bottom gradient, and renders title/subtitle in white. Set `isAccessibilityElement = false`; the carousel owns logical accessibility.

```swift
func configure(sound: Sound) {
    artworkImageView.image = SoundArtwork.image(for: sound)
    fallbackGradient.isHidden = artworkImageView.image != nil
    titleLabel.text = sound.title
    subtitleLabel.text = sound.subtitle
    isAccessibilityElement = false
}
```

- [ ] **Step 5: Implement the three-segment carousel**

Use these public/internal signatures exactly:

```swift
final class InfiniteSoundCarousel: UIView {
    var onSettled: ((Int) -> Void)?
    var onTransition: ((_ from: Int, _ to: Int, _ progress: CGFloat) -> Void)?

    private(set) var displayedLogicalIndex: Int
    var physicalItemCount: Int { indexing.physicalItemCount }
    var centeredPhysicalIndex: Int { indexing.centeredPhysicalIndex(for: displayedLogicalIndex) }
    var collectionAccessibilityElementsHidden: Bool { collectionView.accessibilityElementsHidden }

    init(sounds: [Sound], selectedIndex: Int)
    func setSelectedSound(index: Int, animated: Bool)
    func settle(onPhysicalIndex physicalIndex: Int)
}
```

`settle(onPhysicalIndex:)` performs this order:

```swift
let logical = indexing.logicalIndex(for: physicalIndex)
if let centered = indexing.recenteredPhysicalIndex(after: physicalIndex) {
    scrollToPhysicalItem(centered, animated: false)
}
guard logical != displayedLogicalIndex else { return }
displayedLogicalIndex = logical
updateAccessibilityValue()
onSettled?(logical)
```

Call it from `scrollViewDidEndDecelerating`, `scrollViewDidEndScrollingAnimation`, and `scrollViewDidEndDragging` when `decelerate == false`. During `scrollViewDidScroll`, calculate each visible cell's normalized center distance, apply scale `1 - 0.06 * min(distance, 1)` and alpha `1 - 0.25 * min(distance, 1)`, then report the neighboring logical indices and fractional progress through `onTransition`.

Make the carousel one `.adjustable` accessibility element. `accessibilityIncrement()` and `accessibilityDecrement()` call `setSelectedSound` for the next or previous logical index and then `onSettled` once; update `accessibilityValue` as `"<title>，<position> / <count>"`. Set `collectionView.accessibilityElementsHidden = true`.

- [ ] **Step 6: Run focused carousel tests and layout sanity build**

Run the Step 2 command again, then run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

Expected: carousel tests pass and the generic simulator build ends with `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit the carousel slice**

```bash
git add IsleWhispers/IsleWhispers/UI/SoundArtwork.swift \
  IsleWhispers/IsleWhispers/UI/SoundCarouselCell.swift \
  IsleWhispers/IsleWhispers/UI/SoundCarouselFlowLayout.swift \
  IsleWhispers/IsleWhispers/UI/InfiniteSoundCarousel.swift \
  IsleWhispersTests/InfiniteSoundCarouselTests.swift
git commit -m "feat: add infinite sound carousel"
```

---

### Task 5: Recent-sounds full-screen overlay

**Files:**
- Create: `IsleWhispers/IsleWhispers/UI/RecentSoundCell.swift`
- Create: `IsleWhispers/IsleWhispers/ViewControllers/RecentSoundsViewController.swift`
- Create: `IsleWhispersTests/RecentSoundsViewControllerTests.swift`

**Interfaces:**
- Consumes: a `[Sound]` snapshot and selected sound ID.
- Produces: `RecentSoundsViewController.onSelect`, `onClose`, three-column card layout, selected styling, and empty state.

- [ ] **Step 1: Write failing overlay tests**

```swift
import XCTest
@testable import IsleWhispers

final class RecentSoundsViewControllerTests: XCTestCase {
    @MainActor
    func testShowsSixRecentSoundsInThreeColumnsAndReportsSelection() throws {
        let sounds = Array(Sound.catalog.prefix(6))
        let controller = RecentSoundsViewController(sounds: sounds, selectedSoundID: sounds[2].id)
        var selected: Sound?
        controller.onSelect = { selected = $0 }
        layout(controller, size: CGSize(width: 390, height: 844))

        let collection = try XCTUnwrap(findCollectionView(in: controller.view))
        XCTAssertEqual(collection.numberOfItems(inSection: 0), 6)
        let frames = (0..<3).compactMap {
            collection.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: $0, section: 0))?.frame
        }
        XCTAssertEqual(frames[0].minY, frames[1].minY, accuracy: 1)
        XCTAssertEqual(frames[1].minY, frames[2].minY, accuracy: 1)

        controller.collectionView(collection, didSelectItemAt: IndexPath(item: 4, section: 0))
        XCTAssertEqual(selected, sounds[4])
    }

    @MainActor
    func testEmptyRecentsShowsAccessibleEmptyState() {
        let controller = RecentSoundsViewController(sounds: [], selectedSoundID: Sound.catalog[2].id)
        controller.loadViewIfNeeded()
        XCTAssertNotNil(findLabel(text: "还没有最近播放", in: controller.view))
        XCTAssertNotNil(findButton(label: "关闭最近播放", in: controller.view))
    }
}
```

Keep `layout`, `findCollectionView`, `findLabel`, and `findButton` as private test-only hierarchy helpers in this test file.

- [ ] **Step 2: Run tests and confirm RED**

Run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:IsleWhispersTests/RecentSoundsViewControllerTests \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because the recent overlay and cell do not exist.

- [ ] **Step 3: Implement the portrait capsule cell**

`RecentSoundCell.configure(sound:selected:)` uses a vertical image capsule with aspect-fill artwork, a title below it, and a 2pt white selected border plus waveform mark. The cell itself is one button-like accessibility element with `.selected` when active.

```swift
func configure(sound: Sound, selected: Bool) {
    imageView.image = SoundArtwork.image(for: sound)
    fallbackGradient.isHidden = imageView.image != nil
    titleLabel.text = sound.title
    waveformView.isHidden = !selected
    imageContainer.layer.borderWidth = selected ? 2 : 0
    imageContainer.layer.borderColor = selected ? UIColor.white.cgColor : UIColor.clear.cgColor
    accessibilityLabel = "\(sound.title)：\(sound.subtitle)"
    accessibilityTraits = selected ? [.button, .selected] : .button
}
```

- [ ] **Step 4: Implement the full-screen overlay**

Use this contract:

```swift
final class RecentSoundsViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    var onSelect: ((Sound) -> Void)?
    var onClose: (() -> Void)?

    init(sounds: [Sound], selectedSoundID: String)
}
```

Build a warm full-screen background, title `"最近播放"`, top-right close button labeled `"关闭最近播放"`, and a vertically scrolling collection view. The compositional layout uses three equal-width items per row with 16pt group spacing and 14pt section insets. When empty, hide the collection and show `"还没有最近播放"` plus `"播放声音后会出现在这里"`.

On cell selection call `onSelect?(sounds[indexPath.item])`; the presenter owns dismissal so selection and dismissal order remain testable. On close call `onClose?()`.

- [ ] **Step 5: Run focused tests and confirm GREEN**

Run the Step 2 command again.

Expected: both overlay tests pass.

- [ ] **Step 6: Commit the recent overlay**

```bash
git add IsleWhispers/IsleWhispers/UI/RecentSoundCell.swift \
  IsleWhispers/IsleWhispers/ViewControllers/RecentSoundsViewController.swift \
  IsleWhispersTests/RecentSoundsViewControllerTests.swift
git commit -m "feat: add recent sounds overlay"
```

---

### Task 6: Grouped sound-library Tab

**Files:**
- Create: `IsleWhispers/IsleWhispers/UI/LibrarySoundCardCell.swift`
- Create: `IsleWhispers/IsleWhispers/ViewControllers/SoundLibraryViewController.swift`
- Create: `IsleWhispersTests/SoundLibraryViewControllerTests.swift`

**Interfaces:**
- Consumes: `SoundCategory.allCases`, `Sound.catalogByCategory`, and current selected sound ID.
- Produces: `SoundLibraryViewController.onSelect`, `updateSelectedSound(id:)`, three ordered sections, two-column default layout, and one-column accessibility layout.

- [ ] **Step 1: Write failing section, layout, and selection tests**

```swift
import XCTest
@testable import IsleWhispers

final class SoundLibraryViewControllerTests: XCTestCase {
    @MainActor
    func testShowsOrderedGroupsAndAllFifteenSounds() {
        let controller = SoundLibraryViewController(selectedSoundID: Sound.catalog[2].id)
        controller.loadViewIfNeeded()
        XCTAssertEqual(controller.sectionTitles, ["自然", "生活", "氛围"])
        XCTAssertEqual(controller.sectionItemCounts, [7, 5, 3])
        XCTAssertEqual(controller.sectionItemCounts.reduce(0, +), 15)
    }

    @MainActor
    func testSelectingCardReportsCatalogIndex() {
        let controller = SoundLibraryViewController(selectedSoundID: Sound.catalog[2].id)
        var selectedIndex: Int?
        controller.onSelect = { selectedIndex = $0 }
        controller.loadViewIfNeeded()

        controller.selectItemForTesting(section: 1, item: 2)

        XCTAssertEqual(selectedIndex, Sound.catalog.firstIndex { $0.title == "游艇" })
    }

    @MainActor
    func testDefaultUsesTwoColumnsAndAccessibilityUsesOne() {
        let controller = SoundLibraryViewController(selectedSoundID: Sound.catalog[2].id)
        XCTAssertEqual(controller.columnCount(for: .large), 2)
        XCTAssertEqual(controller.columnCount(for: .accessibilityExtraExtraExtraLarge), 1)
    }
}
```

- [ ] **Step 2: Run tests and confirm RED**

Run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:IsleWhispersTests/SoundLibraryViewControllerTests \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because the grouped library types are missing.

- [ ] **Step 3: Implement the image card and grouped controller**

Use this controller contract:

```swift
final class SoundLibraryViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    var onSelect: ((Int) -> Void)?
    private(set) var selectedSoundID: String

    var sectionTitles: [String] { sections.map { $0.category.rawValue } }
    var sectionItemCounts: [Int] { sections.map { $0.sounds.count } }

    init(selectedSoundID: String)
    func updateSelectedSound(id: String)
    func columnCount(for category: UIContentSizeCategory) -> Int
    func selectItemForTesting(section: Int, item: Int)
}
```

Keep a private ordered section model built from `SoundCategory.allCases`. `selectItemForTesting` must call the same private selection method used by `collectionView(_:didSelectItemAt:)`, not duplicate selection logic.

`LibrarySoundCardCell` shows aspect-fill artwork, warm overlay, title, subtitle, and a white selected border. Use a compositional layout with two fractional-width cards by default and one full-width card for accessibility categories. Invalidate and reload on `UIContentSizeCategory.didChangeNotification`.

```swift
func configure(sound: Sound, selected: Bool) {
    artworkImageView.image = SoundArtwork.image(for: sound)
    fallbackGradient.isHidden = artworkImageView.image != nil
    titleLabel.text = sound.title
    subtitleLabel.text = sound.subtitle
    contentView.layer.borderWidth = selected ? 2 : 0
    contentView.layer.borderColor = selected ? UIColor.white.cgColor : UIColor.clear.cgColor
    accessibilityLabel = "\(sound.title)：\(sound.subtitle)"
    accessibilityTraits = selected ? [.button, .selected] : .button
}
```

- [ ] **Step 4: Run focused tests and confirm GREEN**

Run the Step 2 command again.

Expected: three library tests pass.

- [ ] **Step 5: Commit the grouped library**

```bash
git add IsleWhispers/IsleWhispers/UI/LibrarySoundCardCell.swift \
  IsleWhispers/IsleWhispers/ViewControllers/SoundLibraryViewController.swift \
  IsleWhispersTests/SoundLibraryViewControllerTests.swift
git commit -m "feat: add grouped sound library"
```

---

### Task 7: Full-height home screen and single selection flow

**Files:**
- Modify: `IsleWhispers/IsleWhispers/UI/Theme.swift`
- Create: `IsleWhispers/IsleWhispers/ViewControllers/HomeViewController.swift`
- Create: `IsleWhispersTests/HomeViewControllerTests.swift`

**Interfaces:**
- Consumes: `AudioPlayerService`, `RecentSoundsStore`, `InfiniteSoundCarousel`, `RecentSoundsViewController`, `SleepTimerView`, and `SoundArtwork`.
- Produces: `HomeViewController.selectAndPlaySound(at:animated:)`, `displayedSoundIndex`, top-right mute/recent actions, auto-play on settle, and low-blur background transitions.

- [ ] **Step 1: Write failing behavior and layout tests**

```swift
import XCTest
@testable import IsleWhispers

final class HomeViewControllerTests: XCTestCase {
    @MainActor
    func testSettlingCarouselAutoPlaysOnceAndRecordsRecentSound() throws {
        let context = makeHomeContext()
        defer { context.cleanup() }
        layout(context.controller, size: CGSize(width: 390, height: 844))

        let carousel = try XCTUnwrap(findSubview(InfiniteSoundCarousel.self, in: context.controller.view))
        carousel.settle(onPhysicalIndex: 19)

        XCTAssertEqual(context.service.selectedIndex, 4)
        XCTAssertTrue(context.service.isPlaying)
        XCTAssertEqual(context.store.recentSounds.map(\.id), [Sound.catalog[4].id])
        XCTAssertEqual(context.controller.displayedSoundIndex, 4)
    }

    @MainActor
    func testMuteButtonDoesNotPausePlayback() throws {
        let context = makeHomeContext()
        defer { context.cleanup() }
        context.service.play()
        context.controller.loadViewIfNeeded()
        let mute = try XCTUnwrap(findButton(label: "静音", in: context.controller.view))

        mute.sendActions(for: .touchUpInside)

        XCTAssertTrue(context.service.isMuted)
        XCTAssertTrue(context.service.isPlaying)
        XCTAssertEqual(mute.accessibilityLabel, "恢复声音")
    }

    @MainActor
    func testCarouselFillsSpaceBetweenHeaderAndControlsWithoutProgressUI() throws {
        let context = makeHomeContext()
        defer { context.cleanup() }
        for size in [CGSize(width: 375, height: 667), CGSize(width: 430, height: 932)] {
            layout(context.controller, size: size)
            let carousel = try XCTUnwrap(findSubview(InfiniteSoundCarousel.self, in: context.controller.view))
            let controls = try XCTUnwrap(findView(identifier: "homeControls", in: context.controller.view))

            XCTAssertGreaterThan(carousel.bounds.height, 300)
            XCTAssertLessThanOrEqual(carousel.frame.maxY, controls.frame.minY)
            XCTAssertNil(findSubview(UIProgressView.self, in: context.controller.view))
            XCTAssertFalse(allLabels(in: context.controller.view).contains {
                $0.text?.range(of: #"^\d{1,2}:\d{2}$"#, options: .regularExpression) != nil
            })
        }
    }
}
```

`makeHomeContext()` creates an isolated defaults suite, service with `configureSystemIntegration: false`, store, controller, and cleanup closure. Hierarchy helpers remain private to this test file.

- [ ] **Step 2: Run tests and confirm RED**

Run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:IsleWhispersTests/HomeViewControllerTests \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because `HomeViewController` and its selection contract are missing.

- [ ] **Step 3: Add the warm home-theme tokens**

Add exact reusable tokens to `AppTheme`:

```swift
static let warmRose = UIColor(red: 0.73, green: 0.55, blue: 0.56, alpha: 1)
static let warmCream = UIColor(red: 0.98, green: 0.91, blue: 0.79, alpha: 1)
static let homeOverlay = UIColor.black.withAlphaComponent(0.28)
static let tabBarBackground = UIColor(red: 0.16, green: 0.13, blue: 0.14, alpha: 0.88)
```

- [ ] **Step 4: Implement the home hierarchy and selection flow**

Use this constructor and coordination API:

```swift
final class HomeViewController: UIViewController {
    private let playerService: AudioPlayerService
    private let recentStore: RecentSoundsStore
    private let carousel: InfiniteSoundCarousel
    private(set) var displayedSoundIndex: Int

    init(playerService: AudioPlayerService, recentStore: RecentSoundsStore)

    func selectAndPlaySound(at index: Int, animated: Bool) {
        guard Sound.catalog.indices.contains(index) else { return }
        playerService.selectAndPlay(at: index)
        recentStore.record(Sound.catalog[index])
        displayedSoundIndex = index
        carousel.setSelectedSound(index: index, animated: animated)
        render()
    }
}
```

Wire `carousel.onSettled` to call `selectAndPlaySound(at:animated: false)` only when the settled index differs from `playerService.selectedIndex`. Wire `carousel.onTransition` to update two edge-pinned background image views and their alpha; use `UIVisualEffectView` with `.systemUltraThinMaterialDark` at alpha `0.20`, plus `AppTheme.homeOverlay`. Do not place blur over the crisp carousel cell.

Build the layout with SnapKit:

- Safe-area top header containing greeting/current title and 48pt mute/recent buttons.
- Carousel top equal to header bottom + 12 and bottom equal to controls top - 12; no fixed height.
- `homeControls` vertical container with page dots, a 64pt play/pause button, `SleepTimerView`, retry/status when needed, and no time/progress views.
- Bottom constraint to the view safe area; the enclosing `UITabBarController` automatically reserves the Tab Bar.

The mute button calls `playerService.toggleMuted()`. The recent button creates `RecentSoundsViewController(sounds: recentStore.recentSounds, selectedSoundID: playerService.currentSound.id)`. Its selection closure calls `selectAndPlaySound`, then dismisses; its close closure only dismisses.

Observe `.audioPlayerStateDidChange` and update play/pause, mute label, current sound, status/retry, background, dots, and carousel position. External remote-command selection must reposition the carousel without auto-playing again.

- [ ] **Step 5: Run home tests and all earlier focused suites**

Run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:IsleWhispersTests/HomeViewControllerTests \
  -only-testing:IsleWhispersTests/InfiniteSoundCarouselTests \
  -only-testing:IsleWhispersTests/RecentSoundsViewControllerTests \
  -only-testing:IsleWhispersTests/AudioPlayerPersistenceTests \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: all selected suites pass.

- [ ] **Step 6: Commit the home screen**

```bash
git add IsleWhispers/IsleWhispers/UI/Theme.swift \
  IsleWhispers/IsleWhispers/ViewControllers/HomeViewController.swift \
  IsleWhispersTests/HomeViewControllerTests.swift
git commit -m "feat: build full-height sound home"
```

---

### Task 8: Root Tabs, iPhone-only configuration, and predecessor-screen removal

**Files:**
- Create: `IsleWhispers/IsleWhispers/ViewControllers/RootTabBarController.swift`
- Modify: `IsleWhispers/IsleWhispers/SceneDelegate.swift`
- Modify: `IsleWhispers/IsleWhispers.xcodeproj/project.pbxproj`
- Create: `IsleWhispersTests/RootTabBarControllerTests.swift`
- Create: `IsleWhispersTests/AppConfigurationTests.swift`
- Delete: `IsleWhispers/IsleWhispers/ViewControllers/LibraryViewController.swift`
- Delete: `IsleWhispers/IsleWhispers/ViewControllers/PlayerViewController.swift`
- Delete: `IsleWhispers/IsleWhispers/UI/PlayerControlsView.swift`
- Delete: `IsleWhispers/IsleWhispers/UI/SoundCell.swift`
- Delete: `IsleWhispersTests/LibraryViewControllerTests.swift`
- Delete: `IsleWhispersTests/PlayerViewControllerLayoutTests.swift`

**Interfaces:**
- Consumes: `HomeViewController`, `SoundLibraryViewController`, shared player/store instances.
- Produces: two fixed Tabs, library-to-home selection coordination, iPhone-only portrait build metadata, and no active legacy push flow.

- [ ] **Step 1: Write failing root and configuration tests**

```swift
import XCTest
@testable import IsleWhispers

final class RootTabBarControllerTests: XCTestCase {
    @MainActor
    func testRootContainsHomeAndSoundTabs() {
        let context = makeRootContext()
        defer { context.cleanup() }
        context.controller.loadViewIfNeeded()

        XCTAssertEqual(context.controller.viewControllers?.count, 2)
        XCTAssertEqual(context.controller.viewControllers?.map { $0.tabBarItem.title }, ["首页", "声音"])
    }

    @MainActor
    func testLibrarySelectionAutoPlaysAndReturnsHome() {
        let context = makeRootContext()
        defer { context.cleanup() }
        context.controller.loadViewIfNeeded()
        context.controller.selectedIndex = 1

        context.controller.selectSoundFromLibrary(at: 11)

        XCTAssertEqual(context.controller.selectedIndex, 0)
        XCTAssertEqual(context.service.selectedIndex, 11)
        XCTAssertTrue(context.service.isPlaying)
        XCTAssertEqual(context.store.recentSounds.map(\.id), [Sound.catalog[11].id])
        XCTAssertEqual(context.controller.homeViewController.displayedSoundIndex, 11)
    }

    @MainActor
    func testCarouselSelectionUpdatesLibrarySelectedState() {
        let context = makeRootContext()
        defer { context.cleanup() }
        context.controller.loadViewIfNeeded()

        context.controller.homeViewController.selectAndPlaySound(at: 4, animated: false)

        XCTAssertEqual(context.controller.soundLibraryViewController.selectedSoundID, Sound.catalog[4].id)
    }
}

final class AppConfigurationTests: XCTestCase {
    func testApplicationBuildIsIPhonePortraitOnly() throws {
        let info = try XCTUnwrap(Bundle.main.infoDictionary)
        XCTAssertEqual(info["UIDeviceFamily"] as? [Int], [1])
        XCTAssertEqual(
            info["UISupportedInterfaceOrientations~iphone"] as? [String],
            ["UIInterfaceOrientationPortrait"]
        )
        XCTAssertNil(info["UISupportedInterfaceOrientations~ipad"])
    }
}
```

`makeRootContext()` uses an isolated defaults suite and constructs `RootTabBarController(playerService:recentStore:)`.

- [ ] **Step 2: Run focused tests and confirm RED**

Run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:IsleWhispersTests/RootTabBarControllerTests \
  -only-testing:IsleWhispersTests/AppConfigurationTests \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because the root controller is missing and the built app still declares iPad device family support.

- [ ] **Step 3: Implement root coordination and scene startup**

Use this root contract:

```swift
final class RootTabBarController: UITabBarController {
    let homeViewController: HomeViewController
    let soundLibraryViewController: SoundLibraryViewController
    private let playerService: AudioPlayerService
    private let recentStore: RecentSoundsStore

    init(playerService: AudioPlayerService, recentStore: RecentSoundsStore)

    func selectSoundFromLibrary(at index: Int) {
        homeViewController.selectAndPlaySound(at: index, animated: false)
        soundLibraryViewController.updateSelectedSound(id: Sound.catalog[index].id)
        selectedIndex = 0
    }
}
```

Give the Tabs titles `"首页"` and `"声音"`, SF Symbols `house.fill` and `square.grid.2x2.fill`, a warm translucent background, and white selected tint. Assign the library controller's `onSelect` closure to `selectSoundFromLibrary(at:)`.

Observe `.audioPlayerStateDidChange` in the root controller and call `soundLibraryViewController.updateSelectedSound(id: playerService.currentSound.id)`. Remove the observer in `deinit`. This keeps the library selection synchronized after carousel, recent-overlay, remote-command, and lock-screen changes, not only after a library tap.

Replace `SceneDelegate` root setup with:

```swift
let root = RootTabBarController(
    playerService: .shared,
    recentStore: RecentSoundsStore()
)
window.rootViewController = root
```

- [ ] **Step 4: Make the built application iPhone portrait only**

In both app Debug and Release configurations:

```text
TARGETED_DEVICE_FAMILY = 1;
INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;
```

Remove `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad` and `INFOPLIST_KEY_UIRequiresFullScreen` from both configurations. Set the test target's `TARGETED_DEVICE_FAMILY = 1` in Debug and Release so hosted tests use the same device family.

- [ ] **Step 5: Remove the superseded active-flow files**

Delete the two predecessor view controllers and their focused tests only after Tasks 5–7 pass. Delete `PlayerControlsView` and `SoundCell` after `rg` confirms the new sources do not reference them:

```bash
rg -n 'LibraryViewController|PlayerViewController|PlayerControlsView|SoundCell' \
  IsleWhispers/IsleWhispers IsleWhispersTests
```

Expected before deletion: matches are limited to the six predecessor source/test files. Expected after deletion: no matches.

Remove exactly these six superseded source/test files through the execution environment's patch tool; do not reset or restore the working tree. Their approved low-blur, background-artwork, accessibility, and compact-layout behavior is already represented by Tasks 4–7.

- [ ] **Step 6: Run root/configuration tests and generic build**

Run the Step 2 command again, then:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

Expected: root/configuration tests pass and generic build ends with `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Inspect the built app metadata**

Run:

```bash
find ~/Library/Developer/Xcode/DerivedData \
  -path '*/Build/Products/Debug-iphonesimulator/IsleWhispers.app/Info.plist' \
  -print -quit | xargs plutil -p | rg -A8 'UIDeviceFamily|UISupportedInterfaceOrientations'
```

Expected: `UIDeviceFamily` contains only `1`, the iPhone orientations array contains only `UIInterfaceOrientationPortrait`, and no iPad orientations key is present.

- [ ] **Step 8: Commit root wiring and predecessor replacement**

```bash
git add IsleWhispers/IsleWhispers/SceneDelegate.swift \
  IsleWhispers/IsleWhispers.xcodeproj/project.pbxproj \
  IsleWhispers/IsleWhispers/ViewControllers/RootTabBarController.swift \
  IsleWhispers/IsleWhispers/ViewControllers/LibraryViewController.swift \
  IsleWhispers/IsleWhispers/ViewControllers/PlayerViewController.swift \
  IsleWhispers/IsleWhispers/UI/PlayerControlsView.swift \
  IsleWhispers/IsleWhispers/UI/SoundCell.swift \
  IsleWhispersTests/RootTabBarControllerTests.swift \
  IsleWhispersTests/AppConfigurationTests.swift \
  IsleWhispersTests/LibraryViewControllerTests.swift \
  IsleWhispersTests/PlayerViewControllerLayoutTests.swift
git commit -m "feat: wire iPhone-only sound tabs"
```

---

### Task 9: Full regression, interaction verification, and handoff

**Files:**
- Modify only if a failing verification exposes a requirement regression in Tasks 1–8.
- Record results in the final handoff; do not create a progress or duration UI.

**Interfaces:**
- Consumes: the complete implementation and all tests.
- Produces: fresh full-suite, build, metadata, source-constraint, and manual interaction evidence.

- [ ] **Step 1: Run the complete hosted test suite**

Run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST SUCCEEDED **` with zero failed tests.

- [ ] **Step 2: Run a fresh generic simulator build**

Run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'generic/platform=iOS Simulator' clean build CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Verify source constraints and exact resources**

Run:

```bash
rg -n 'UIProgressView|elapsed|duration|currentTime|numberOfLoops' IsleWhispers/IsleWhispers
find IsleWhispers/IsleWhispers/Resources/Audio -name '*.caf' | wc -l
find IsleWhispers/IsleWhispers/Resources/Backgrounds -name '*.png' | wc -l
git diff --check
```

Expected: no progress/time UI match, `numberOfLoops = -1` remains, both resource counts are `15`, and `git diff --check` prints nothing.

- [ ] **Step 4: Verify the two screen sizes in portrait**

Ensure the layout test methods exercise both literal sizes `CGSize(width: 375, height: 667)` and `CGSize(width: 430, height: 932)`, then run:

```bash
xcodebuild -workspace IsleWhispers/IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:IsleWhispersTests/HomeViewControllerTests/testCarouselFillsSpaceBetweenHeaderAndControlsWithoutProgressUI \
  -only-testing:IsleWhispersTests/SoundLibraryViewControllerTests/testDefaultUsesTwoColumnsAndAccessibilityUsesOne \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: the carousel fills the remaining vertical area, the Tab Bar and controls are reachable, recent sounds use three columns, and library cards use two columns without constraint warnings.

- [ ] **Step 5: Manually verify interaction behavior in Simulator**

Perform this exact sequence:

1. Launch on iPhone 17 Pro in portrait.
2. Swipe forward across the 15-sound boundary twice and backward across it twice.
3. Confirm no visible teleport, duplicate accessibility position, or black frame.
4. Flick across multiple cards and confirm only the final settled sound begins playing.
5. Mute, swipe to another sound, and confirm it remains muted while playback remains active.
6. Restore sound and confirm playback continues.
7. Open recent sounds, select an item, and confirm the overlay closes and home centers it.
8. Open the Sound Tab, select one item in each group, and confirm each selection returns home and auto-plays.
9. Enable Reduce Motion and repeat one swipe; confirm scaling is removed.
10. Enable an accessibility content size; confirm the library becomes one column and all controls remain reachable.

- [ ] **Step 6: Verify physical-device-only boundaries or state them explicitly as pending**

On a real iPhone, verify lock-screen commands, background playback, sleep timer expiry, route removal, interruption/resume, and natural audio looping. If no device is available, list these six checks as unverified; simulator build/tests do not prove them.

- [ ] **Step 7: Inspect final scope and commit any verification-only correction**

Run:

```bash
git status --short
git log --oneline --max-count=10
```

Expected: only intended implementation paths are changed; no temporary frames, recordings, DerivedData, or test-result bundles are tracked. If Step 1–6 required a correction, commit only its exact files with a message describing that correction. If no correction was required, create no empty commit.
