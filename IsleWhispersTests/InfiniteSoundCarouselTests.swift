import UIKit
import XCTest
@testable import IsleWhispers

final class InfiniteSoundCarouselTests: XCTestCase {
    @MainActor
    func testUsesThreeSegmentsAndCentersSelectedSound() {
        let carousel = makeCarousel(selectedIndex: 2)

        XCTAssertEqual(carousel.physicalItemCount, 45)
        XCTAssertEqual(carousel.displayedLogicalIndex, 2)
        XCTAssertEqual(carousel.centeredPhysicalIndex, 17)
    }

    @MainActor
    func testSettlingNewSoundReportsOnceAndRecentersOuterSegment() {
        let carousel = makeCarousel(selectedIndex: 2)
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
        let carousel = makeCarousel(selectedIndex: 2)

        XCTAssertTrue(carousel.isAccessibilityElement)
        XCTAssertTrue(carousel.accessibilityTraits.contains(.adjustable))
        XCTAssertEqual(carousel.accessibilityValue, "雨声，3 / 15")
        XCTAssertTrue(carousel.collectionAccessibilityElementsHidden)
    }

    @MainActor
    func testProgrammaticSelectionUpdatesAndSettlesOnlyOnce() {
        let carousel = makeCarousel(selectedIndex: 2)
        var settled: [Int] = []
        carousel.onSettled = { settled.append($0) }

        carousel.setSelectedSound(index: 5, animated: false)
        carousel.settle(onPhysicalIndex: 20)

        XCTAssertEqual(carousel.displayedLogicalIndex, 5)
        XCTAssertEqual(carousel.centeredPhysicalIndex, 20)
        XCTAssertEqual(settled, [5])
        XCTAssertEqual(carousel.accessibilityValue, "风声，6 / 15")
    }

    @MainActor
    func testAccessibilityScrollsLogicallyAcrossCatalogBoundary() {
        let carousel = makeCarousel(selectedIndex: 14)
        var settled: [Int] = []
        carousel.onSettled = { settled.append($0) }

        carousel.accessibilityIncrement()
        carousel.accessibilityDecrement()

        XCTAssertEqual(carousel.displayedLogicalIndex, 14)
        XCTAssertEqual(settled, [0, 14])
        XCTAssertEqual(carousel.accessibilityValue, "鲸歌，15 / 15")
    }

    @MainActor
    func testTransitionReportsNeighboringLogicalSoundsAndProgress() throws {
        let carousel = makeCarousel(selectedIndex: 2)
        let collectionView = try XCTUnwrap(
            carousel.subviews.compactMap { $0 as? UICollectionView }.first
        )
        let layout = try XCTUnwrap(collectionView.collectionViewLayout as? SoundCarouselFlowLayout)
        let from = try XCTUnwrap(layout.layoutAttributesForItem(at: IndexPath(item: 17, section: 0)))
        let to = try XCTUnwrap(layout.layoutAttributesForItem(at: IndexPath(item: 18, section: 0)))
        var reported: (from: Int, to: Int, progress: CGFloat)?
        carousel.onTransition = { reported = ($0, $1, $2) }

        collectionView.contentOffset.x = (from.center.x + to.center.x) / 2 - collectionView.bounds.width / 2
        carousel.scrollViewDidScroll(collectionView)

        XCTAssertEqual(reported?.from, 2)
        XCTAssertEqual(reported?.to, 3)
        XCTAssertEqual(try XCTUnwrap(reported?.progress), 0.5, accuracy: 0.01)
    }

    @MainActor
    private func makeCarousel(selectedIndex: Int) -> InfiniteSoundCarousel {
        let carousel = InfiniteSoundCarousel(sounds: Sound.catalog, selectedIndex: selectedIndex)
        carousel.frame = CGRect(x: 0, y: 0, width: 390, height: 520)
        carousel.layoutIfNeeded()
        return carousel
    }
}
