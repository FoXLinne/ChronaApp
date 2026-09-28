import Foundation

/// 倒数日 CRUD + 时间筛选。
/// 纯逻辑层，接收 countdownEvents 数组并返回修改后的副本。
enum CountdownManager {

    /// 添加倒数日事件，返回更新后的数组。
    static func addEvent(
        title: String,
        date: Date,
        includesTime: Bool,
        notificationEnabled: Bool,
        in events: [CountdownEvent]
    ) -> [CountdownEvent] {
        let event = CountdownEvent(
            title: title,
            date: normalizedDate(date, includesTime: includesTime),
            includesTime: includesTime,
            notificationEnabled: notificationEnabled
        )
        var updated = events
        updated.append(event)
        return updated.sorted(by: { $0.date < $1.date })
    }

    /// 更新倒数日事件，返回更新后的数组。
    static func updateEvent(_ event: CountdownEvent, in events: [CountdownEvent]) -> [CountdownEvent] {
        var updated = events
        guard let index = updated.firstIndex(where: { $0.id == event.id }) else { return updated }
        var copy = event
        copy.date = normalizedDate(copy.date, includesTime: copy.includesTime)
        updated[index] = copy
        return updated.sorted(by: { $0.date < $1.date })
    }

    /// 按 ID 删除倒数日事件。
    static func deleteEvent(id: UUID, in events: [CountdownEvent]) -> [CountdownEvent] {
        var updated = events
        updated.removeAll(where: { $0.id == id })
        return updated
    }

    // MARK: - 工具

    /// 归一化日期：不含时间的事件截断到当天零点。
    static func normalizedDate(_ date: Date, includesTime: Bool) -> Date {
        includesTime ? date : Calendar.current.startOfDay(for: date)
    }
}
