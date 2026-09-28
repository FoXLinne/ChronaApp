import Foundation

/// 任务 CRUD + 排序管理。
/// 纯逻辑层，接收 tasks 数组并返回修改后的副本。
enum TaskManager {

    /// 创建新任务，返回更新后的 tasks 数组。
    static func createTask(
        title: String,
        mode: FocusMode,
        presetID: String,
        countdownDuration: TimeInterval,
        backgroundName: String,
        in tasks: [TaskItem]
    ) -> [TaskItem] {
        let task = TaskItem(
            title: title,
            mode: mode,
            pomodoroPresetID: presetID,
            countdownDuration: countdownDuration,
            backgroundName: backgroundName,
            order: tasks.count
        )
        var updated = tasks
        updated.append(task)
        return reindex(updated)
    }

    /// 更新已有任务，返回更新后的 tasks 数组。
    static func updateTask(_ task: TaskItem, in tasks: [TaskItem]) -> [TaskItem] {
        var updated = tasks
        guard let index = updated.firstIndex(where: { $0.id == task.id }) else { return updated }
        updated[index] = task
        return reindex(updated)
    }

    /// 按 ID 删除任务，返回更新后的 tasks 数组。
    static func deleteTask(id: UUID, in tasks: [TaskItem]) -> [TaskItem] {
        var updated = tasks
        updated.removeAll(where: { $0.id == id })
        return reindex(updated)
    }

    /// 移动任务排序，返回更新后的 tasks 数组。
    static func moveTasks(from source: IndexSet, to destination: Int, sortedTasks: [TaskItem]) -> [TaskItem] {
        var reordered = sortedTasks
        // 手动实现 move，避免依赖 SwiftUI 的 RangeReplaceableCollection 扩展
        var itemsToMove: [TaskItem] = []
        for index in source {
            itemsToMove.append(reordered[index])
        }
        // 从后往前移除，避免索引偏移
        for index in source.sorted().reversed() {
            reordered.remove(at: index)
        }
        let insertionIndex = min(destination, reordered.count)
        reordered.insert(contentsOf: itemsToMove, at: insertionIndex)
        for index in reordered.indices {
            reordered[index].order = index
        }
        return reordered
    }

    /// 检查任务名是否冲突（排除指定 ID）。
    static func isTaskNameDuplicate(_ title: String, excluding id: UUID?, in tasks: [TaskItem]) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return tasks.contains { $0.id != id && $0.title.lowercased() == trimmed.lowercased() }
    }

    // MARK: - 私有工具

    /// 重新编排 order 索引，保持当前排序顺序。
    private static func reindex(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted(by: { $0.order < $1.order }).enumerated().map { index, item in
            var copy = item
            copy.order = index
            return copy
        }
    }
}
