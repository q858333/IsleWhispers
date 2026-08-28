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
