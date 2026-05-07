import Foundation

/// 签到管理：每日签到、连续天数、总天数。
/// 纯逻辑层，接收 checkInDates 数组并返回计算结果或修改后的副本。
enum CheckIn {

    /// 今天是否已签到。
    static func hasCheckedInToday(in dates: [Date]) -> Bool {
        dates.contains(where: { Calendar.current.isDateInToday($0) })
    }

    /// 签到。返回 (新 dates 数组, 是否成功)。已签到则返回 false。
    @discardableResult
    static func checkInToday(in dates: [Date]) -> (dates: [Date], success: Bool) {
        let today = Calendar.current.startOfDay(for: .now)
        guard !dates.contains(where: { Calendar.current.isDate($0, inSameDayAs: today) }) else {
            return (dates, false)
        }
        return (normalizedDates(dates + [today]), true)
    }

    /// 当前连续签到天数（从今天往回数）。
    static func checkInStreak(in dates: [Date]) -> Int {
        guard !dates.isEmpty else { return 0 }

        let calendar = Calendar.current
        let daySet = Set(dates.map { calendar.startOfDay(for: $0) })

        var streak = 0
        var cursor = calendar.startOfDay(for: .now)

        while daySet.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return streak
    }

    /// 最长连续签到天数。
    static func longestCheckInStreak(in dates: [Date]) -> Int {
        guard dates.count > 1 else { return dates.count }

        let calendar = Calendar.current
        let sorted = Set(dates.map { calendar.startOfDay(for: $0) }).sorted()
        var maxLen = 1
        var cur = 1
        for i in 1..<sorted.count {
            if let diff = calendar.dateComponents([.day], from: sorted[i - 1], to: sorted[i]).day, diff == 1 {
                cur += 1
                maxLen = max(maxLen, cur)
            } else {
                cur = 1
            }
        }
        return maxLen
    }

    /// 签到总天数。
    static func totalCheckInCount(in dates: [Date]) -> Int {
        dates.count
    }

    // MARK: - 工具

    /// 归一化签到日期：去重、截断到当天零点、降序排列。
    static func normalizedDates(_ dates: [Date]) -> [Date] {
        let calendar = Calendar.current
        let uniqueDays = Set(dates.map { calendar.startOfDay(for: $0) })
        return uniqueDays.sorted(by: >)
    }
}
