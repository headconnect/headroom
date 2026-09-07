import Foundation

/// Adaptive polling interval for one account.
///
/// Starts at `base`. A fetch that shows changed numbers drops to `boost`; an
/// unchanged fetch doubles the interval up to `max`. `reset()` returns to `base`.
struct RefreshPolicy: Equatable {
    let boost: TimeInterval
    let base: TimeInterval
    let max: TimeInterval
    private(set) var interval: TimeInterval

    init(boost: TimeInterval = 2 * 60, base: TimeInterval = 5 * 60, max: TimeInterval = 20 * 60) {
        self.boost = boost
        self.base = base
        self.max = max
        interval = base
    }

    mutating func reset() {
        interval = base
    }

    mutating func record(changed: Bool) {
        if changed {
            interval = boost
        } else if interval < base {
            interval = base
        } else {
            interval = Swift.min(interval * 2, max)
        }
    }

    mutating func backOff() {
        interval = max
    }
}
