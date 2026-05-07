import Foundation

/// 专注会话生命周期管理：开始、暂停、恢复、结束、休息转换。
/// 纯逻辑层，不持有 @Published 状态；所有数据由调用方（AppViewModel）传入和回写。
@MainActor
enum SessionManager {

    // MARK: - 开始专注

    /// 尝试开始一个新专注会话。返回新的 snapshot 和是否成功的标志。
    static func startTask(
        _ task: TaskItem,
        activeSession: ActiveSessionSnapshot?,
        now: Date
    ) -> ActiveSessionSnapshot? {
        guard activeSession == nil else { return nil }

        let focusDuration: TimeInterval?
        switch task.mode {
        case .pomodoro:
            focusDuration = task.pomodoroPreset.workDuration
        case .countdown:
            focusDuration = task.countdownDuration
        case .stopwatch:
            focusDuration = nil
        }

        return ActiveSessionSnapshot(
            taskID: task.id,
            taskTitle: task.title,
            mode: task.mode,
            phase: .focus,
            startedAt: now,
            focusDuration: focusDuration,
            restDuration: nil,
            pausedAt: nil,
            pausedAccumulated: 0,
            isPaused: false,
            pauseDeadline: nil
        )
    }

    // MARK: - 停止后果预判

    /// 预判停止当前专注的后果（正常记录 / 丢弃过短 / 丢弃高级规则）。
    static func stopConsequence(
        activeSession: ActiveSessionSnapshot?,
        now: Date,
        advancedDisallowEarlyFinish: Bool
    ) -> StopConsequence {
        guard let session = activeSession, session.phase == .focus else {
            return .willRecord
        }

        let status = TimerEngine.status(for: session, now: now)
        let focusDuration = status.elapsed
        guard focusDuration >= 5 else {
            return .discardTooShort
        }

        let reachedTarget = session.focusDuration.map { focusDuration >= $0 } ?? true
        let isCompleted = !advancedDisallowEarlyFinish || reachedTarget
        let shouldAbandon = advancedDisallowEarlyFinish && !isCompleted
        return shouldAbandon ? .discardAdvancedRule : .willRecord
    }

    // MARK: - 暂停 / 恢复

    /// 切换暂停状态。返回更新后的 snapshot，以及通知提示文案（nil 表示无需提示）。
    static func togglePause(
        activeSession: ActiveSessionSnapshot?,
        settings: AppSettings,
        selectedTab: AppTab,
        now: Date
    ) -> (snapshot: ActiveSessionSnapshot?, notice: String?, resetImmersiveClock: Bool) {
        guard var session = activeSession else { return (nil, nil, false) }
        guard session.phase == .focus, session.mode != .pomodoro else { return (session, nil, false) }
        guard !settings.advancedDisallowPause else { return (session, nil, false) }

        if session.isPaused {
            let resumeMoment = min(now, session.pauseDeadline ?? now)
            let pausedDuration = resumeMoment.timeIntervalSince(session.pausedAt ?? resumeMoment)
            session.pausedAccumulated += pausedDuration
            session.pausedAt = nil
            session.isPaused = false
            session.pauseDeadline = nil
            return (session, String(localized: "session.pause.resumed"), selectedTab == .active)
        } else {
            session.isPaused = true
            session.pausedAt = now
            if let limit = settings.stopwatchPauseLimitMinutes {
                session.pauseDeadline = Calendar.current.date(byAdding: .minute, value: limit, to: now)
                let notice = String(format: String(localized: "session.pause.entered.limit"), limit)
                return (session, notice, false)
            } else {
                return (session, String(localized: "session.pause.entered"), false)
            }
        }
    }

    // MARK: - 停止专注

    /// 停止当前专注会话的结果。
    struct StopResult {
        var recordedSession: FocusSessionRecord?
        var shouldBeginRest: Bool
        var notice: String?
    }

    static func stopActiveSession(
        activeSession: ActiveSessionSnapshot?,
        now: Date,
        settings: AppSettings,
        autoMoveCompletedTaskToTop: Bool
    ) -> StopResult {
        guard let session = activeSession else {
            return StopResult(recordedSession: nil, shouldBeginRest: false, notice: nil)
        }

        let status = TimerEngine.status(for: session, now: now)
        let focusDuration = session.phase == .focus ? status.elapsed : 0
        let isQualified = focusDuration >= 5
        let reachedTarget = session.phase == .focus && (session.focusDuration.map { focusDuration >= $0 } ?? isQualified)
        let isCompleted = session.phase == .focus && isQualified && (!settings.advancedDisallowEarlyFinish || reachedTarget)
        let isAbandoned = settings.advancedDisallowEarlyFinish && !isCompleted

        var notice: String?
        if session.phase == .focus, !isQualified {
            notice = String(format: String(localized: "session.discard.short"), Int(focusDuration.rounded()))
        } else if session.phase == .focus, isAbandoned {
            notice = String(localized: "session.discard.advanced")
        }

        var record: FocusSessionRecord?
        if session.phase == .focus, isQualified, !isAbandoned {
            let recordedDuration = min(focusDuration, session.focusDuration ?? focusDuration)
            record = makeRecord(session: session, duration: recordedDuration, completed: isCompleted, now: now, settings: settings)
        }

        let shouldBeginRest = session.phase == .focus
        return StopResult(
            recordedSession: record,
            shouldBeginRest: shouldBeginRest,
            notice: notice
        )
    }

    // MARK: - 结束休息

    static func endRest() -> ActiveSessionSnapshot? {
        return nil
    }

    // MARK: - 自动恢复超时暂停

    /// 如果暂停超过时限则自动恢复。返回更新后的 snapshot、是否触发了自动恢复、提示文案。
    static func autoResumeFromPauseLimit(
        activeSession: ActiveSessionSnapshot?,
        now: Date,
        selectedTab: AppTab
    ) -> (snapshot: ActiveSessionSnapshot?, didResume: Bool, notice: String?, resetImmersiveClock: Bool) {
        guard var session = activeSession,
              session.mode != .pomodoro,
              session.isPaused,
              let deadline = session.pauseDeadline,
              now >= deadline
        else {
            return (activeSession, false, nil, false)
        }

        let pausedDuration = deadline.timeIntervalSince(session.pausedAt ?? deadline)
        session.pausedAccumulated += pausedDuration
        session.pausedAt = nil
        session.isPaused = false
        session.pauseDeadline = nil

        let resetClock = selectedTab == .active
        return (session, true, String(localized: "session.pause.autoResumed"), resetClock)
    }

    // MARK: - 休息时长计算

    /// 计算休息时长（秒），返回 nil 表示不需要休息。
    static func restDuration(
        after session: ActiveSessionSnapshot,
        activeTask: TaskItem?,
        restDurationMinutes: Int
    ) -> TimeInterval? {
        if session.mode == .pomodoro, let task = activeTask {
            return task.pomodoroPreset.breakDuration
        }
        guard restDurationMinutes > 0 else { return nil }
        return Double(restDurationMinutes * 60)
    }

    /// 构建休息阶段的 snapshot。
    static func makeRestSnapshot(after session: ActiveSessionSnapshot, restDuration: TimeInterval) -> ActiveSessionSnapshot {
        ActiveSessionSnapshot(
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

    // MARK: - 计时器 Tick 处理

    struct TickResult {
        var newActiveSession: ActiveSessionSnapshot?
        var stopResult: StopResult?
        var shouldEndRest: Bool
        var autoResumeNotice: String?
    }

    static func handleTimerTick(
        activeSession: ActiveSessionSnapshot?,
        now: Date,
        settings: AppSettings,
        selectedTab: AppTab
    ) -> TickResult {
        guard activeSession != nil else {
            return TickResult(newActiveSession: activeSession, stopResult: nil, shouldEndRest: false, autoResumeNotice: nil)
        }

        // 先处理暂停超时自动恢复
        let resumeResult = autoResumeFromPauseLimit(activeSession: activeSession, now: now, selectedTab: selectedTab)
        let session = resumeResult.snapshot

        guard let session else {
            return TickResult(newActiveSession: nil, stopResult: nil, shouldEndRest: false, autoResumeNotice: resumeResult.notice)
        }

        if session.isPaused {
            return TickResult(newActiveSession: session, stopResult: nil, shouldEndRest: false, autoResumeNotice: resumeResult.notice)
        }

        let status = TimerEngine.status(for: session, now: now)
        guard status.isFinished else {
            return TickResult(newActiveSession: session, stopResult: nil, shouldEndRest: false, autoResumeNotice: resumeResult.notice)
        }

        if session.phase == .focus {
            let stopResult = stopActiveSession(activeSession: session, now: now, settings: settings, autoMoveCompletedTaskToTop: false)
            return TickResult(newActiveSession: nil, stopResult: stopResult, shouldEndRest: false, autoResumeNotice: resumeResult.notice)
        } else {
            return TickResult(newActiveSession: nil, stopResult: nil, shouldEndRest: true, autoResumeNotice: resumeResult.notice)
        }
    }

    // MARK: - 前后台切换时校验

    static func reconcile(
        activeSession: ActiveSessionSnapshot?,
        now: Date,
        settings: AppSettings,
        selectedTab: AppTab
    ) -> TickResult {
        guard activeSession != nil else {
            return TickResult(newActiveSession: nil, stopResult: nil, shouldEndRest: false, autoResumeNotice: nil)
        }

        let resumeResult = autoResumeFromPauseLimit(activeSession: activeSession, now: now, selectedTab: selectedTab)
        let session = resumeResult.snapshot

        guard let session else {
            return TickResult(newActiveSession: nil, stopResult: nil, shouldEndRest: false, autoResumeNotice: resumeResult.notice)
        }

        if session.isPaused {
            return TickResult(newActiveSession: session, stopResult: nil, shouldEndRest: false, autoResumeNotice: resumeResult.notice)
        }

        let status = TimerEngine.status(for: session, now: now)
        guard status.isFinished else {
            return TickResult(newActiveSession: session, stopResult: nil, shouldEndRest: false, autoResumeNotice: resumeResult.notice)
        }

        if session.phase == .focus {
            let stopResult = stopActiveSession(activeSession: session, now: now, settings: settings, autoMoveCompletedTaskToTop: false)
            return TickResult(newActiveSession: nil, stopResult: stopResult, shouldEndRest: false, autoResumeNotice: resumeResult.notice)
        } else {
            return TickResult(newActiveSession: nil, stopResult: nil, shouldEndRest: true, autoResumeNotice: resumeResult.notice)
        }
    }

    // MARK: - 重复记录检查

    static func hasRecordedSession(
        sessions: [FocusSessionRecord],
        session: ActiveSessionSnapshot,
        duration: TimeInterval,
        completed: Bool
    ) -> Bool {
        sessions.contains {
            $0.taskID == session.taskID &&
            $0.mode == session.mode &&
            $0.taskTitle == session.taskTitle &&
            abs($0.startedAt.timeIntervalSince(session.startedAt)) < 1 &&
            abs($0.focusedDuration - duration) < 1 &&
            $0.wasCompleted == completed
        }
    }

    // MARK: - 私有工具

    private static func makeRecord(
        session: ActiveSessionSnapshot,
        duration: TimeInterval,
        completed: Bool,
        now: Date,
        settings: AppSettings
    ) -> FocusSessionRecord {
        FocusSessionRecord(
            taskID: session.taskID,
            taskTitle: session.taskTitle,
            mode: session.mode,
            startedAt: session.startedAt,
            endedAt: now,
            focusedDuration: duration,
            wasCompleted: completed,
            wasAbandoned: !completed && settings.advancedDisallowEarlyFinish
        )
    }
}
