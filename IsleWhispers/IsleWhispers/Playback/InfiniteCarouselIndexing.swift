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
