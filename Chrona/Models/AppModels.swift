import Foundation

enum FocusMode: String, Codable, CaseIterable, Identifiable {
    case pomodoro
    case stopwatch
    case countdown

    var id: String { rawValue }
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

enum AppTab: Hashable {
    case active
    case tasks
    case statistics
    case countdown
    case profile
}

enum SessionPhase: String, Codable {
    case focus
    case rest
}

struct PomodoroPreset: Codable, Hashable, Identifiable {
    let id: String
    let workDuration: TimeInterval
    let breakDuration: TimeInterval

    static let preset25 = PomodoroPreset(id: "25-5", workDuration: 25 * 60, breakDuration: 5 * 60)
    static let preset50 = PomodoroPreset(id: "50-10", workDuration: 50 * 60, breakDuration: 10 * 60)

    static let `default` = preset25
    static let all: [PomodoroPreset] = [.preset25, .preset50]
}

struct TaskItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var mode: FocusMode
    var pomodoroPresetID: String
    var countdownDuration: TimeInterval
    var backgroundName: String
    var order: Int

    init(
        id: UUID = UUID(),
        title: String,
        mode: FocusMode,
        pomodoroPresetID: String = PomodoroPreset.default.id,
        countdownDuration: TimeInterval = 5 * 60,
        backgroundName: String = "sunset",
        order: Int
    ) {
        self.id = id
        self.title = title
        self.mode = mode
        self.pomodoroPresetID = pomodoroPresetID
        self.countdownDuration = countdownDuration
        self.backgroundName = backgroundName
        self.order = order
    }

    var pomodoroPreset: PomodoroPreset {
        PomodoroPreset.all.first(where: { $0.id == pomodoroPresetID }) ?? .default
    }
}

struct FocusSessionRecord: Identifiable, Codable {
    var id: UUID
    var taskID: UUID?
    var taskTitle: String
    var mode: FocusMode
    var startedAt: Date
    var endedAt: Date
    var focusedDuration: TimeInterval
    var wasCompleted: Bool
    var wasAbandoned: Bool

    init(
        id: UUID = UUID(),
        taskID: UUID?,
        taskTitle: String,
        mode: FocusMode,
        startedAt: Date,
        endedAt: Date,
        focusedDuration: TimeInterval,
        wasCompleted: Bool,
        wasAbandoned: Bool
    ) {
        self.id = id
        self.taskID = taskID
        self.taskTitle = taskTitle
        self.mode = mode
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.focusedDuration = focusedDuration
        self.wasCompleted = wasCompleted
        self.wasAbandoned = wasAbandoned
    }
}

struct CountdownEvent: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var date: Date

    init(id: UUID = UUID(), title: String, date: Date) {
        self.id = id
        self.title = title
        self.date = date
    }
}

struct ProfileInfo: Codable, Equatable {
    var name: String
    var avatarSymbol: String
    var avatarImageData: Data?
    var signature: String

    static let `default` = ProfileInfo(name: "Chrona", avatarSymbol: "person.crop.circle.fill", avatarImageData: nil, signature: "Stay focused.")
}

struct AppSettings: Codable, Equatable {
    var autoMoveCompletedTaskToTop: Bool
    var strikethroughCompletedTask: Bool
    var enableMinimalBlackMode: Bool
    var keepScreenAwake: Bool
    var restDurationMinutes: Int
    var theme: AppTheme
    var liveActivitiesEnabled: Bool
    var dailyReminderEnabled: Bool
    var dailyReminderHour: Int
    var dailyReminderMinute: Int
    var advancedDisallowPause: Bool
    var advancedDisallowEarlyFinish: Bool
    var stopwatchPauseLimitMinutes: Int?
    var minimalModeActivationDelaySeconds: Int
    var showStatusBarOverlay: Bool

    static let `default` = AppSettings(
        autoMoveCompletedTaskToTop: false,
        strikethroughCompletedTask: true,
        enableMinimalBlackMode: true,
        keepScreenAwake: true,
        restDurationMinutes: 5,
        theme: .system,
        liveActivitiesEnabled: true,
        dailyReminderEnabled: false,
        dailyReminderHour: 20,
        dailyReminderMinute: 0,
        advancedDisallowPause: false,
        advancedDisallowEarlyFinish: false,
        stopwatchPauseLimitMinutes: nil,
        minimalModeActivationDelaySeconds: 5,
        showStatusBarOverlay: true
    )

    init(
        autoMoveCompletedTaskToTop: Bool = false,
        strikethroughCompletedTask: Bool = true,
        enableMinimalBlackMode: Bool = true,
        keepScreenAwake: Bool = true,
        restDurationMinutes: Int = 5,
        theme: AppTheme = .system,
        liveActivitiesEnabled: Bool = true,
        dailyReminderEnabled: Bool = false,
        dailyReminderHour: Int = 20,
        dailyReminderMinute: Int = 0,
        advancedDisallowPause: Bool = false,
        advancedDisallowEarlyFinish: Bool = false,
        stopwatchPauseLimitMinutes: Int? = nil,
        minimalModeActivationDelaySeconds: Int = 5,
        showStatusBarOverlay: Bool = true
    ) {
        self.autoMoveCompletedTaskToTop = autoMoveCompletedTaskToTop
        self.strikethroughCompletedTask = strikethroughCompletedTask
        self.enableMinimalBlackMode = enableMinimalBlackMode
        self.keepScreenAwake = keepScreenAwake
        self.restDurationMinutes = restDurationMinutes
        self.theme = theme
        self.liveActivitiesEnabled = liveActivitiesEnabled
        self.dailyReminderEnabled = dailyReminderEnabled
        self.dailyReminderHour = dailyReminderHour
        self.dailyReminderMinute = dailyReminderMinute
        self.advancedDisallowPause = advancedDisallowPause
        self.advancedDisallowEarlyFinish = advancedDisallowEarlyFinish
        self.stopwatchPauseLimitMinutes = stopwatchPauseLimitMinutes
        self.minimalModeActivationDelaySeconds = minimalModeActivationDelaySeconds
        self.showStatusBarOverlay = showStatusBarOverlay
    }

    /// 容错解码：缺失的字段使用默认值，保证新旧版本数据兼容
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        autoMoveCompletedTaskToTop = try c.decodeIfPresent(Bool.self, forKey: .autoMoveCompletedTaskToTop) ?? false
        strikethroughCompletedTask = try c.decodeIfPresent(Bool.self, forKey: .strikethroughCompletedTask) ?? true
        enableMinimalBlackMode = try c.decodeIfPresent(Bool.self, forKey: .enableMinimalBlackMode) ?? true
        keepScreenAwake = try c.decodeIfPresent(Bool.self, forKey: .keepScreenAwake) ?? true
        restDurationMinutes = try c.decodeIfPresent(Int.self, forKey: .restDurationMinutes) ?? 5
        theme = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
        liveActivitiesEnabled = try c.decodeIfPresent(Bool.self, forKey: .liveActivitiesEnabled) ?? true
        dailyReminderEnabled = try c.decodeIfPresent(Bool.self, forKey: .dailyReminderEnabled) ?? false
        dailyReminderHour = try c.decodeIfPresent(Int.self, forKey: .dailyReminderHour) ?? 20
        dailyReminderMinute = try c.decodeIfPresent(Int.self, forKey: .dailyReminderMinute) ?? 0
        advancedDisallowPause = try c.decodeIfPresent(Bool.self, forKey: .advancedDisallowPause) ?? false
        advancedDisallowEarlyFinish = try c.decodeIfPresent(Bool.self, forKey: .advancedDisallowEarlyFinish) ?? false
        stopwatchPauseLimitMinutes = try c.decodeIfPresent(Int.self, forKey: .stopwatchPauseLimitMinutes)
        minimalModeActivationDelaySeconds = try c.decodeIfPresent(Int.self, forKey: .minimalModeActivationDelaySeconds) ?? 5
        showStatusBarOverlay = try c.decodeIfPresent(Bool.self, forKey: .showStatusBarOverlay) ?? true
    }
}

// MARK: - 持久化存储结构

enum StorageSchemaVersion {
    static let current = 1
}

enum ExportFormatVersion {
    static let current = 1
}

/// 用户数据文件 (chrona_data.json)
struct DataStore: Codable {
    var version: Int
    var tasks: [TaskItem]
    var sessions: [FocusSessionRecord]
    var countdownEvents: [CountdownEvent]
    var profile: ProfileInfo
    var checkInDates: [Date]?
    var lastTaskID: UUID?
    var activeSession: ActiveSessionSnapshot?

    static let `default` = DataStore(
        version: StorageSchemaVersion.current,
        tasks: [
            TaskItem(title: "Deep Work", mode: .pomodoro, order: 0),
            TaskItem(title: "Reading", mode: .stopwatch, backgroundName: "forest", order: 1),
            TaskItem(title: "Workout", mode: .countdown, countdownDuration: 15 * 60, backgroundName: "ocean", order: 2)
        ],
        sessions: [],
        countdownEvents: [],
        profile: .default,
        checkInDates: [],
        lastTaskID: nil,
        activeSession: nil
    )
}

/// 设置文件 (chrona_settings.json)
struct SettingsStore: Codable {
    var version: Int
    var settings: AppSettings
}

/// 导出文件格式 — 只备份长期数据，不保存正在运行的计时会话。
struct ChronaExportFile: Codable {
    let formatVersion: Int
    let exportedAt: Date
    var tasks: [TaskItem]
    var sessions: [FocusSessionRecord]
    var countdownEvents: [CountdownEvent]
    var profile: ProfileInfo
    var settings: AppSettings
    var checkInDates: [Date]?
    var lastTaskID: UUID?
    /// 备份内容签名；用于发现新版导出文件被手工修改或传输损坏。
    var signature: String?
}

struct ActiveSessionSnapshot: Codable {
    var taskID: UUID?
    var taskTitle: String
    var mode: FocusMode
    var phase: SessionPhase
    var startedAt: Date
    var focusDuration: TimeInterval?
    var restDuration: TimeInterval?
    var pausedAt: Date?
    var pausedAccumulated: TimeInterval
    var isPaused: Bool
    var pauseDeadline: Date?
}

struct AppSnapshot: Codable {
    var tasks: [TaskItem]
    var sessions: [FocusSessionRecord]
    var countdownEvents: [CountdownEvent]
    var profile: ProfileInfo
    var settings: AppSettings
    var checkInDates: [Date]?
    var lastTaskID: UUID?
    var activeSession: ActiveSessionSnapshot?

    static let `default` = AppSnapshot(
        tasks: [
            TaskItem(title: "Deep Work", mode: .pomodoro, order: 0),
            TaskItem(
                title: "Reading",
                mode: .stopwatch,
                backgroundName: "forest",
                order: 1
            ),
            TaskItem(title: "Workout", mode: .countdown, countdownDuration: 15 * 60, backgroundName: "ocean", order: 2)
        ],
        sessions: [],
        countdownEvents: [
            CountdownEvent(title: "WWDC", date: Calendar.current.date(byAdding: .day, value: 48, to: .now) ?? .now),
            CountdownEvent(title: "Project Launch", date: Calendar.current.date(byAdding: .day, value: -12, to: .now) ?? .now)
        ],
        profile: .default,
        settings: .default,
        checkInDates: [],
        lastTaskID: nil,
        activeSession: nil
    )
}

enum TimeRange: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }
}

struct TaskDistributionEntry: Identifiable {
    var id: UUID
    var taskTitle: String
    var duration: TimeInterval
    var colorSeed: String
}

enum StopConsequence {
     case willRecord
     case discardTooShort
     case discardAdvancedRule
}

struct DayTrendEntry: Identifiable {
    var id: UUID = UUID()
    var date: Date
    var duration: TimeInterval
}

struct RoutineTrendPoint: Identifiable {
    var id: UUID = UUID()
    var date: Date
    var value: Double
}
