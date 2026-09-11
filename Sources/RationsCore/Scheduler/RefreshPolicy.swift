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
    /// Set by `backOff()`: the server asked us to slow down, so the interval is
    /// a floor and must not be shortened to catch a window reset.
    private(set) var isBackingOff = false

    init(boost: TimeInterval = 2 * 60, base: TimeInterval = 5 * 60, max: TimeInterval = 20 * 60) {
        self.boost = boost
        self.base = base
        self.max = max
        interval = base
    }

    mutating func reset() {
        interval = base
        isBackingOff = false
    }

    mutating func record(changed: Bool) {
        isBackingOff = false
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
        isBackingOff = true
    }
}
