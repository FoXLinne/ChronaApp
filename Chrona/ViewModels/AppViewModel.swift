import Combine
import Foundation
import os
import SwiftUI
import ActivityKit
import UniformTypeIdentifiers
import WidgetKit

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
    private let persistence = Persistence()
    private let notifications = Notifications()
    private let logger = Logger(subsystem: "top.kaedekr.chrona", category: "AppViewModel")
    private var ticker: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var noticeTask: Task<Void, Never>?
    private let isPreviewMode: Bool
    private var activeTabEnteredAt: Date? = .now

    init(forcePreviewMode: Bool = false) {
        let runningForPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        isPreviewMode = forcePreviewMode || runningForPreview

        if isPreviewMode {
            let defaultData = DataStore.default
            tasks = defaultData.tasks.sorted(by: { $0.order < $1.order })
            sessions = defaultData.sessions.sorted(by: { $0.startedAt > $1.startedAt })
            countdownEvents = defaultData.countdownEvents.sorted(by: { $0.date < $1.date })
            profile = defaultData.profile
            settings = AppSettings.default
            checkInDates = CheckIn.normalizedDates(defaultData.checkInDates)
            lastTaskID = defaultData.lastTaskID
            activeSession = defaultData.activeSession
            quickLaunchTaskID = defaultData.lastTaskID
        } else {
            let dataStore = persistence.loadData()
            let storedSettings = persistence.loadSettings()

            tasks = dataStore.tasks.sorted(by: { $0.order < $1.order })
            sessions = dataStore.sessions.sorted(by: { $0.startedAt > $1.startedAt })
            countdownEvents = dataStore.countdownEvents.sorted(by: { $0.date < $1.date })
            profile = dataStore.profile
            settings = storedSettings
            checkInDates = CheckIn.normalizedDates(dataStore.checkInDates)
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
        refreshCheckInCache()
    }

    static func previewModel() -> AppViewModel {
        let model = AppViewModel(forcePreviewMode: true)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today) ?? today
        model.checkInDates = CheckIn.normalizedDates([today, yesterday, twoDaysAgo])

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

    // MARK: - 计算属性

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

    // MARK: - 任务管理（委托 TaskManager）

    func createTask(title: String, mode: FocusMode, presetID: String, countdownDuration: TimeInterval, backgroundName: String) {
        tasks = TaskManager.createTask(
            title: title,
            mode: mode,
            presetID: presetID,
            countdownDuration: countdownDuration,
            backgroundName: backgroundName,
            in: tasks
        )
    }

    func updateTask(_ task: TaskItem) {
        tasks = TaskManager.updateTask(task, in: tasks)
    }

    func isTaskNameDuplicate(_ title: String, excluding id: UUID?) -> Bool {
        TaskManager.isTaskNameDuplicate(title, excluding: id, in: tasks)
    }

    func deleteTasks(at offsets: IndexSet) {
        tasks = TaskManager.deleteTasks(at: offsets, sortedTasks: sortedTasks, in: tasks)
    }

    func deleteTask(id: UUID) {
        tasks = TaskManager.deleteTask(id: id, in: tasks)
    }

    func moveTasks(from source: IndexSet, to destination: Int) {
        tasks = TaskManager.moveTasks(from: source, to: destination, sortedTasks: sortedTasks)
    }

    func completedCountToday(for task: TaskItem) -> Int {
        TaskManager.completedCountToday(for: task, in: sessions)
    }

    // MARK: - 倒数日管理（委托 CountdownManager）

    func addCountdownEvent(title: String, date: Date, includesTime: Bool = false, notificationEnabled: Bool = false) {
        countdownEvents = CountdownManager.addEvent(
            title: title,
            date: date,
            includesTime: includesTime,
            notificationEnabled: notificationEnabled,
            in: countdownEvents
        )
        if let last = countdownEvents.last {
            syncCountdownReminder(for: last)
        }
        syncWidgetData()
    }

    func updateCountdownEvent(_ event: CountdownEvent) {
        countdownEvents = CountdownManager.updateEvent(event, in: countdownEvents)
        if let updated = countdownEvents.first(where: { $0.id == event.id }) {
            syncCountdownReminder(for: updated)
        }
        syncWidgetData()
    }

    func deleteCountdownEvent(id: UUID) {
        countdownEvents = CountdownManager.deleteEvent(id: id, in: countdownEvents)
        notifications.cancelCountdownReminder(eventID: id)
        syncWidgetData()
    }

    var futureEvents: [CountdownEvent] {
        CountdownManager.futureEvents(in: countdownEvents, now: now)
    }

    var todayEvents: [CountdownEvent] {
        CountdownManager.todayEvents(in: countdownEvents)
    }

    var pastEvents: [CountdownEvent] {
        CountdownManager.pastEvents(in: countdownEvents, now: now)
    }

    // MARK: - 会话管理（委托 SessionManager）

    @discardableResult
    func startTask(_ task: TaskItem) -> Bool {
        guard activeSession == nil else {
            selectedTab = .active
            showNotice(String(localized: "session.alreadyRunning"))
            return false
        }

        guard let snapshot = SessionManager.startTask(task, activeSession: activeSession, now: now) else {
            return false
        }

        activeSession = snapshot
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
        SessionManager.stopConsequence(
            activeSession: activeSession,
            now: now,
            advancedDisallowEarlyFinish: settings.advancedDisallowEarlyFinish
        )
    }

    func pauseOrResumeActiveSession() {
        let result = SessionManager.togglePause(
            activeSession: activeSession,
            settings: settings,
            selectedTab: selectedTab,
            now: now
        )
        guard let snapshot = result.snapshot else { return }
        activeSession = snapshot
        if let notice = result.notice {
            showNotice(notice)
        }
        if result.resetImmersiveClock {
            activeTabEnteredAt = .now
        }
        if !result.resetImmersiveClock && activeSession?.isPaused == true {
            activeTabEnteredAt = nil
        }
        refreshDerivedState(shouldSyncActivity: true)
    }

    func stopActiveSession(forceAbandon: Bool = false) {
        let result = SessionManager.stopActiveSession(
            activeSession: activeSession,
            now: now,
            settings: settings,
            autoMoveCompletedTaskToTop: settings.autoMoveCompletedTaskToTop
        )

        if let notice = result.notice {
            showNotice(notice)
        }

        if let record = result.recordedSession,
           let session = activeSession,
           !SessionManager.hasRecordedSession(sessions: sessions, session: session, duration: record.focusedDuration, completed: record.wasCompleted) {
            sessions.insert(record, at: 0)
            // 自动置顶已完成的任务
            if settings.autoMoveCompletedTaskToTop, let taskID = session.taskID, let index = tasks.firstIndex(where: { $0.id == taskID }) {
                var moved = tasks.remove(at: index)
                moved.order = 0
                tasks.insert(moved, at: 0)
                tasks = TaskManager.moveTasks(from: IndexSet(integer: 0), to: 0, sortedTasks: sortedTasks)
            }
        }

        if result.shouldBeginRest {
            if let session = activeSession, let restDur = SessionManager.restDuration(after: session, activeTask: activeTask, restDurationMinutes: settings.restDurationMinutes) {
                activeSession = SessionManager.makeRestSnapshot(after: session, restDuration: restDur)
            } else {
                activeSession = nil
            }
        } else {
            activeSession = nil
        }

        activeTabEnteredAt = nil
        refreshDerivedState(shouldSyncActivity: true)
        persistState()
    }

    func endRest() {
        activeSession = SessionManager.endRest()
        activeTabEnteredAt = nil
        refreshDerivedState(shouldSyncActivity: true)
        persistState()
    }

    // MARK: - 签到管理（委托 CheckIn，结果缓存）

    /// 缓存的签到计算结果，仅当 checkInDates 变化时重算
    private var cachedCheckInStreak: Int = 0
    private var cachedLongestCheckInStreak: Int = 0

    var hasCheckedInToday: Bool {
        CheckIn.hasCheckedInToday(in: checkInDates)
    }

    var totalCheckInCount: Int {
        CheckIn.totalCheckInCount(in: checkInDates)
    }

    var checkInStreak: Int {
        cachedCheckInStreak
    }

    var longestCheckInStreak: Int {
        cachedLongestCheckInStreak
    }

    private func refreshCheckInCache() {
        cachedCheckInStreak = CheckIn.checkInStreak(in: checkInDates)
        cachedLongestCheckInStreak = CheckIn.longestCheckInStreak(in: checkInDates)
    }

    @discardableResult
    func checkInToday() -> Bool {
        let result = CheckIn.checkInToday(in: checkInDates)
        checkInDates = result.dates
        refreshCheckInCache()
        return result.success
    }

    // MARK: - 统计数据（委托 Statistics）

    func dailyFocusDurations(for month: Date) -> [Date: TimeInterval] {
        Statistics.dailyFocusDurations(sessions: sessions, for: month)
    }

    func totalFocusedDuration(for range: TimeRange) -> TimeInterval {
        Statistics.totalFocusedDuration(sessions: sessions, range: range)
    }

    func totalFocusedCount(for range: TimeRange) -> Int {
        Statistics.totalFocusedCount(sessions: sessions, range: range)
    }

    func averageDailyDuration() -> TimeInterval {
        Statistics.averageDailyDuration(sessions: sessions)
    }

    var totalFocusedDurationAllTime: TimeInterval {
        Statistics.totalFocusedDurationAllTime(sessions: sessions)
    }

    func taskDistribution(range: TimeRange) -> [TaskDistributionEntry] {
        Statistics.taskDistribution(sessions: sessions, range: range)
    }

    func taskDistribution(on date: Date) -> [TaskDistributionEntry] {
        Statistics.taskDistribution(sessions: sessions, on: date)
    }

    func monthlyTrendPoints() -> [DayTrendEntry] {
        Statistics.monthlyTrendPoints(sessions: sessions, selectedMonth: selectedStatisticsMonth)
    }

    func statisticsTrendDomain() -> ClosedRange<Date> {
        Statistics.trendDomain(selectedMonth: selectedStatisticsMonth)
    }

    var statisticsTrendVisibleLength: TimeInterval {
        Statistics.trendVisibleLength()
    }

    func updateStatisticsTrendScrollDate(_ candidate: Date) {
        statisticsTrendScrollDate = Statistics.clampedTrendStartDate(candidate, month: selectedStatisticsMonth)
    }

    func resetStatisticsTrendToToday() {
        selectedStatisticsMonth = Statistics.monthStartDate(for: .now)
        statisticsTrendScrollDate = Statistics.defaultTrendStartDate(for: selectedStatisticsMonth, anchorDate: .now)
    }

    func cycleStatisticsMonth(forward: Bool) {
        let result = Statistics.cycleMonth(selectedMonth: selectedStatisticsMonth, forward: forward)
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedStatisticsMonth = result.month
            statisticsTrendScrollDate = result.scrollDate
        }
    }

    // MARK: - 主题

    func applyTheme() -> ColorScheme? {
        switch settings.theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    // MARK: - 内部：计时器

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

        let finishedSession = activeSession
        let finishedTask = activeTask
        let result = SessionManager.handleTimerTick(
            activeSession: activeSession,
            now: now,
            settings: settings,
            selectedTab: selectedTab
        )

        if let notice = result.autoResumeNotice {
            showNotice(notice)
            if result.newActiveSession?.isPaused == false {
                activeTabEnteredAt = selectedTab == .active ? .now : nil
            }
        }

        activeSession = result.newActiveSession

        if let stopResult = result.stopResult {
            applyStopResult(stopResult, after: finishedSession, activeTask: finishedTask)
        }

        if result.shouldEndRest {
            activeSession = nil
        }

        refreshDerivedState()
        syncLiveActivity()
    }

    private func reconcileActiveSessionIfNeeded() {
        guard activeSession != nil else {
            refreshDerivedState(shouldSyncActivity: true)
            return
        }

        let finishedSession = activeSession
        let finishedTask = activeTask
        let result = SessionManager.reconcile(
            activeSession: activeSession,
            now: now,
            settings: settings,
            selectedTab: selectedTab
        )

        if let notice = result.autoResumeNotice {
            showNotice(notice)
            if result.newActiveSession?.isPaused == false {
                activeTabEnteredAt = selectedTab == .active ? .now : nil
            }
        }

        activeSession = result.newActiveSession

        if let stopResult = result.stopResult {
            applyStopResult(stopResult, after: finishedSession, activeTask: finishedTask)
        }

        if result.shouldEndRest {
            activeSession = nil
        }

        refreshDerivedState(shouldSyncActivity: true)
    }

    /// 将 StopResult 应用到当前状态（记录会话、置顶任务等）。
    private func applyStopResult(
        _ result: SessionManager.StopResult,
        after finishedSession: ActiveSessionSnapshot?,
        activeTask finishedTask: TaskItem?
    ) {
        if let notice = result.notice {
            showNotice(notice)
        }

        if let record = result.recordedSession {
            sessions.insert(record, at: 0)
            if settings.autoMoveCompletedTaskToTop, let taskID = record.taskID, let index = tasks.firstIndex(where: { $0.id == taskID }) {
                var moved = tasks.remove(at: index)
                moved.order = 0
                tasks.insert(moved, at: 0)
            }
        }

        if result.shouldBeginRest {
            // 自然结束时 activeSession 已被清空，必须用刚结束的会话创建休息阶段。
            if let session = finishedSession, let restDur = SessionManager.restDuration(after: session, activeTask: finishedTask, restDurationMinutes: settings.restDurationMinutes) {
                activeSession = SessionManager.makeRestSnapshot(after: session, restDuration: restDur)
            } else {
                activeSession = nil
            }
        }
    }

    // MARK: - 内部：持久化

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
        .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.persistDataState()
        }
        .store(in: &cancellables)

        $settings
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
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

    // MARK: - 内部：副作用

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
            .sink { [weak self] newSettings in self?.syncReminder(settings: newSettings) }
            .store(in: &cancellables)

        // 提醒同步：当天完成专注后自动取消当天提醒
        $sessions
            .dropFirst()
            .sink { [weak self] newSessions in self?.syncReminder(sessions: newSessions) }
            .store(in: &cancellables)

        // Live Activity 同步：开关变更时立即启停灵动岛/锁屏实时活动
        $settings
            .dropFirst()
            .removeDuplicates { $0.liveActivitiesEnabled == $1.liveActivitiesEnabled }
            .sink { [weak self] _ in self?.syncLiveActivity() }
            .store(in: &cancellables)

        // 签到缓存：checkInDates 变化时重算连续天数
        $checkInDates
            .dropFirst()
            .sink { [weak self] _ in self?.refreshCheckInCache() }
            .store(in: &cancellables)
    }

    private func wirePersistenceAndSideEffects() {
        wirePersistence()
        wireSideEffects()
    }

    // MARK: - 内部：通知

    private func syncReminder(settings effectiveSettings: AppSettings? = nil, sessions effectiveSessions: [FocusSessionRecord]? = nil) {
        // @Published 在 willSet 发出新值；提醒同步优先使用 publisher 传入的新状态。
        let settings = effectiveSettings ?? self.settings
        let sessions = effectiveSessions ?? self.sessions

        guard settings.dailyReminderEnabled else {
            notifications.cancelDailyReminder()
            return
        }
        if sessions.contains(where: { Calendar.current.isDateInToday($0.endedAt) }) {
            notifications.cancelDailyReminder()
        } else {
            notifications.scheduleIfAuthorized(
                hour: settings.dailyReminderHour,
                minute: settings.dailyReminderMinute
            )
        }
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

        let reminderDate = CountdownManager.normalizedDate(event.date, includesTime: event.includesTime)
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

    // MARK: - 内部：Live Activity

    private func syncLiveActivity() {
        guard settings.liveActivitiesEnabled else {
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
            let endTime = status.remaining.map { Date.now.addingTimeInterval($0) }
            let elapsedReferenceDate = Date.now.addingTimeInterval(-status.elapsed)

            let pausedTimerText: String
            let pauseEndTime: Date?
            if session.isPaused, let pauseDeadline = session.pauseDeadline {
                pausedTimerText = ""
                pauseEndTime = pauseDeadline
            } else if session.isPaused {
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
                modeLabel: session.mode.label,
                modeSystemImage: session.mode.symbol,
                isPaused: session.isPaused,
                isRest: session.phase == .rest,
                isStopwatch: session.mode == .stopwatch && session.phase == .focus
            )

            let staleDate = endTime

            if let activity = timerActivity,
               Activity<TimerActivityAttributes>.activities.contains(where: { $0.id == activity.id }) {
                Task {
                    await activity.update(ActivityContent(state: state, staleDate: staleDate))
                }
            } else {
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
                        logger.error("Live Activity failed to start: \(error.localizedDescription)")
                    }
                }
            }
        } else {
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

    // MARK: - 内部：工具

    private func refreshDerivedState(shouldSyncActivity: Bool = false) {
        ScreenAwakeController.update(isEnabled: settings.keepScreenAwake && activeSession != nil)
        if shouldSyncActivity {
            syncLiveActivity()
        }
        syncWidgetData()
    }

    private func syncWidgetData() {
        let todayDuration = sessions
            .filter { Calendar.current.isDateInToday($0.endedAt) }
            .reduce(0) { $0 + $1.focusedDuration }
        SharedStore.syncTodayFocusDuration(todayDuration)
        SharedStore.syncCountdownEvents(
            countdownEvents.map {
                SharedCountdownEvent(
                    id: $0.id,
                    title: $0.title,
                    date: $0.date,
                    includesTime: $0.includesTime
                )
            }
        )
        SharedStore.syncMonthlyFocusDurations(
            dailyFocusDurations(for: .now)
                .map { day, duration in
                    SharedDailyFocusDuration(day: day, duration: duration)
                }
                .sorted(by: { $0.day < $1.day })
        )
        WidgetCenter.shared.reloadAllTimelines()
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

    // MARK: - 数据清除

    func clearAllData() {
        guard !isPreviewMode else { return }

        let defaultData = DataStore.default
        tasks = defaultData.tasks.sorted(by: { $0.order < $1.order })
        sessions = []
        countdownEvents = defaultData.countdownEvents.sorted(by: { $0.date < $1.date })
        profile = ProfileInfo.default
        settings = AppSettings.default
        checkInDates = []
        lastTaskID = nil
        quickLaunchTaskID = nil
        activeSession = nil
        selectedTab = .active

        let dataStore = DataStore(
            version: StorageSchemaVersion.current,
            tasks: tasks,
            sessions: [],
            countdownEvents: countdownEvents,
            profile: ProfileInfo.default,
            checkInDates: [],
            lastTaskID: nil,
            activeSession: nil
        )
        persistence.save(data: dataStore)
        persistence.save(settings: currentSettingsStore())
        notifications.cancelDailyReminder()
        notifications.cancelAllCountdownReminders()
        refreshDerivedState(shouldSyncActivity: true)
        showNotice(String(localized: "settings.clearData.success"))
    }

    // MARK: - 数据导入导出

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

    func inspectImport(data: Data) -> Persistence.ImportResult? {
        persistence.inspectImport(data: data)
    }

    func importData(from data: Data) -> ImportStatus {
        guard !isPreviewMode else { return .failed }

        guard let result = inspectImport(data: data) else {
            return .failed
        }
        return importData(result)
    }

    func importData(_ result: Persistence.ImportResult) -> ImportStatus {
        guard !isPreviewMode else { return .failed }

        tasks = result.tasks.sorted(by: { $0.order < $1.order })
        sessions = result.sessions.sorted(by: { $0.startedAt > $1.startedAt })
        countdownEvents = result.countdownEvents.sorted(by: { $0.date < $1.date })
        profile = result.profile
        settings = result.settings
        checkInDates = CheckIn.normalizedDates(result.checkInDates)
        lastTaskID = result.lastTaskID
        quickLaunchTaskID = result.lastTaskID
        activeSession = nil

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
        syncCountdownReminders()

        return ImportStatus.success(
            fileVersion: result.fileVersion,
            sourceAppVersion: result.sourceAppVersion,
            sourceBuildNumber: result.sourceBuildNumber,
            isSignatureMismatch: result.isSignatureMismatch
        )
    }

    enum ImportStatus {
        case success(
            fileVersion: Int,
            sourceAppVersion: String?,
            sourceBuildNumber: Int?,
            isSignatureMismatch: Bool
        )
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
