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
