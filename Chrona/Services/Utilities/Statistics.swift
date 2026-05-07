import Foundation

/// 统计数据计算。全部为纯函数，不持有任何状态。
enum Statistics {

    // MARK: - 专注时长聚合

    /// 指定时间范围内的专注记录。
    static func filteredSessions(sessions: [FocusSessionRecord], range: TimeRange, now: Date = .now) -> [FocusSessionRecord] {
        let calendar = Calendar.current
        return sessions.filter { record in
            switch range {
            case .day:
                return calendar.isDateInToday(record.endedAt)
            case .week:
                return calendar.isDate(record.endedAt, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(record.endedAt, equalTo: now, toGranularity: .month)
            }
        }
    }

    /// 指定时间范围内的总专注时长。
    static func totalFocusedDuration(sessions: [FocusSessionRecord], range: TimeRange) -> TimeInterval {
        filteredSessions(sessions: sessions, range: range).reduce(0) { $0 + $1.focusedDuration }
    }

    /// 指定时间范围内的专注次数。
    static func totalFocusedCount(sessions: [FocusSessionRecord], range: TimeRange) -> Int {
        filteredSessions(sessions: sessions, range: range).count
    }

    /// 日均专注时长（从最早记录到今天）。
    static func averageDailyDuration(sessions: [FocusSessionRecord]) -> TimeInterval {
        guard let earliest = sessions.map(\.startedAt).min() else { return 0 }
        let calendar = Calendar.current
        let earliestDay = calendar.startOfDay(for: earliest)
        let today = calendar.startOfDay(for: .now)
        let elapsedDays = calendar.dateComponents([.day], from: earliestDay, to: today).day ?? 0
        let dayCount = max(1, elapsedDays + 1)
        return sessions.reduce(0) { $0 + $1.focusedDuration } / Double(dayCount)
    }

    /// 累计总专注时长。
    static func totalFocusedDurationAllTime(sessions: [FocusSessionRecord]) -> TimeInterval {
        sessions.reduce(0) { $0 + $1.focusedDuration }
    }

    // MARK: - 热力图

    /// 指定月份的每日专注时长聚合，供热力图使用。
    static func dailyFocusDurations(sessions: [FocusSessionRecord], for month: Date) -> [Date: TimeInterval] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [:] }

        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        var durations = Dictionary(grouping: sessions.filter { record in
            record.endedAt >= monthStart && record.endedAt < nextMonthStart
        }) { record in
            calendar.startOfDay(for: record.endedAt)
        }
        .mapValues { records in
            records.reduce(0) { $0 + $1.focusedDuration }
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
        let grouped = Dictionary(grouping: filteredSessions(sessions: sessions, range: range)) { record in
            record.taskID?.uuidString ?? "title:\(record.taskTitle)"
        }
        return grouped.map { key, value in
            TaskDistributionEntry(
                id: key,
                taskTitle: value.first?.taskTitle ?? "",
                duration: value.reduce(0) { $0 + $1.focusedDuration },
                colorSeed: key
            )
        }
        .sorted(by: { $0.duration > $1.duration })
    }

    /// 按指定日期的任务分布。
    static func taskDistribution(sessions: [FocusSessionRecord], on date: Date) -> [TaskDistributionEntry] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        let filtered = sessions.filter { $0.endedAt >= dayStart && $0.endedAt < dayEnd }
        let grouped = Dictionary(grouping: filtered) { record in
            record.taskID?.uuidString ?? "title:\(record.taskTitle)"
        }
        return grouped.map { key, value in
            TaskDistributionEntry(
                id: key,
                taskTitle: value.first?.taskTitle ?? "",
                duration: value.reduce(0) { $0 + $1.focusedDuration },
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
        let durationsByDay = Dictionary(grouping: sessions.filter { record in
            record.endedAt >= monthStart && record.endedAt < nextMonthStart
        }) { record in
            calendar.startOfDay(for: record.endedAt)
        }
        .mapValues { records in
            records.reduce(0) { $0 + $1.focusedDuration }
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
