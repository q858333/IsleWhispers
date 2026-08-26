import XCTest
@testable import IsleWhispers

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
