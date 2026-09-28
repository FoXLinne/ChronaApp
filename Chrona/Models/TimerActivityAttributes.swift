import ActivityKit
import Foundation

/// 灵动岛 / 实时活动的属性与状态模型
/// 此文件需同时加入主 App Target 和 ChronaWidget Target 的 Target Membership
nonisolated struct TimerActivityAttributes: ActivityAttributes {

    // MARK: - 静态属性（会话创建时固定）
    var taskID: UUID?

    // MARK: - 动态内容状态（每次 syncLiveActivity 推送）
    public nonisolated struct ContentState: Codable, Hashable {

        /// 倒计时 / 番茄钟：会话结束的未来时间点，供 Text(.., style: .timer) 自动倒计
        /// 秒表模式时为 nil
        var endTime: Date?

        /// 秒表模式：会话有效开始的过去时间点 = Date.now - elapsed
        /// 供 Text(.., style: .timer) 自动正向计数；倒计时模式下也写入但不使用
        var elapsedReferenceDate: Date

        /// 暂停时的冻结显示文本（由主 App 格式化后写入）
        /// 无时限暂停显示本地化静态文案，未暂停时为空字符串。
        var pausedTimerText: String

        /// 有时限暂停的结束时间点，供 Widget 在后台自动倒计时。
        var pauseEndTime: Date?

        /// 任务名称
        var taskTitle: String

        /// 阶段标签（主 App 预本地化写入）
        /// 例：「专注中」「休息中」「已暂停」
        var phaseLabel: String

        /// 模式标签（主 App 预本地化写入）
        /// 例：「番茄钟」「倒计时」「秒表」
        var modeLabel: String

        /// 模式 SF Symbol 名称
        var modeSystemImage: String

        /// 当前是否处于暂停状态
        var isPaused: Bool

        /// 当前是否处于休息阶段
        var isRest: Bool

        /// 是否为秒表模式（决定使用 elapsedReferenceDate 还是 endTime 渲染计时器）
        var isStopwatch: Bool

        init(
            endTime: Date?,
            elapsedReferenceDate: Date,
            pausedTimerText: String,
            pauseEndTime: Date? = nil,
            taskTitle: String,
            phaseLabel: String,
            modeLabel: String,
            modeSystemImage: String,
            isPaused: Bool,
            isRest: Bool = false,
            isStopwatch: Bool
        ) {
            self.endTime = endTime
            self.elapsedReferenceDate = elapsedReferenceDate
            self.pausedTimerText = pausedTimerText
            self.pauseEndTime = pauseEndTime
            self.taskTitle = taskTitle
            self.phaseLabel = phaseLabel
            self.modeLabel = modeLabel
            self.modeSystemImage = modeSystemImage
            self.isPaused = isPaused
            self.isRest = isRest
            self.isStopwatch = isStopwatch
        }

        // MARK: - 编码键（确保新增字段不影响旧数据解码）

        private enum CodingKeys: String, CodingKey {
            case endTime
            case elapsedReferenceDate
            case pausedTimerText
            case pauseEndTime
            case taskTitle
            case phaseLabel
            case modeLabel
            case modeSystemImage
            case isPaused
            case isRest
            case isStopwatch
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
            elapsedReferenceDate = try container.decode(Date.self, forKey: .elapsedReferenceDate)
            pausedTimerText = try container.decode(String.self, forKey: .pausedTimerText)
            pauseEndTime = try container.decodeIfPresent(Date.self, forKey: .pauseEndTime)
            taskTitle = try container.decode(String.self, forKey: .taskTitle)
            phaseLabel = try container.decode(String.self, forKey: .phaseLabel)
            modeLabel = try container.decode(String.self, forKey: .modeLabel)
            modeSystemImage = try container.decode(String.self, forKey: .modeSystemImage)
            isPaused = try container.decode(Bool.self, forKey: .isPaused)
            isRest = try container.decodeIfPresent(Bool.self, forKey: .isRest) ?? false
            isStopwatch = try container.decode(Bool.self, forKey: .isStopwatch)
        }
    }
}
