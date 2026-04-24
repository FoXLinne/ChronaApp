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
        let snapshot = isPreviewMode ? AppSnapshot.default : persistence.load()
        self.tasks = snapshot.tasks.sorted(by: { $0.order < $1.order })
        self.sessions = snapshot.sessions.sorted(by: { $0.startedAt > $1.startedAt })
        self.countdownEvents = snapshot.countdownEvents.sorted(by: { $0.date < $1.date })
        self.profile = snapshot.profile
        self.settings = snapshot.settings
        self.checkInDates = Self.normalizedCheckInDates(snapshot.checkInDates ?? [])
        self.lastTaskID = snapshot.lastTaskID
        self.activeSession = snapshot.activeSession
        self.quickLaunchTaskID = snapshot.lastTaskID

        startTicker()
        if !isPreviewMode {
            wirePersistence()
            syncReminder()
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

    func addCountdownEvent(title: String, date: Date) {
        countdownEvents.append(CountdownEvent(title: title, date: date))
        countdownEvents.sort(by: { $0.date < $1.date })
    }

    func updateCountdownEvent(_ event: CountdownEvent) {
        guard let index = countdownEvents.firstIndex(where: { $0.id == event.id }) else { return }
        countdownEvents[index] = event
        countdownEvents.sort(by: { $0.date < $1.date })
    }

    func deleteCountdownEvent(id: UUID) {
        countdownEvents.removeAll(where: { $0.id == id })
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

    @discardableResult
    func checkInToday() -> Bool {
        let today = Calendar.current.startOfDay(for: .now)
        guard !checkInDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: today) }) else {
            return false
        }

        checkInDates = Self.normalizedCheckInDates(checkInDates + [today])
        return true
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
        let dayCount = max(1, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: earliest), to: Calendar.current.startOfDay(for: .now)).day ?? 0)
        return sessions.reduce(0) { $0 + $1.focusedDuration } / Double(dayCount)
    }

    var futureEvents: [CountdownEvent] {
        countdownEvents.filter { $0.date >= Calendar.current.startOfDay(for: .now) }
    }

    var pastEvents: [CountdownEvent] {
        countdownEvents.filter { $0.date < Calendar.current.startOfDay(for: .now) }.sorted(by: { $0.date > $1.date })
    }

    func taskDistribution(range: TimeRange) -> [TaskDistributionEntry] {
        let grouped = Dictionary(grouping: filteredSessions(range: range), by: \.taskTitle)
        return grouped.map { key, value in
            TaskDistributionEntry(id: UUID(), taskTitle: key, duration: value.reduce(0) { $0 + $1.focusedDuration }, colorSeed: key)
        }
        .sorted(by: { $0.duration > $1.duration })
    }

    func monthlyTrendPoints() -> [DayTrendEntry] {
        let calendar = Calendar.current
        let monthStart = statisticsMonthStart(for: selectedStatisticsMonth)
        let monthEnd = statisticsMonthEnd(for: selectedStatisticsMonth)
        let dayCount = max(1, calendar.dateComponents([.day], from: monthStart, to: monthEnd).day ?? 0)

        return (0...dayCount).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: monthStart) ?? monthStart
            let duration = sessions
                .filter { calendar.isDate($0.endedAt, inSameDayAs: date) }
                .reduce(0) { $0 + $1.focusedDuration }
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
        if forward {
            let currentMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
            selectedStatisticsMonth = min(candidate, currentMonth)
        } else {
            selectedStatisticsMonth = candidate
        }
        selectedStatisticsMonth = statisticsMonthStart(for: selectedStatisticsMonth)
        statisticsTrendScrollDate = defaultStatisticsTrendStartDate(for: selectedStatisticsMonth, anchorDate: selectedStatisticsMonth)
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
            Task {
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

            // 暂停时的冻结显示文字（用于 Widget 显示静态快照，不会随时间自动更新）
            let pausedTimerText: String
            if session.isPaused {
                if session.mode == .stopwatch {
                    pausedTimerText = formattedDuration(status.elapsed)
                } else {
                    pausedTimerText = formattedDuration(status.remaining ?? 0)
                }
            } else {
                pausedTimerText = ""
            }

            // 阶段标签（暂停时覆盖为「已暂停」）
            let phaseLabel: String
            if session.isPaused {
                phaseLabel = String(localized: "la.paused")
            } else if session.phase == .focus {
                phaseLabel = String(localized: "la.phase.focus")
            } else {
                phaseLabel = String(localized: "la.phase.rest")
            }

            let state = TimerActivityAttributes.ContentState(
                endTime: endTime,
                elapsedReferenceDate: elapsedReferenceDate,
                pausedTimerText: pausedTimerText,
                taskTitle: session.taskTitle,
                phaseLabel: phaseLabel,
                modeLabel: liveActivityModeLabel(for: session.mode),
                modeSystemImage: liveActivityModeImage(for: session.mode),
                isPaused: session.isPaused,
                isStopwatch: session.mode == .stopwatch
            )

            // staleDate：倒计时/番茄钟在结束时间标记为过期；秒表无限期
            let staleDate = endTime

            if let activity = timerActivity {
                Task {
                    await activity.update(ActivityContent(state: state, staleDate: staleDate))
                }
            } else {
                // 尝试复用应用重启前遗留的活动实例
                if let existingActivity = Activity<TimerActivityAttributes>.activities.first {
                    timerActivity = existingActivity
                    Task {
                        await existingActivity.update(ActivityContent(state: state, staleDate: staleDate))
                    }
                } else {
                    // 启动新活动
                    let attributes = TimerActivityAttributes(taskID: session.taskID)
                    do {
                        timerActivity = try Activity.request(
                            attributes: attributes,
                            content: ActivityContent(state: state, staleDate: staleDate),
                            pushType: nil
                        )
                    } catch {
                        print("Live Activity 启动失败: \(error.localizedDescription)")
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
        // 数据持久化：监听所有状态变化
        Publishers.MergeMany(
            $profile.map { _ in () }.eraseToAnyPublisher(),
            $settings.map { _ in () }.eraseToAnyPublisher(),
            $activeSession.map { _ in () }.eraseToAnyPublisher(),
            $countdownEvents.map { _ in () }.eraseToAnyPublisher(),
            $tasks.map { _ in () }.eraseToAnyPublisher(),
            $sessions.map { _ in () }.eraseToAnyPublisher(),
            $checkInDates.map { _ in () }.eraseToAnyPublisher(),
            $lastTaskID.map { _ in () }.eraseToAnyPublisher()
        )
        .sink { [weak self] _ in
            self?.persistState()
        }
        .store(in: &cancellables)

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
    }

    private func persistState() {
        guard !isPreviewMode else { return }

        let snapshot = AppSnapshot(
            tasks: tasks,
            sessions: sessions,
            countdownEvents: countdownEvents,
            profile: profile,
            settings: settings,
            checkInDates: checkInDates,
            lastTaskID: lastTaskID,
            activeSession: activeSession
        )
        persistence.save(snapshot)
        // 通知调度由专用订阅者负责，不在 persistState 中处理
        refreshDerivedState()
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
        let defaultSnapshot = AppSnapshot.default
        tasks = defaultSnapshot.tasks
        sessions = []
        countdownEvents = []
        profile = ProfileInfo.default
        settings = AppSettings.default
        checkInDates = []
        lastTaskID = nil
        quickLaunchTaskID = nil
        activeSession = nil
        selectedTab = .active

        // Clear persisted data
        persistence.save(defaultSnapshot)
        notifications.cancelDailyReminder()
        refreshDerivedState(shouldSyncActivity: true)
        showNotice(String(localized: "settings.clearData.success"))
    }

    // MARK: - 数据导入导出
    
    /// 导出数据为 JSON 文件
    func exportData() -> Data? {
        guard !isPreviewMode else { return nil }
        
        let snapshot = AppSnapshot(
            tasks: tasks,
            sessions: sessions,
            countdownEvents: countdownEvents,
            profile: profile,
            settings: settings,
            checkInDates: checkInDates,
            lastTaskID: lastTaskID,
            activeSession: activeSession
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try? encoder.encode(snapshot)
    }
    
    /// 导入数据从 JSON 文件
    func importData(from data: Data) -> Bool {
        guard !isPreviewMode else { return false }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let snapshot = try? decoder.decode(AppSnapshot.self, from: data) else {
            return false
        }
        
        // 应用导入的数据
        tasks = snapshot.tasks.sorted(by: { $0.order < $1.order })
        sessions = snapshot.sessions.sorted(by: { $0.startedAt > $1.startedAt })
        countdownEvents = snapshot.countdownEvents.sorted(by: { $0.date < $1.date })
        profile = snapshot.profile
        settings = snapshot.settings
        checkInDates = Self.normalizedCheckInDates(snapshot.checkInDates ?? [])
        lastTaskID = snapshot.lastTaskID
        quickLaunchTaskID = snapshot.lastTaskID
        activeSession = snapshot.activeSession
        
        // 持久化数据
        persistence.save(snapshot)
        refreshDerivedState(shouldSyncActivity: true)
        syncReminder()
        
        showNotice(String(localized: "settings.importData.success"))
        return true
    }
}

// MARK: - 自定义文件类型

extension UTType {
    static var chronaData: UTType {
        UTType.json
    }
}
