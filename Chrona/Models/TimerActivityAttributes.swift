import ActivityKit
import Foundation

/// 灵动岛 / 实时活动的属性与状态模型
/// 此文件需同时加入主 App Target 和 ChronaWidget Target 的 Target Membership
struct TimerActivityAttributes: ActivityAttributes {

    // MARK: - 静态属性（会话创建时固定）
    var taskID: UUID?

    // MARK: - 动态内容状态（每次 syncLiveActivity 推送）
    public struct ContentState: Codable, Hashable {

        /// 倒计时 / 番茄钟：会话结束的未来时间点，供 Text(.., style: .timer) 自动倒计
        /// 秒表模式时为 nil
        var endTime: Date?

        /// 秒表模式：会话有效开始的过去时间点 = Date.now - elapsed
        /// 供 Text(.., style: .timer) 自动正向计数；倒计时模式下也写入但不使用
        var elapsedReferenceDate: Date

        /// 暂停时的冻结显示文本（由主 App 格式化后写入）
        /// 秒表：已计时长；倒计时/番茄钟：剩余时长
        /// 未暂停时为空字符串
        var pausedTimerText: String

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

        /// 是否为秒表模式（决定使用 elapsedReferenceDate 还是 endTime 渲染计时器）
        var isStopwatch: Bool
    }
}