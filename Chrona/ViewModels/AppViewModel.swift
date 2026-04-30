import Combine
import Foundation
import SwiftUI
import ActivityKit
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var tasks: [TaskItem]
    @Published private(set) var sessions: [FocusSessionRecord]
    @Published private(set) var countdownEvents: [CountdownEvent]
    @Published var profile: ProfileInfo
    @Published var settings: AppSettings
    @Published private(set) var checkInDates: [Date]
    @Published private(set) var lastTaskID: UUID?
    @Published var activeSession: ActiveSessionSnapshot?
    @Published var now: Date = .now
    @Published var selectedStatisticsMonth: Date = .now
    @Published var statisticsTrendScrollDate: Date = .now
    @Published var quickLaunchTaskID: UUID?
    @Published var selectedTab: AppTab = .active {
        didSet {
            updateImmersiveActivationClock(previousTab: oldValue, newTab: selectedTab)
        }
    }
    @Published var globalNotice: String?
    @Published var isActiveImmersiveChromeHidden = false

    private var timerActivity: Activity<TimerActivityAttributes>?
    private let persistence = PersistenceService()
    private let notifications = NotificationService()
    private var ticker: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var noticeTask: Task<Void, Never>?
    private let isPreviewMode: Bool
    private let statisticsTrendVisibleDays = 7
    private var activeTabEnteredAt: Date? = .now

    init(forcePreviewMode: Bool = false) {
        let runningForPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        isPreviewMode = forcePreviewMode || runningForPreview

        if isPreviewMode {
            let snapshot = AppSnapshot.default
            tasks = snapshot.tasks.sorted(by: { $0.order < $1.order })
            sessions = snapshot.sessions.sorted(by: { $0.startedAt > $1.startedAt })
            countdownEvents = snapshot.countdownEvents.sorted(by: { $0.date < $1.date })
            profile = snapshot.profile
            settings = snapshot.settings
            checkInDates = Self.normalizedCheckInDates(snapshot.checkInDates ?? [])
            lastTaskID = snapshot.lastTaskID
            activeSession = snapshot.activeSession
            quickLaunchTaskID = snapshot.lastTaskID
        } else {
            _ = persistence.migrateIfNeeded()

            let dataStore = persistence.loadData()
            let storedSettings = persistence.loadSettings()

            tasks = dataStore.tasks.sorted(by: { $0.order < $1.order })
            sessions = dataStore.sessions.sorted(by: { $0.startedAt > $1.startedAt })
            countdownEvents = dataStore.countdownEvents.sorted(by: { $0.date < $1.date })
            profile = dataStore.profile
            settings = storedSettings
            checkInDates = Self.normalizedCheckInDates(dataStore.checkInDates ?? [])
            lastTaskID = dataStore.lastTaskID
            activeSession = dataStore.activeSession
            quickLaunchTaskID = dataStore.lastTaskID
        }

        startTicker()
        if !isPreviewMode {
            notifications.setup()
            wirePersistenceAndSideEffects()
            syncReminder()
            syncCountdownReminders()
        }
        refreshDerivedState()
        reconcileActiveSessionIfNeeded()
        resetStatisticsTrendToToday()
    }

    static func previewModel() -> AppViewModel {
        let model = AppViewModel(forcePreviewMode: true)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today) ?? today
        model.checkInDates = normalizedCheckInDates([today, yesterday, twoDaysAgo])

        // 热力图预览：构造最近 7 天不同时长的模拟专注记录
        let sampleDurations: [TimeInterval] = [
            0,
            15 * 60,
            45 * 60,
            90 * 60,
            120 * 60,
            30 * 60,
            5 * 60,
        ]
        let fallbackTask = TaskItem(title: "Sample", mode: .pomodoro, order: 0)
        let baseHour: TimeInterval = 9 * 3600

        var previewSessions: [FocusSessionRecord] = []
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let duration = sampleDurations[offset]
            guard duration > 0 else { continue }
            let task = model.tasks.first ?? fallbackTask
            let startTime = day.addingTimeInterval(baseHour)
            let endTime = startTime.addingTimeInterval(duration)
            let session = FocusSessionRecord(
                id: UUID(),
                taskID: task.id,
                taskTitle: task.title,
                mode: task.mode,
                startedAt: startTime,
                endedAt: endTime,
                focusedDuration: duration,
                wasCompleted: true,
                wasAbandoned: false
            )
            previewSessions.append(session)
        }
        model.sessions = previewSessions.sorted(by: { $0.startedAt > $1.startedAt })

        return model
    }

    var sortedTasks: [TaskItem] {
        tasks.sorted(by: { $0.order < $1.order })
    }

    var activeTask: TaskItem? {
        guard let id = activeSession?.taskID else { return nil }
        return tasks.first(where: { $0.id == id })
    }

    var quickLaunchTask: TaskItem? {
        guard let id = quickLaunchTaskID else { return nil }
        return tasks.first(where: { $0.id == id })
    }

    var timerStatus: TimerStatus? {
        guard let activeSession else { return nil }
        return TimerEngine.status(for: activeSession, now: now)
    }

    var shouldShowMinimalMode: Bool {
        guard selectedTab == .active else { return false }
        guard settings.enableMinimalBlackMode, let activeSession else { return false }
        guard activeSession.phase == .focus, !activeSession.isPaused else { return false }
        guard let activeTabEnteredAt else { return false }
        return now.timeIntervalSince(activeTabEnteredAt) >= Double(settings.minimalModeActivationDelaySeconds)
    }

    var minimalModeActivationDelaySeconds: Int {
        settings.minimalModeActivationDelaySeconds
    }

    func setActiveImmersiveChromeHidden(_ hidden: Bool) {
        isActiveImmersiveChromeHidden = hidden
    }

    func formattedDuration(_ value: TimeInterval) -> String {
        let duration = max(0, Int(value.rounded()))
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func createTask(title: String, mode: FocusMode, presetID: String, countdownDuration: TimeInterval, backgroundName: String) {
        let task = TaskItem(
            title: title,
            mode: mode,
            pomodoroPresetID: presetID,
            countdownDuration: countdownDuration,
            backgroundName: backgroundName,
            order: tasks.count
        )
        tasks.append(task)
        reindexTasks()
    }

    func updateTask(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        reindexTasks()
    }

    /// 检查任务名是否冲突（排除当前正在编辑的任务 ID）
    func isTaskNameDuplicate(_ title: String, excluding id: UUID?) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return tasks.contains { $0.id != id && $0.title.lowercased() == trimmed.lowercased() }
    }

    func deleteTasks(at offsets: IndexSet) {
        let ids = offsets.map { sortedTasks[$0].id }
        tasks.removeAll(where: { ids.contains($0.id) })
        reindexTasks()
    }

    func deleteTask(id: UUID) {
        tasks.removeAll(where: { $0.id == id })
        reindexTasks()
    }

    func moveTasks(from source: IndexSet, to destination: Int) {
        var reordered = sortedTasks
        reordered.move(fromOffsets: source, toOffset: destination)
        for index in reordered.indices {
            reordered[index].order = index
        }
        tasks = reordered
    }

    func addCountdownEvent(title: String, date: Date, includesTime: Bool = false, notificationEnabled: Bool = false) {
        let event = CountdownEvent(
            title: title,
            date: normalizedCountdownDate(date, includesTime: includesTime),
            includesTime: includesTime,
            notificationEnabled: notificationEnabled
        )
        countdownEvents.append(event)
        countdownEvents.sort(by: { $0.date < $1.date })
        syncCountdownReminder(for: event)
    }

    func updateCountdownEvent(_ event: CountdownEvent) {
        guard let index = countdownEvents.firstIndex(where: { $0.id == event.id }) else { return }
        var copy = event
        copy.date = normalizedCountdownDate(copy.date, includesTime: copy.includesTime)
        countdownEvents[index] = copy
        countdownEvents.sort(by: { $0.date < $1.date })
        syncCountdownReminder(for: copy)
    }

    func deleteCountdownEvent(id: UUID) {
        countdownEvents.removeAll(where: { $0.id == id })
        notifications.cancelCountdownReminder(eventID: id)
    }

    func deleteCountdownEvents(at offsets: IndexSet, from future: Bool) {
        let target = future ? futureEvents : pastEvents
        let ids = offsets.map { target[$0].id }
        countdownEvents.removeAll(where: { ids.contains($0.id) })
    }

    @discardableResult
    func startTask(_ task: TaskItem) -> Bool {
        guard activeSession == nil else {
            selectedTab = .active
            showNotice(String(localized: "session.alreadyRunning"))
            return false
        }

        let focusDuration: TimeInterval?
        switch task.mode {
        case .pomodoro:
            focusDuration = task.pomodoroPreset.workDuration
        case .countdown:
            focusDuration = task.countdownDuration
        case .stopwatch:
            focusDuration = nil
        }

        activeSession = ActiveSessionSnapshot(
            taskID: task.id,
            taskTitle: task.title,
            mode: task.mode,
            phase: .focus,
            startedAt: .now,
            focusDuration: focusDuration,
            restDuration: nil,
            pausedAt: nil,
            pausedAccumulated: 0,
            isPaused: false,
            pauseDeadline: nil
        )
        lastTaskID = task.id
        quickLaunchTaskID = task.id
        selectedTab = .active
        activeTabEnteredAt = .now
        showNotice(String(localized: "session.started"))
        refreshDerivedState(shouldSyncActivity: true)
        return true
    }

    func quickStartLastTask() {
        guard let id = quickLaunchTaskID, let task = tasks.first(where: { $0.id == id }) else { return }
        _ = startTask(task)
    }

    func openTasksTab() {
        selectedTab = .tasks
    }

    func showGlobalNotice(_ message: String) {
        showNotice(message)
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        now = .now

        switch phase {
        case .active:
            reconcileActiveSessionIfNeeded()
        case .inactive, .background:
            persistState()
        @unknown default:
            break
        }
    }

    func stopConsequence(forceAbandon: Bool = false) -> StopConsequence {
        guard let session = activeSession, session.phase == .focus else {
            return .willRecord
        }

        let status = TimerEngine.status(for: session, now: now)
        let focusDuration = status.elapsed
        let isQualified = focusDuration >= 5
        guard isQualified else {
            return .discardTooShort
        }

        let reachedTarget = session.focusDuration.map { focusDuration >= $0 } ?? true
        let isCompleted = !settings.advancedDisallowEarlyFinish || reachedTarget
        let shouldAbandon = forceAbandon || (settings.advancedDisallowEarlyFinish && !isCompleted)
        return shouldAbandon ? .discardAdvancedRule : .willRecord
    }

    func pauseOrResumeActiveSession() {
        guard var session = activeSession else { return }
        guard session.phase == .focus, session.mode != .pomodoro else { return }
        guard !settings.advancedDisallowPause else { return }

        if session.isPaused {
            let resumeMoment = min(Date.now, session.pauseDeadline ?? Date.now)
            let pausedDuration = resumeMoment.timeIntervalSince(session.pausedAt ?? resumeMoment)
            session.pausedAccumulated += pausedDuration
            session.pausedAt = nil
            session.isPaused = false
            session.pauseDeadline = nil
            activeTabEnteredAt = selectedTab == .active ? .now : nil
            showNotice(String(localized: "session.pause.resumed"))
        } else {
            session.isPaused = true
            session.pausedAt = .now
            activeTabEnteredAt = nil
            if let limit = settings.stopwatchPauseLimitMinutes {
                session.pauseDeadline = Calendar.current.date(byAdding: .minute, value: limit, to: .now)
                showNotice(String(format: String(localized: "session.pause.entered.limit"), limit))
            } else {
                showNotice(String(localized: "session.pause.entered"))
            }
        }
        activeSession = session
        refreshDerivedState(shouldSyncActivity: true)
    }

    func stopActiveSession(forceAbandon: Bool = false) {
        guard let session = activeSession else { return }
        let status = TimerEngine.status(for: session, now: now)
        let focusDuration = session.phase == .focus ? status.elapsed : 0
        let isQualified = focusDuration >= 5
        let reachedTarget = session.phase == .focus && (session.focusDuration.map { focusDuration >= $0 } ?? isQualified)
        let isCompleted = session.phase == .focus && isQualified && (!settings.advancedDisallowEarlyFinish || reachedTarget)
        let isAbandoned = forceAbandon || (settings.advancedDisallowEarlyFinish && !isCompleted)

        if session.phase == .focus, !isQualified {
            showNotice(String(format: String(localized: "session.discard.short"), Int(focusDuration.rounded())))
        } else if session.phase == .focus, isAbandoned {
            showNotice(String(localized: "session.discard.advanced"))
        }

        if session.phase == .focus, isQualified, !isAbandoned {
            let recordedDuration = min(focusDuration, session.focusDuration ?? focusDuration)
            if !hasRecordedSession(session: session, duration: recordedDuration, completed: isCompleted) {
                recordSession(session: session, duration: recordedDuration, completed: isCompleted)
            }
        }

        if session.phase == .focus {
            beginRestIfNeeded(after: session)
        } else {
            activeSession = nil
        }
        activeTabEnteredAt = nil
        refreshDerivedState(shouldSyncActivity: true)
        persistState()
    }

    func endRest() {
        activeSession = nil
        activeTabEnteredAt = nil
        refreshDerivedState(shouldSyncActivity: true)
        persistState()
    }

    var hasCheckedInToday: Bool {
        checkInDates.contains(where: { Calendar.current.isDateInToday($0) })
    }

    var totalCheckInCount: Int {
        checkInDates.count
    }

    var checkInStreak: Int {
        guard !checkInDates.isEmpty else { return 0 }

        let calendar = Calendar.current
        let daySet = Set(checkInDates.map { calendar.startOfDay(for: $0) })

        var streak = 0
        var cursor = calendar.startOfDay(for: .now)

        while daySet.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return streak
    }

    var longestCheckInStreak: Int {
        guard checkInDates.count > 1 else { return checkInDates.count }

        let calendar = Calendar.current
        let sorted = Set(checkInDates.map { calendar.startOfDay(for: $0) }).sorted()
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

    @discardableResult
    func checkInToday() -> Bool {
        let today = Calendar.current.startOfDay(for: .now)
        guard !checkInDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: today) }) else {
            return false
        }

        checkInDates = Self.normalizedCheckInDates(checkInDates + [today])
        return true
    }

    /// 指定月份的每日专注时长聚合，供热力图使用。
    func dailyFocusDurations(for month: Date) -> [Date: TimeInterval] {
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

    func completedCountToday(for task: TaskItem) -> Int {
        sessions.filter {
            $0.taskID == task.id &&
            $0.wasCompleted &&
            Calendar.current.isDateInToday($0.endedAt)
        }.count
    }

    func totalFocusedDuration(for range: TimeRange) -> TimeInterval {
        filteredSessions(range: range).reduce(0) { $0 + $1.focusedDuration }
    }

    func totalFocusedCount(for range: TimeRange) -> Int {
        filteredSessions(range: range).count
    }

    func averageDailyDuration() -> TimeInterval {
        guard let earliest = sessions.map(\.startedAt).min() else { return 0 }
        let calendar = Calendar.current
        let earliestDay = calendar.startOfDay(for: earliest)
        let today = calendar.startOfDay(for: .now)
        let elapsedDays = calendar.dateComponents([.day], from: earliestDay, to: today).day ?? 0
        let dayCount = max(1, elapsedDays + 1)
        return sessions.reduce(0) { $0 + $1.focusedDuration } / Double(dayCount)
    }

    var totalFocusedDurationAllTime: TimeInterval {
        sessions.reduce(0) { $0 + $1.focusedDuration }
    }

    var futureEvents: [CountdownEvent] {
        countdownEvents.filter { $0.date >= Calendar.current.startOfDay(for: .now) && !Calendar.current.isDateInToday($0.date) }
    }

    var todayEvents: [CountdownEvent] {
        countdownEvents.filter { Calendar.current.isDateInToday($0.date) }
    }

    var pastEvents: [CountdownEvent] {
        countdownEvents.filter { $0.date < Calendar.current.startOfDay(for: .now) && !Calendar.current.isDateInToday($0.date) }.sorted(by: { $0.date > $1.date })
    }

    func taskDistribution(range: TimeRange) -> [TaskDistributionEntry] {
        let grouped = Dictionary(grouping: filteredSessions(range: range)) { record in
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

    func monthlyTrendPoints() -> [DayTrendEntry] {
        let calendar = Calendar.current
        let monthStart = statisticsMonthStart(for: selectedStatisticsMonth)
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

    func statisticsTrendDomain() -> ClosedRange<Date> {
        let monthStart = statisticsMonthStart(for: selectedStatisticsMonth)
        let monthEnd = statisticsMonthEnd(for: selectedStatisticsMonth)
        return monthStart...monthEnd
    }

    var statisticsTrendVisibleLength: TimeInterval {
        TimeInterval((statisticsTrendVisibleDays - 1) * 24 * 60 * 60)
    }

    func updateStatisticsTrendScrollDate(_ candidate: Date) {
        statisticsTrendScrollDate = clampedStatisticsTrendStartDate(candidate, month: selectedStatisticsMonth)
    }

    func resetStatisticsTrendToToday() {
        selectedStatisticsMonth = statisticsMonthStart(for: .now)
        statisticsTrendScrollDate = defaultStatisticsTrendStartDate(for: selectedStatisticsMonth, anchorDate: .now)
    }

    func cycleStatisticsMonth(forward: Bool) {
        let candidate = Calendar.current.date(byAdding: .month, value: forward ? 1 : -1, to: selectedStatisticsMonth) ?? selectedStatisticsMonth
        let target: Date
        if forward {
            let currentMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
            target = min(candidate, currentMonth)
        } else {
            target = candidate
        }
        let newMonth = statisticsMonthStart(for: target)
        let newScrollDate = defaultStatisticsTrendStartDate(for: newMonth, anchorDate: newMonth)
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedStatisticsMonth = newMonth
            statisticsTrendScrollDate = newScrollDate
        }
    }

    private func statisticsMonthStart(for date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }

    private func statisticsMonthEnd(for date: Date) -> Date {
        let calendar = Calendar.current
        let monthStart = statisticsMonthStart(for: date)
        guard let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart),
              let monthEnd = calendar.date(byAdding: .day, value: -1, to: nextMonthStart)
        else {
            return monthStart
        }
        return calendar.startOfDay(for: monthEnd)
    }

    private func maxStatisticsTrendStartDate(for month: Date) -> Date {
        let calendar = Calendar.current
        let monthEnd = statisticsMonthEnd(for: month)
        let candidate = calendar.date(byAdding: .day, value: -(statisticsTrendVisibleDays - 1), to: monthEnd) ?? monthEnd
        let monthStart = statisticsMonthStart(for: month)
        return max(candidate, monthStart)
    }

    private func clampedStatisticsTrendStartDate(_ proposed: Date, month: Date) -> Date {
        let calendar = Calendar.current
        let normalized = calendar.startOfDay(for: proposed)
        let monthStart = statisticsMonthStart(for: month)
        let monthMax = maxStatisticsTrendStartDate(for: month)
        if normalized < monthStart { return monthStart }
        if normalized > monthMax { return monthMax }
        return normalized
    }

    private func defaultStatisticsTrendStartDate(for month: Date, anchorDate: Date) -> Date {
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: anchorDate)
        let candidate = calendar.date(byAdding: .day, value: -(statisticsTrendVisibleDays - 1), to: anchor) ?? anchor
        return clampedStatisticsTrendStartDate(candidate, month: month)
    }

    func applyTheme() -> ColorScheme? {
        switch settings.theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    private func reindexTasks() {
        tasks = sortedTasks.enumerated().map { index, item in
            var copy = item
            copy.order = index
            return copy
        }
    }

    private func recordSession(session: ActiveSessionSnapshot, duration: TimeInterval, completed: Bool) {
        // Sessions shorter than 5 seconds are filtered before reaching this method.
        let record = FocusSessionRecord(
            taskID: session.taskID,
            taskTitle: session.taskTitle,
            mode: session.mode,
            startedAt: session.startedAt,
            endedAt: now,
            focusedDuration: duration,
            wasCompleted: completed,
            wasAbandoned: !completed && settings.advancedDisallowEarlyFinish
        )
        sessions.insert(record, at: 0)
        if settings.autoMoveCompletedTaskToTop, let taskID = session.taskID, let index = tasks.firstIndex(where: { $0.id == taskID }) {
            var moved = tasks.remove(at: index)
            moved.order = 0
            tasks.insert(moved, at: 0)
            reindexTasks()
        }
    }

    private func beginRestIfNeeded(after session: ActiveSessionSnapshot) {
        let restDuration: TimeInterval
        if session.mode == .pomodoro, let task = activeTask {
            restDuration = task.pomodoroPreset.breakDuration
        } else {
            guard settings.restDurationMinutes > 0 else {
                activeSession = nil
                return
            }
            restDuration = Double(settings.restDurationMinutes * 60)
        }

        activeSession = ActiveSessionSnapshot(
            taskID: session.taskID,
            taskTitle: session.taskTitle,
            mode: session.mode,
            phase: .rest,
            startedAt: .now,
            focusDuration: nil,
            restDuration: restDuration,
            pausedAt: nil,
            pausedAccumulated: 0,
            isPaused: false,
            pauseDeadline: nil
        )
    }

    func taskDistribution(on date: Date) -> [TaskDistributionEntry] {
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

    private func filteredSessions(range: TimeRange) -> [FocusSessionRecord] {
        let calendar = Calendar.current
        return sessions.filter { record in
            switch range {
            case .day:
                return calendar.isDateInToday(record.endedAt)
            case .week:
                return calendar.isDate(record.endedAt, equalTo: .now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(record.endedAt, equalTo: .now, toGranularity: .month)
            }
        }
    }

    private static func normalizedCheckInDates(_ dates: [Date]) -> [Date] {
        let calendar = Calendar.current
        let uniqueDays = Set(dates.map { calendar.startOfDay(for: $0) })
        return uniqueDays.sorted(by: >)
    }

    private func startTicker() {
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                guard let self else { return }
                now = date
                handleTimerTick()
            }
    }

    private func handleTimerTick() {
        guard activeSession != nil else { return }

        _ = autoResumeFromPauseLimitIfNeeded(now: now)

        guard let activeSession else { return }

        if activeSession.isPaused {
            refreshDerivedState()
            return
        }

        guard let status = timerStatus, status.isFinished else {
            refreshDerivedState()
            return
        }

        if activeSession.phase == .focus {
            stopActiveSession()
        } else {
            endRest()
        }
    }

    private func reconcileActiveSessionIfNeeded() {
        guard activeSession != nil else {
            refreshDerivedState(shouldSyncActivity: true)
            return
        }

        _ = autoResumeFromPauseLimitIfNeeded(now: now)

        guard let activeSession else {
            refreshDerivedState(shouldSyncActivity: true)
            return
        }

        if activeSession.isPaused {
            refreshDerivedState(shouldSyncActivity: true)
            return
        }

        let status = TimerEngine.status(for: activeSession, now: now)
        guard status.isFinished else {
            refreshDerivedState(shouldSyncActivity: true)
            return
        }

        if activeSession.phase == .focus {
            stopActiveSession()
        } else {
            endRest()
        }
    }

    private func hasRecordedSession(session: ActiveSessionSnapshot, duration: TimeInterval, completed: Bool) -> Bool {
        sessions.contains {
            $0.taskID == session.taskID &&
            $0.mode == session.mode &&
            $0.taskTitle == session.taskTitle &&
            abs($0.startedAt.timeIntervalSince(session.startedAt)) < 1 &&
            abs($0.focusedDuration - duration) < 1 &&
            $0.wasCompleted == completed
        }
    }

    @discardableResult
    private func autoResumeFromPauseLimitIfNeeded(now: Date) -> Bool {
        guard var session = activeSession,
              session.mode != .pomodoro,
              session.isPaused,
              let deadline = session.pauseDeadline,
              now >= deadline
        else {
            return false
        }

        let pausedDuration = deadline.timeIntervalSince(session.pausedAt ?? deadline)
        session.pausedAccumulated += pausedDuration
        session.pausedAt = nil
        session.isPaused = false
        session.pauseDeadline = nil
        activeSession = session
        activeTabEnteredAt = selectedTab == .active ? .now : nil
        showNotice(String(localized: "session.pause.autoResumed"))
        syncLiveActivity()
        return true
    }

    private func refreshDerivedState(shouldSyncActivity: Bool = false) {
        ScreenAwakeController.update(isEnabled: settings.keepScreenAwake && activeSession != nil)
        if shouldSyncActivity {
            syncLiveActivity()
        }
    }

    private func syncLiveActivity() {
        guard settings.liveActivitiesEnabled else {
            // 关闭时：清本地引用 + 立即结束所有系统活动
            let ref = timerActivity
            timerActivity = nil
            Task {
                if let activity = ref {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
                for activity in Activity<TimerActivityAttributes>.activities {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
            return
        }

        if let session = activeSession {
            let status = TimerEngine.status(for: session, now: now)

            // 倒计时/番茄钟：会话结束的未来时间点（秒表为 nil）
            let endTime = status.remaining.map { Date.now.addingTimeInterval($0) }

            // 秒表正向计时的参考起点 = 现在 - 已计时长（Widget 自动正向计数，无需 App 推送）
            let elapsedReferenceDate = Date.now.addingTimeInterval(-status.elapsed)

            // 暂停时冻结计时器显示值；有时限暂停交给 Widget 按结束时间自动倒计时。
            let pausedTimerText: String
            let pauseEndTime: Date?
            if session.isPaused, let pauseDeadline = session.pauseDeadline {
                pausedTimerText = ""
                pauseEndTime = pauseDeadline
            } else if session.isPaused {
                // 无时限暂停：冻结当前时间值
                if session.mode == .stopwatch {
                    pausedTimerText = formattedDuration(status.elapsed)
                } else {
                    pausedTimerText = formattedDuration(status.remaining ?? 0)
                }
                pauseEndTime = nil
            } else {
                pausedTimerText = ""
                pauseEndTime = nil
            }

            // 阶段标签：有时限暂停 vs 无时限暂停 区分显示
            let phaseLabel: String
            if session.isPaused {
                if session.pauseDeadline != nil {
                    phaseLabel = String(localized: "la.paused")
                } else {
                    phaseLabel = String(localized: "la.paused.indefinite")
                }
            } else if session.phase == .focus {
                phaseLabel = String(localized: "la.phase.focus")
            } else {
                phaseLabel = String(localized: "la.phase.rest")
            }

            let state = TimerActivityAttributes.ContentState(
                endTime: endTime,
                elapsedReferenceDate: elapsedReferenceDate,
                pausedTimerText: pausedTimerText,
                pauseEndTime: pauseEndTime,
                taskTitle: session.taskTitle,
                phaseLabel: phaseLabel,
                modeLabel: liveActivityModeLabel(for: session.mode),
                modeSystemImage: liveActivityModeImage(for: session.mode),
                isPaused: session.isPaused,
                isRest: session.phase == .rest,
                isStopwatch: session.mode == .stopwatch && session.phase == .focus
            )

            // staleDate：倒计时/番茄钟在结束时间标记为过期；秒表无限期
            let staleDate = endTime

            // 尝试更新已有活动；若本地引用已失效则清除，走新建流程
            if let activity = timerActivity,
               Activity<TimerActivityAttributes>.activities.contains(where: { $0.id == activity.id }) {
                Task {
                    await activity.update(ActivityContent(state: state, staleDate: staleDate))
                }
            } else {
                // 引用已失效或首次创建：清理残留，新建
                timerActivity = nil
                let staleActivities = Activity<TimerActivityAttributes>.activities
                let attributes = TimerActivityAttributes(taskID: session.taskID)

                Task { @MainActor in
                    for stale in staleActivities {
                        await stale.end(nil, dismissalPolicy: .immediate)
                    }

                    guard self.timerActivity == nil, self.activeSession != nil else { return }
                    do {
                        self.timerActivity = try Activity.request(
                            attributes: attributes,
                            content: ActivityContent(state: state, staleDate: staleDate),
                            pushType: nil
                        )
                    } catch {
                        print("Live Activity failed to start: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            // 没有活跃会话，结束所有活动
            let activityRef = timerActivity
            timerActivity = nil
            Task {
                if let activity = activityRef {
                    await activity.end(nil, dismissalPolicy: .immediate)
                } else {
                    for activity in Activity<TimerActivityAttributes>.activities {
                        await activity.end(nil, dismissalPolicy: .immediate)
                    }
                }
            }
        }
    }

    private func liveActivityModeLabel(for mode: FocusMode) -> String {
        switch mode {
        case .pomodoro:  return String(localized: "mode.pomodoro")
        case .countdown: return String(localized: "mode.countdown")
        case .stopwatch: return String(localized: "mode.stopwatch")
        }
    }

    private func liveActivityModeImage(for mode: FocusMode) -> String {
        switch mode {
        case .pomodoro:  return "timer"
        case .countdown: return "hourglass"
        case .stopwatch: return "stopwatch"
        }
    }


    private func wirePersistence() {
        // 用户数据与设置分开持久化，避免设置切换时重复写入会话/任务大文件。
        Publishers.MergeMany(
            $profile.map { _ in () }.eraseToAnyPublisher(),
            $activeSession.map { _ in () }.eraseToAnyPublisher(),
            $countdownEvents.map { _ in () }.eraseToAnyPublisher(),
            $tasks.map { _ in () }.eraseToAnyPublisher(),
            $sessions.map { _ in () }.eraseToAnyPublisher(),
            $checkInDates.map { _ in () }.eraseToAnyPublisher(),
            $lastTaskID.map { _ in () }.eraseToAnyPublisher()
        )
        .sink { [weak self] _ in
            self?.persistDataState()
        }
        .store(in: &cancellables)

        $settings
            .sink { [weak self] newSettings in
                self?.persistSettingsState(newSettings)
            }
            .store(in: &cancellables)
    }

    private func currentDataStore() -> DataStore {
        DataStore(
            version: StorageSchemaVersion.current,
            tasks: tasks,
            sessions: sessions,
            countdownEvents: countdownEvents,
            profile: profile,
            checkInDates: checkInDates,
            lastTaskID: lastTaskID,
            activeSession: activeSession
        )
    }

    private func currentSettingsStore(settings settingsValue: AppSettings? = nil) -> SettingsStore {
        SettingsStore(
            version: StorageSchemaVersion.current,
            settings: settingsValue ?? settings
        )
    }

    private func persistDataState() {
        guard !isPreviewMode else { return }

        persistence.save(data: currentDataStore())
        refreshDerivedState()
    }

    private func persistSettingsState(_ newSettings: AppSettings) {
        guard !isPreviewMode else { return }

        // @Published 在 willSet 发出新值；这里必须保存 publisher 传入的新设置，避免杀进程时写回旧值。
        persistence.save(settings: currentSettingsStore(settings: newSettings))
        refreshDerivedState()
    }

    private func persistState() {
        guard !isPreviewMode else { return }

        persistence.save(data: currentDataStore())
        persistence.save(settings: currentSettingsStore())
        refreshDerivedState()
    }

    private func wireSideEffects() {
        // 提醒同步：仅在提醒相关设置改变时重新调度
        $settings
            .dropFirst()
            .filter { [weak self] newSettings in
                guard let self else { return false }
                return newSettings.dailyReminderEnabled != self.settings.dailyReminderEnabled
                    || newSettings.dailyReminderHour != self.settings.dailyReminderHour
                    || newSettings.dailyReminderMinute != self.settings.dailyReminderMinute
            }
            .sink { [weak self] _ in self?.syncReminder() }
            .store(in: &cancellables)

        // 提醒同步：当天完成专注后自动取消当天提醒
        $sessions
            .dropFirst()
            .sink { [weak self] _ in self?.syncReminder() }
            .store(in: &cancellables)

        // Live Activity 同步：开关变更时立即启停灵动岛/锁屏实时活动
        $settings
            .dropFirst()
            .removeDuplicates { $0.liveActivitiesEnabled == $1.liveActivitiesEnabled }
            .sink { [weak self] _ in self?.syncLiveActivity() }
            .store(in: &cancellables)
    }

    private func wirePersistenceAndSideEffects() {
        wirePersistence()
        wireSideEffects()
    }

    /// 同步每日提醒状态：今天已专注则取消，否则按设置调度
    private func syncReminder() {
        guard settings.dailyReminderEnabled else {
            notifications.cancelDailyReminder()
            return
        }
        if hasFocusedToday() {
            notifications.cancelDailyReminder()
        } else {
            notifications.scheduleIfAuthorized(
                hour: settings.dailyReminderHour,
                minute: settings.dailyReminderMinute
            )
        }
    }

    /// 今天是否已有合格的专注记录（≥5s，recordSession 才会写入）
    private func hasFocusedToday() -> Bool {
        sessions.contains { Calendar.current.isDateInToday($0.endedAt) }
    }

    private func syncCountdownReminders() {
        let events = countdownEvents
        notifications.cancelAllCountdownReminders { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                events.forEach(self.syncCountdownReminder)
            }
        }
    }

    private func syncCountdownReminder(for event: CountdownEvent) {
        guard !isPreviewMode else { return }
        guard event.notificationEnabled else {
            notifications.cancelCountdownReminder(eventID: event.id)
            return
        }

        let reminderDate = normalizedCountdownDate(event.date, includesTime: event.includesTime)
        guard reminderDate > Date.now else {
            notifications.cancelCountdownReminder(eventID: event.id)
            return
        }
        notifications.scheduleCountdownReminderIfAuthorized(
            eventID: event.id,
            title: event.title,
            date: reminderDate
        )
    }

    private func normalizedCountdownDate(_ date: Date, includesTime: Bool) -> Date {
        includesTime ? date : Calendar.current.startOfDay(for: date)
    }

    private func showNotice(_ message: String) {
        noticeTask?.cancel()
        globalNotice = message

        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.globalNotice = nil
            }
        }
    }

    private func updateImmersiveActivationClock(previousTab: AppTab, newTab: AppTab) {
        if newTab == .active {
            if previousTab != .active {
                if let session = activeSession, session.phase == .focus, !session.isPaused {
                    activeTabEnteredAt = .now
                } else {
                    activeTabEnteredAt = nil
                }
            }
        } else {
            activeTabEnteredAt = nil
        }
    }

    func clearAllData() {
        guard !isPreviewMode else { return }

        // Reset to default state
        tasks = []
        sessions = []
        countdownEvents = []
        profile = ProfileInfo.default
        settings = AppSettings.default
        checkInDates = []
        lastTaskID = nil
        quickLaunchTaskID = nil
        activeSession = nil
        selectedTab = .active

        // 清除持久化数据
        let dataStore = DataStore(
            version: StorageSchemaVersion.current,
            tasks: [],
            sessions: [],
            countdownEvents: [],
            profile: ProfileInfo.default,
            checkInDates: [],
            lastTaskID: nil,
            activeSession: nil
        )
        persistence.save(data: dataStore)
        persistence.save(settings: currentSettingsStore())
        notifications.cancelDailyReminder()
        refreshDerivedState(shouldSyncActivity: true)
        showNotice(String(localized: "settings.clearData.success"))
    }

    // MARK: - 数据导入导出

    /// 导出数据为含版本号的 JSON 文件
    func exportData() -> Data? {
        guard !isPreviewMode else { return nil }

        let dataStore = DataStore(
            version: StorageSchemaVersion.current,
            tasks: tasks,
            sessions: sessions,
            countdownEvents: countdownEvents,
            profile: profile,
            checkInDates: checkInDates,
            lastTaskID: lastTaskID,
            activeSession: activeSession
        )
        return persistence.exportData(data: dataStore, settings: settings)
    }

    /// 预检导入文件，供 UI 展示版本提示；返回值可直接传给 importData(_:)。
    func inspectImport(data: Data) -> PersistenceService.ImportResult? {
        persistence.inspectImport(data: data)
    }

    /// 从原始 JSON 数据导入；适合外部调用，内部会先完成一次预检解析。
    func importData(from data: Data) -> ImportStatus {
        guard !isPreviewMode else { return .failed }

        guard let result = inspectImport(data: data) else {
            return .failed
        }
        return importData(result)
    }

    /// 使用已预检解析的结果导入，避免确认弹窗后再次解码同一份文件。
    func importData(_ result: PersistenceService.ImportResult) -> ImportStatus {
        guard !isPreviewMode else { return .failed }

        // 应用导入的数据
        tasks = result.tasks.sorted(by: { $0.order < $1.order })
        sessions = result.sessions.sorted(by: { $0.startedAt > $1.startedAt })
        countdownEvents = result.countdownEvents.sorted(by: { $0.date < $1.date })
        profile = result.profile
        settings = result.settings
        checkInDates = Self.normalizedCheckInDates(result.checkInDates ?? [])
        lastTaskID = result.lastTaskID
        quickLaunchTaskID = result.lastTaskID
        activeSession = nil // 导入时不恢复进行中的计时

        // 持久化数据
        let dataStore = DataStore(
            version: StorageSchemaVersion.current,
            tasks: tasks,
            sessions: sessions,
            countdownEvents: countdownEvents,
            profile: profile,
            checkInDates: checkInDates,
            lastTaskID: lastTaskID,
            activeSession: activeSession
        )
        persistence.save(data: dataStore)
        persistence.save(settings: currentSettingsStore())

        refreshDerivedState(shouldSyncActivity: true)
        syncReminder()

        return ImportStatus.success(
            fileVersion: result.fileVersion,
            isLegacy: result.isLegacy,
            isSignatureMismatch: result.isSignatureMismatch
        )
    }

    enum ImportStatus {
        case success(fileVersion: Int, isLegacy: Bool, isSignatureMismatch: Bool)
        case failed

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }
}

// MARK: - 自定义文件类型

extension UTType {
    static var chronaData: UTType {
        UTType.json
    }
}
