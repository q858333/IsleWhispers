import Foundation

struct PlaybackState: Equatable {
    private(set) var selectedIndex: Int
    var isPlaying: Bool

    mutating func select(index: Int, count: Int) {
        guard count > 0 else { return }
        selectedIndex = (index % count + count) % count
    }

    mutating func selectNext(count: Int) {
        select(index: selectedIndex + 1, count: count)
    }

    mutating func selectPrevious(count: Int) {
        select(index: selectedIndex - 1, count: count)
    }
}

enum SleepTimerOption: Int, CaseIterable {
    case unlimited = 0
    case minutes15 = 15
    case minutes30 = 30
    case minutes60 = 60
}

struct SleepTimerState: Equatable {
    private(set) var option: SleepTimerOption = .unlimited
    private(set) var deadline: Date?

    mutating func schedule(_ option: SleepTimerOption, now: Date) {
        self.option = option
        deadline = option == .unlimited ? nil : now.addingTimeInterval(TimeInterval(option.rawValue * 60))
    }

    func isExpired(at date: Date) -> Bool {
        deadline.map { date >= $0 } ?? false
    }
}
