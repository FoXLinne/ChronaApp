import Foundation

/// 统计数据计算。全部为纯函数，不持有任何状态。
enum Statistics {

    // MARK: - 专注时长聚合

    /// 概览同时计算次数、总时长与日均值，避免多次扫描会话记录。
    static func overview(sessions: [FocusSessionRecord], now: Date = .now) -> (count: Int, duration: TimeInterval, dailyAverage: TimeInterval) {
        guard !sessions.isEmpty else { return (0, 0, 0) }
        var duration: TimeInterval = 0
        var earliest = sessions[0].startedAt
        for session in sessions {
            duration += session.focusedDuration
            if session.startedAt < earliest { earliest = session.startedAt }
        }
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: earliest),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        return (sessions.count, duration, duration / Double(max(1, days + 1)))
    }

    /// 当日卡片共用一次筛选和求和。
    static func todaySummary(sessions: [FocusSessionRecord]) -> (count: Int, duration: TimeInterval) {
        let calendar = Calendar.current
        var count = 0
        var duration: TimeInterval = 0
        for session in sessions where calendar.isDateInToday(session.endedAt) {
            count += 1
            duration += session.focusedDuration
        }
        return (count, duration)
    }

    // MARK: - 热力图

    /// 指定月份的每日专注时长聚合，供热力图使用。
    static func dailyFocusDurations(sessions: [FocusSessionRecord], for month: Date) -> [Date: TimeInterval] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [:] }

        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        var durations: [Date: TimeInterval] = [:]
        for record in sessions where record.endedAt >= monthStart && record.endedAt < nextMonthStart {
            durations[calendar.startOfDay(for: record.endedAt), default: 0] += record.focusedDuration
        }

        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            durations[date] = durations[date] ?? 0
        }
        return durations
    }

    // MARK: - 任务分布

    /// 按时间范围的任务分布。
    static func taskDistribution(sessions: [FocusSessionRecord], range: TimeRange) -> [TaskDistributionEntry] {
        let component: Calendar.Component
        switch range {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        }
        guard let interval = Calendar.current.dateInterval(of: component, for: .now) else { return [] }
        return taskDistribution(sessions: sessions, in: interval)
    }

    /// 按指定日期的任务分布。
    static func taskDistribution(sessions: [FocusSessionRecord], on date: Date) -> [TaskDistributionEntry] {
        guard let interval = Calendar.current.dateInterval(of: .day, for: date) else { return [] }
        return taskDistribution(sessions: sessions, in: interval)
    }

    private static func taskDistribution(sessions: [FocusSessionRecord], in interval: DateInterval) -> [TaskDistributionEntry] {
        var totals: [String: (title: String, duration: TimeInterval)] = [:]
        for record in sessions where record.endedAt >= interval.start && record.endedAt < interval.end {
            let key = record.taskID?.uuidString ?? "title:\(record.taskTitle)"
            if var total = totals[key] {
                total.duration += record.focusedDuration
                totals[key] = total
            } else {
                totals[key] = (record.taskTitle, record.focusedDuration)
            }
        }
        return totals.map { key, value in
            TaskDistributionEntry(
                id: key,
                taskTitle: value.title,
                duration: value.duration,
                colorSeed: key
            )
        }
        .sorted(by: { $0.duration > $1.duration })
    }

    // MARK: - 月度趋势

    static let trendVisibleDays = 7

    /// 指定月份的趋势数据点。
    static func monthlyTrendPoints(sessions: [FocusSessionRecord], selectedMonth: Date) -> [DayTrendEntry] {
        let calendar = Calendar.current
        let monthStart = monthStartDate(for: selectedMonth)
        let dayRange = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<2
        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        var durationsByDay: [Date: TimeInterval] = [:]
        for record in sessions where record.endedAt >= monthStart && record.endedAt < nextMonthStart {
            durationsByDay[calendar.startOfDay(for: record.endedAt), default: 0] += record.focusedDuration
        }

        return dayRange.compactMap { day in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { return nil }
            let duration = durationsByDay[date] ?? 0
            return DayTrendEntry(date: date, duration: duration)
        }
    }

    /// 趋势图的 X 轴可见域。
    static func trendVisibleLength() -> TimeInterval {
        TimeInterval((trendVisibleDays - 1) * 24 * 60 * 60)
    }

    /// 趋势图的 X 轴数据域（月份首日...末日）。
    static func trendDomain(selectedMonth: Date) -> ClosedRange<Date> {
        let monthStart = monthStartDate(for: selectedMonth)
        let monthEnd = monthEndDate(for: selectedMonth)
        return monthStart...monthEnd
    }

    /// 将趋势滚动起始日钳制在合法范围内。
    static func clampedTrendStartDate(_ proposed: Date, month: Date) -> Date {
        let calendar = Calendar.current
        let normalized = calendar.startOfDay(for: proposed)
        let mStart = monthStartDate(for: month)
        let mMax = maxTrendStartDate(for: month)
        if normalized < mStart { return mStart }
        if normalized > mMax { return mMax }
        return normalized
    }

    /// 默认趋势滚动起始日（锚定到给定日期的前 N 天）。
    static func defaultTrendStartDate(for month: Date, anchorDate: Date) -> Date {
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: anchorDate)
        let candidate = calendar.date(byAdding: .day, value: -(trendVisibleDays - 1), to: anchor) ?? anchor
        return clampedTrendStartDate(candidate, month: month)
    }

    /// 切换月份（向前/向后），返回新月份和新滚动日期。
    static func cycleMonth(selectedMonth: Date, forward: Bool) -> (month: Date, scrollDate: Date) {
        let candidate = Calendar.current.date(byAdding: .month, value: forward ? 1 : -1, to: selectedMonth) ?? selectedMonth
        let target: Date
        if forward {
            let currentMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
            target = min(candidate, currentMonth)
        } else {
            target = candidate
        }
        let newMonth = monthStartDate(for: target)
        let newScrollDate = defaultTrendStartDate(for: newMonth, anchorDate: newMonth)
        return (newMonth, newScrollDate)
    }

    // MARK: - 月份边界

    static func monthStartDate(for date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }

    static func monthEndDate(for date: Date) -> Date {
        let calendar = Calendar.current
        let start = monthStartDate(for: date)
        guard let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: start),
              let monthEnd = calendar.date(byAdding: .day, value: -1, to: nextMonthStart)
        else { return start }
        return calendar.startOfDay(for: monthEnd)
    }

    private static func maxTrendStartDate(for month: Date) -> Date {
        let calendar = Calendar.current
        let end = monthEndDate(for: month)
        let candidate = calendar.date(byAdding: .day, value: -(trendVisibleDays - 1), to: end) ?? end
        let start = monthStartDate(for: month)
        return max(candidate, start)
    }
}
