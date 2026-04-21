import Combine
import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var tasks: [TaskItem]
    @Published private(set) var sessions: [FocusSessionRecord]
    @Published private(set) var countdownEvents: [CountdownEvent]
    @Published var profile: ProfileInfo
    @Published var settings: AppSettings
    @Published private(set) var sleepWakeRecords: [SleepWakeRecord]
    @Published private(set) var lastTaskID: UUID?
    @Published var activeSession: ActiveSessionSnapshot?
    @Published var now: Date = .now
    @Published var selectedStatisticsMonth: Date = .now
    @Published var selectedStatisticsWeekOffset: Int = 0
    @Published var selectedRoutineMonth: Date = .now
    @Published var selectedRoutineWeekOffset: Int = 0
    @Published var quickLaunchTaskID: UUID?

    private let persistence = PersistenceService()
    private let notifications = NotificationService()
    private var ticker: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    init() {
        let snapshot = persistence.load()
        self.tasks = snapshot.tasks.sorted(by: { $0.order < $1.order })
        self.sessions = snapshot.sessions.sorted(by: { $0.startedAt > $1.startedAt })
        self.countdownEvents = snapshot.countdownEvents.sorted(by: { $0.date < $1.date })
        self.profile = snapshot.profile
        self.settings = snapshot.settings
        self.sleepWakeRecords = snapshot.sleepWakeRecords.sorted(by: { $0.date > $1.date })
        self.lastTaskID = snapshot.lastTaskID
        self.activeSession = snapshot.activeSession
        self.quickLaunchTaskID = snapshot.lastTaskID

        startTicker()
        wirePersistence()
        restoreReminder()
        refreshDerivedState()
    }

    var sortedTasks: [TaskItem] {
        tasks.sorted(by: { $0.order < $1.order })
    }

    var activeTask: TaskItem? {
        guard let id = activeSession?.taskID else { return nil }
        return tasks.first(where: { $0.id == id })
    }

    var timerStatus: TimerStatus? {
        guard let activeSession else { return nil }
        return TimerEngine.status(for: activeSession, now: now)
    }

    var shouldShowMinimalMode: Bool {
        guard settings.enableMinimalBlackMode, let activeSession else { return false }
        guard activeSession.phase == .focus, !activeSession.isPaused else { return false }
        return (timerStatus?.elapsed ?? 0) >= 5
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

    func deleteTasks(at offsets: IndexSet) {
        let ids = offsets.map { sortedTasks[$0].id }
        tasks.removeAll(where: { ids.contains($0.id) })
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

    func deleteCountdownEvents(at offsets: IndexSet, from future: Bool) {
        let target = future ? futureEvents : pastEvents
        let ids = offsets.map { target[$0].id }
        countdownEvents.removeAll(where: { ids.contains($0.id) })
    }

    func startTask(_ task: TaskItem) {
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
        refreshDerivedState()
    }

    func quickStartLastTask() {
        guard let id = quickLaunchTaskID, let task = tasks.first(where: { $0.id == id }) else { return }
        startTask(task)
    }

    func pauseOrResumeActiveSession() {
        guard var session = activeSession else { return }
        guard session.mode == .stopwatch else { return }
        guard !settings.advancedDisallowPause else { return }

        if session.isPaused {
            let pausedDuration = Date.now.timeIntervalSince(session.pausedAt ?? .now)
            session.pausedAccumulated += pausedDuration
            session.pausedAt = nil
            session.isPaused = false
            session.pauseDeadline = nil
        } else {
            session.isPaused = true
            session.pausedAt = .now
            if let limit = settings.stopwatchPauseLimitMinutes {
                session.pauseDeadline = Calendar.current.date(byAdding: .minute, value: limit, to: .now)
            }
        }
        activeSession = session
        refreshDerivedState()
    }

    func stopActiveSession(forceAbandon: Bool = false) {
        guard let session = activeSession else { return }
        let status = TimerEngine.status(for: session, now: now)
        let focusDuration = session.phase == .focus ? status.elapsed : 0
        let isQualified = focusDuration >= 5
        let isCompleted = session.phase == .focus && (session.focusDuration.map { focusDuration >= $0 } ?? isQualified)
        let isAbandoned = forceAbandon || (settings.advancedDisallowEarlyFinish && !isCompleted)

        if session.phase == .focus, isQualified, !isAbandoned {
            recordSession(session: session, duration: min(focusDuration, session.focusDuration ?? focusDuration), completed: isCompleted)
        }

        if session.phase == .focus {
            beginRestIfNeeded(after: session)
        } else {
            activeSession = nil
        }
        refreshDerivedState()
    }

    func endRest() {
        activeSession = nil
        refreshDerivedState()
    }

    func addSleepTime(_ date: Date) {
        upsertRoutine(for: date, isSleep: true)
    }

    func addWakeTime(_ date: Date) {
        let dayStart = Calendar.current.startOfDay(for: date)
        guard !sleepWakeRecords.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: dayStart) && $0.wakeTime != nil }) else {
            return
        }
        upsertRoutine(for: date, isSleep: false)
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

    func monthlyTrend(weekOffset: Int) -> [DayTrendEntry] {
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: selectedStatisticsMonth)) ?? .now
        let weekStart = Calendar.current.date(byAdding: .day, value: weekOffset * 7, to: monthStart) ?? monthStart
        return (0..<7).map { dayOffset in
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart
            let duration = sessions
                .filter { Calendar.current.isDate($0.endedAt, inSameDayAs: date) }
                .reduce(0) { $0 + $1.focusedDuration }
            return DayTrendEntry(date: date, duration: duration)
        }
    }

    func routineTrend(isWake: Bool, weekOffset: Int) -> [RoutineTrendPoint] {
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: selectedRoutineMonth)) ?? .now
        let weekStart = Calendar.current.date(byAdding: .day, value: weekOffset * 7, to: monthStart) ?? monthStart
        return (0..<7).compactMap { dayOffset in
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart
            guard let record = sleepWakeRecords.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) else {
                return RoutineTrendPoint(date: date, value: .nan)
            }
            let target = isWake ? record.wakeTime : record.sleepTime
            guard let target else { return RoutineTrendPoint(date: date, value: .nan) }
            let components = Calendar.current.dateComponents([.hour, .minute], from: target)
            let value = Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
            return RoutineTrendPoint(date: date, value: value)
        }
    }

    func previousSleepAndTodayWake() -> (sleep: Date?, wake: Date?) {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        let sleep = sleepWakeRecords.first(where: { Calendar.current.isDate($0.date, inSameDayAs: yesterday) })?.sleepTime
        let wake = sleepWakeRecords.first(where: { Calendar.current.isDateInToday($0.date) })?.wakeTime
        return (sleep, wake)
    }

    func cycleStatisticsMonth(forward: Bool) {
        let candidate = Calendar.current.date(byAdding: .month, value: forward ? 1 : -1, to: selectedStatisticsMonth) ?? selectedStatisticsMonth
        if forward {
            let currentMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
            selectedStatisticsMonth = min(candidate, currentMonth)
        } else {
            selectedStatisticsMonth = candidate
        }
        selectedStatisticsWeekOffset = 0
    }

    func cycleRoutineMonth(forward: Bool) {
        let candidate = Calendar.current.date(byAdding: .month, value: forward ? 1 : -1, to: selectedRoutineMonth) ?? selectedRoutineMonth
        if forward {
            let currentMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
            selectedRoutineMonth = min(candidate, currentMonth)
        } else {
            selectedRoutineMonth = candidate
        }
        selectedRoutineWeekOffset = 0
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

    private func upsertRoutine(for date: Date, isSleep: Bool) {
        let dayStart = Calendar.current.startOfDay(for: date)
        if let index = sleepWakeRecords.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: dayStart) }) {
            if isSleep {
                sleepWakeRecords[index].sleepTime = date
            } else {
                sleepWakeRecords[index].wakeTime = date
            }
        } else {
            sleepWakeRecords.append(SleepWakeRecord(date: dayStart, sleepTime: isSleep ? date : nil, wakeTime: isSleep ? nil : date))
        }
        sleepWakeRecords.sort(by: { $0.date > $1.date })
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
        guard var activeSession else { return }

        // Auto-resume when a bounded pause expires so stopwatch sessions cannot stall forever.
        if activeSession.isPaused, let deadline = activeSession.pauseDeadline, now >= deadline {
            let pausedDuration = deadline.timeIntervalSince(activeSession.pausedAt ?? deadline)
            activeSession.pausedAccumulated += pausedDuration
            activeSession.pausedAt = nil
            activeSession.isPaused = false
            activeSession.pauseDeadline = nil
            self.activeSession = activeSession
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

    private func refreshDerivedState() {
        ScreenAwakeController.update(isEnabled: settings.keepScreenAwake && activeSession != nil)
    }

    private func wirePersistence() {
        Publishers.MergeMany(
            $profile.map { _ in () }.eraseToAnyPublisher(),
            $settings.map { _ in () }.eraseToAnyPublisher(),
            $activeSession.map { _ in () }.eraseToAnyPublisher(),
            $countdownEvents.map { _ in () }.eraseToAnyPublisher(),
            $tasks.map { _ in () }.eraseToAnyPublisher(),
            $sessions.map { _ in () }.eraseToAnyPublisher(),
            $sleepWakeRecords.map { _ in () }.eraseToAnyPublisher(),
            $lastTaskID.map { _ in () }.eraseToAnyPublisher()
        )
        .sink { [weak self] _ in
            self?.persistState()
        }
        .store(in: &cancellables)
    }

    private func restoreReminder() {
        if settings.dailyReminderEnabled {
            notifications.requestAuthorization()
            notifications.scheduleDailyReminder(hour: settings.dailyReminderHour, minute: settings.dailyReminderMinute)
        }
    }

    private func persistState() {
        let snapshot = AppSnapshot(
            tasks: tasks,
            sessions: sessions,
            countdownEvents: countdownEvents,
            profile: profile,
            settings: settings,
            sleepWakeRecords: sleepWakeRecords,
            lastTaskID: lastTaskID,
            activeSession: activeSession
        )
        persistence.save(snapshot)
        if settings.dailyReminderEnabled {
            notifications.requestAuthorization()
            notifications.scheduleDailyReminder(hour: settings.dailyReminderHour, minute: settings.dailyReminderMinute)
        } else {
            notifications.cancelDailyReminder()
        }
        refreshDerivedState()
    }
}
