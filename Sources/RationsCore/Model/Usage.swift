import Foundation

/// One rate-limit window, e.g. the 5-hour session or the weekly cap.
struct UsageWindow: Equatable, Identifiable {
    let id: String
    let label: String
    /// 0...100
    let percentUsed: Double
    let resetsAt: Date?
    /// Optional caption, e.g. "8,151 of 10,000 left".
    let detail: String?

    init(id: String, label: String, percentUsed: Double, resetsAt: Date?, detail: String? = nil) {
        self.id = id
        self.label = label
        self.detail = detail
        self.percentUsed = min(max(percentUsed, 0), 100)
        // Whole seconds, so sub-second jitter in API timestamps never counts as a change.
        self.resetsAt = resetsAt.map { Date(timeIntervalSince1970: $0.timeIntervalSince1970.rounded(.down)) }
    }
}

struct UsageSnapshot: Equatable {
    let windows: [UsageWindow]
    let fetchedAt: Date

    /// The short-term and long-term limits, e.g. the 5-hour session and the
    /// weekly cap; per-model and overage windows are left to the popover.
    var headline: ArraySlice<UsageWindow> { windows.prefix(2) }

    var earliestReset: Date? { windows.compactMap(\.resetsAt).min() }

    /// True if any limit moved since `previous`.
    func hasChanges(since previous: UsageSnapshot?) -> Bool {
        guard let previous else { return true }
        return windows != previous.windows
    }
}
