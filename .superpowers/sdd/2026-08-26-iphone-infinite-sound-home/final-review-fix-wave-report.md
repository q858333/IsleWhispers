# Final Review Fix Wave Report

Date: 2026-08-27
Branch: `codex/iphone-infinite-sound-home`
Base HEAD: `dae94c723dee663c6058db4114f44372b2364ac1`
Implementation commit: `8b0ae37e310ea3481df9c41ecacdef9da82a52c1` (`fix: coordinate home playback and motion`)

## Scope and findings mapping

### Important: record every successfully playing Home selection exactly once

- Removed the direct `recentStore.record` write from `selectAndPlaySound`.
- Added one Home-owned coordination point, called from `render()`, that observes the shared `AudioPlayerService.selectedIndex` and `isPlaying` state.
- A selected-index change resets the per-logical-selection recording flag. The flag is consumed only after playback has actually succeeded (`isPlaying == true`).
- Initial Play now records the restored/default selection. Remote next/previous while playing record the continued selection even though `AudioPlayerService.selectSound` publishes both the successful continuation and the completed selection state.
- Repeated notifications for pause, mute, sleep timer, retry, interruption state, or the same selected index do not write or reorder recent sounds.
- Paused selection changes remain unrecorded until a later successful Play.
- Coordination only reads player state and writes `RecentSoundsStore`; it never calls back into the player or carousel, so no recursion or second playback state exists.

Production tests added or strengthened:

- `testInitialPlayRecordsSelectedSound`
- `testRemoteNextAndPreviousRecordEachPlayingSelectionWithoutStateReordering`
- `testPausedSelectionWaitsForSuccessfulPlaybackBeforeRecordingRecent`
- `testSettlingCarouselAutoPlaysOnceAndRecordsRecentSound` now counts `.audioPlayerStateDidChange`, repeats the same-index settle twice, and proves the service notification count and recents remain unchanged.

### Minor 1: avoid repeated bundled PNG decoding

- Added one `NSCache<NSURL, UIImage>` to `SoundArtwork`.
- The key is the resolved resource URL, so resource names in different bundle locations cannot collide while carousel cells, library cards, and Home backgrounds share one decoded image instance for the same file.
- Missing resource and decode-failure behavior remains `nil`; there is no new dependency, queue, or asynchronous loading layer.
- `testSoundArtworkReusesImageForSameResolvedResourceURL` proves same-resource identity and distinct-resource separation.

### Minor 2: approved motion mapping

- Home background stays fully on the source through progress `0.5`; progress `0.5...1.0` maps to a source-to-target crossfade. The production-facing Home test checks `0.4 -> 1/0` and `0.75 -> 0.5/0.5`.
- Settle uses a `0.25s` opacity-only fade with `.beginFromCurrentState`, `.allowUserInteraction`, and `.curveEaseOut`. This remains a short/simple fade under Reduce Motion; enhanced carousel scrolling/scaling continues to use the existing Reduce Motion guards.
- Settle reuses whichever background layer already contains the target, or loads into the less-visible layer, then fades to it. It avoids an immediate target replacement on the visible source layer.
- Carousel title/subtitle alpha now uses squared center distance: near-center text remains clear (`distance 0.2` is above `0.9`), while adjacent title/subtitle fall to `0.10/0.04` before cell-level alpha is applied.
- Tests use actual Home background image views and actual `SoundCarouselCell` labels; no timer sleeps are used. The settle-duration production contract is asserted within `0.20...0.30s`.

### Minor 3: settle-once ledger deferral

- No ledger file was touched.
- One new logical settle produces exactly one player-state notification and one recent entry.
- Two subsequent settles on the same centered physical/logical index produce no additional service notification and no recent reorder or duplication.

## TDD evidence

All regression tests were written before production changes.

### RED 1: Home playback/recent coordination

Command:

```sh
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,id=9B6B9CC7-D2FE-4144-A9E6-DBD053E58699' \
  -only-testing:IsleWhispersTests/HomeViewControllerTests \
  test CODE_SIGNING_ALLOWED=NO
```

Result: exit `65`, `** TEST FAILED **`.

- `testInitialPlayRecordsSelectedSound` failed.
- `testPausedSelectionWaitsForSuccessfulPlaybackBeforeRecordingRecent` failed.
- `testRemoteNextAndPreviousRecordEachPlayingSelectionWithoutStateReordering` failed.
- The strengthened settle-once test passed, confirming that its notification-count baseline was valid before changing production code.

### RED 2: artwork cache identity

Command:

```sh
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,id=9B6B9CC7-D2FE-4144-A9E6-DBD053E58699' \
  -only-testing:IsleWhispersTests/HomeViewControllerTests/testSoundArtworkReusesImageForSameResolvedResourceURL \
  test CODE_SIGNING_ALLOWED=NO
```

Result: exit `65`; the cache identity test failed against repeated `UIImage(contentsOfFile:)` calls.

### RED 3: background and title mapping

Command:

```sh
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,id=9B6B9CC7-D2FE-4144-A9E6-DBD053E58699' \
  -only-testing:IsleWhispersTests/HomeViewControllerTests/testBackgroundTransitionHoldsSourceUntilMidpointThenCrossfades \
  -only-testing:IsleWhispersTests/HomeViewControllerTests/testCarouselTitlesAreClearNearCenterAndNearlyHiddenWhenAdjacent \
  test CODE_SIGNING_ALLOWED=NO
```

Result: exit `65`; both tests failed against the original linear background crossfade and `0.85/0.65` adjacent text alpha.

### RED 4: settle duration contract

Command:

```sh
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,id=9B6B9CC7-D2FE-4144-A9E6-DBD053E58699' \
  -only-testing:IsleWhispersTests/HomeViewControllerTests/testSettledBackgroundUsesShortSimpleFadeDuration \
  test CODE_SIGNING_ALLOWED=NO
```

Result: exit `65`; compilation failed with `type 'HomeViewController' has no member 'backgroundSettleDuration'`.

## GREEN verification

### Home regression group

Command:

```sh
xcodebuild -quiet -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,id=9B6B9CC7-D2FE-4144-A9E6-DBD053E58699' \
  -only-testing:IsleWhispersTests/HomeViewControllerTests \
  test CODE_SIGNING_ALLOWED=NO
```

Result: exit `0`; all `15/15` Home tests passed.

### Focused Home / Carousel / Audio regression group

Command:

```sh
xcodebuild -quiet -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,id=9B6B9CC7-D2FE-4144-A9E6-DBD053E58699' \
  -only-testing:IsleWhispersTests/HomeViewControllerTests \
  -only-testing:IsleWhispersTests/InfiniteSoundCarouselTests \
  -only-testing:IsleWhispersTests/InfiniteCarouselIndexingTests \
  -only-testing:IsleWhispersTests/AudioPlayerPersistenceTests \
  -only-testing:IsleWhispersTests/PlaybackStateTests \
  test CODE_SIGNING_ALLOWED=NO
```

Result: exit `0`; `43/43` tests passed, including remote commands, interruption/route changes, mute, sleep timer, playback wrapping, carousel recentering, and settle-once behavior.

### Full suite

The first parallel-clone run reported `55` passed and `3` `RecentSoundsStoreTests` crashes at `0.000s`. The xcresult failure was `Test crashed with signal abrt.`; a focused rerun then exposed the infrastructure cause before test execution:

```text
CoreSimulator SimError 405: Invalid device state
Mach error -308: server died
Failed to install or launch the test runner
```

No production or test change was made for this environment failure. The three store tests passed on a stable simulator with parallel clones disabled, then the full suite was rerun in the same bounded mode:

```sh
xcodebuild -quiet -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,id=5B24F1F6-66D9-42AC-898A-819240E92D5C' \
  -parallel-testing-enabled NO \
  test CODE_SIGNING_ALLOWED=NO
```

Result: exit `0`. Structured xcresult summary:

```json
{"expectedFailures":0,"failedTests":0,"passedTests":58,"skippedTests":0,"result":"Passed","totalTestCount":58}
```

### Generic simulator build

Command:

```sh
xcodebuild -quiet -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```

Result: exit `0`. The build retained the iOS 15 deployment target. Xcode emitted only environment warnings about device build metadata and a missing optional Metal toolchain search path; there were no Swift compile or link failures.

## Self-review

- `git diff --check`: clean.
- Changed implementation/test files before the report: exactly the four authorized files.
- `rg recentStore.record`: one production write remains, inside Home state coordination only.
- `AudioPlayerService.swift`: unchanged; existing playback, remote, interruption, route, mute, sleep timer, and now-playing behavior is preserved.
- No ledger, project configuration, Pods, resources, progress UI, or time UI changed.
- Cache key is the resolved URL rather than only the resource name.
- State coordination has no call back into player selection/playback and therefore cannot recurse.
- Paused selection, failed playback, duplicate service notifications, same-index settle, mute, pause, and timer paths are covered by observable tests.
- Motion assertions exercise production views synchronously; no timer sleeps or test-only production methods were added.
- Final implementation commit stages only the four scoped code/test files. This report is committed separately so it can truthfully contain that immutable implementation SHA.
