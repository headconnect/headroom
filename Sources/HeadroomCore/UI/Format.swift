import SwiftUI

enum Format {
    /// "4h 36m", "6d 5h", "12m", or "now".
    static func countdown(to date: Date, from now: Date) -> String {
        let seconds = Int(date.timeIntervalSince(now))
        guard seconds > 30 else { return "now" }
        let minutes = (seconds + 30) / 60
        let hours = minutes / 60
        let days = hours / 24
        switch (days, hours, minutes) {
        case (1..., _, _): return "\(days)d \(hours % 24)h"
        case (_, 1..., _): return "\(hours)h \(minutes % 60)m"
        default: return "\(minutes)m"
        }
    }

    /// "just now", "3m ago", "2h ago".
    static func age(_ date: Date, now: Date) -> String {
        let minutes = Int(now.timeIntervalSince(date)) / 60
        switch minutes {
        case ..<1: return "just now"
        case ..<60: return "\(minutes)m ago"
        default: return "\(minutes / 60)h ago"
        }
    }

    static func percent(_ value: Double) -> String { "\(Int(value.rounded()))%" }

    /// Green until 70 % used, orange until 90 %, then red.
    static func tint(_ percent: Double) -> Color {
        switch percent {
        case ..<70: .green
        case ..<90: .orange
        default: .red
        }
    }
}
