import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Widget 入口

struct ChronaWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            LockScreenBannerView(state: context.state)
                .activityBackgroundTint(.clear)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(state: context.state)
                }
            } compactLeading: {
                Image(systemName: context.state.modeSystemImage)
                    .font(.caption)
                    .foregroundStyle(Color("AccentColor"))
            } compactTrailing: {
                CompactTrailingView(state: context.state)
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : context.state.modeSystemImage)
                    .foregroundStyle(context.state.isPaused ? Color.secondary : Color("AccentColor"))
            }
            .keylineTint(Color("AccentColor"))
        }
    }
}

// MARK: - 锁屏 / 通知横幅

private struct LockScreenBannerView: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            // 模式图标
            Image(systemName: state.modeSystemImage)
                .font(.title)
                .foregroundStyle(Color("AccentColor"))
                .frame(width: 36)

            // 任务信息
            VStack(alignment: .leading, spacing: 4) {
                Text(state.taskTitle)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text(state.modeLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 计时器 + 状态标签
            VStack(alignment: .trailing, spacing: 4) {
                TimerDisplayView(state: state, font: .system(.title, design: .rounded).monospacedDigit().bold())
                Text(state.phaseLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.85))
        .activitySystemActionForegroundColor(.white)
    }
}

// MARK: - 灵动岛展开：左侧

private struct ExpandedLeadingView: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        Image(systemName: state.modeSystemImage)
            .font(.title2)
            .foregroundStyle(Color("AccentColor"))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.leading, 16)
    }
}

// MARK: - 灵动岛展开：右侧

private struct ExpandedTrailingView: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        // 现在这里放状态标签（原本是计时器）
        Text(state.phaseLabel)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(state.isPaused ? Color.secondary : Color("AccentColor"))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(.trailing, 16)
    }
}

// MARK: - 灵动岛展开：底部

private struct ExpandedBottomView: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .bottom) {
            // 左下
            VStack(alignment: .leading, spacing: 4) {
                Text(state.taskTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(state.modeLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // 右下：计时器（统一使用最大的 .largeTitle 字体）
            TimerDisplayView(state: state, font: .system(.largeTitle, design: .rounded).monospacedDigit().bold())
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
}

// MARK: - 灵动岛紧凑：右侧

private struct CompactTrailingView: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        if state.isPaused {
            Image(systemName: "pause.fill")
                .foregroundStyle(.secondary)
        } else {
            TimerDisplayView(state: state, font: .system(.caption, design: .rounded).monospacedDigit().weight(.semibold))
                .frame(maxWidth: 46, alignment: .trailing)
        }
    }
}

// MARK: - 计时器显示核心组件
//
// 根据 isPaused / isStopwatch 自动选择正确的显示方式：
// - 暂停中：显示由主 App 计算并冻结的静态文本（pausedTimerText）
// - 秒表运行中：Text(elapsedReferenceDate, style: .timer) 从过去时间点正向自动计数
// - 倒计时/番茄钟运行中：Text(endTime, style: .timer) 向未来时间点自动倒计

private struct TimerDisplayView: View {
    let state: TimerActivityAttributes.ContentState
    let font: Font

    var body: some View {
        Group {
            if state.isPaused {
                Text(state.pausedTimerText)
                    .font(font)
            } else if state.isStopwatch {
                Text(state.elapsedReferenceDate, style: .timer)
                    .font(font)
            } else if let endTime = state.endTime {
                Text(endTime, style: .timer)
                    .font(font)
            } else {
                Text("--:--")
                    .font(font)
            }
        }
        .multilineTextAlignment(.trailing)
        .foregroundStyle(state.isPaused ? Color.secondary : Color("AccentColor"))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

// MARK: - Preview

extension TimerActivityAttributes {
    fileprivate static var previewFocus: TimerActivityAttributes {
        TimerActivityAttributes(taskID: nil)
    }
}

extension TimerActivityAttributes.ContentState {
    fileprivate static var previewCountdown: TimerActivityAttributes.ContentState {
        .init(
            endTime: Date.now.addingTimeInterval(14 * 60 + 51),
            elapsedReferenceDate: Date.now.addingTimeInterval(-609),
            pausedTimerText: "",
            taskTitle: "Workout",
            phaseLabel: "专注中",
            modeLabel: "倒计时",
            modeSystemImage: "clock",
            isPaused: false,
            isStopwatch: false
        )
    }

    fileprivate static var previewPaused: TimerActivityAttributes.ContentState {
        .init(
            endTime: Date.now.addingTimeInterval(14 * 60 + 51),
            elapsedReferenceDate: Date.now.addingTimeInterval(-609),
            pausedTimerText: "14:51",
            taskTitle: "Workout",
            phaseLabel: "已暂停",
            modeLabel: "倒计时",
            modeSystemImage: "clock",
            isPaused: true,
            isStopwatch: false
        )
    }

    fileprivate static var previewStopwatch: TimerActivityAttributes.ContentState {
        .init(
            endTime: nil,
            elapsedReferenceDate: Date.now.addingTimeInterval(-305),
            pausedTimerText: "",
            taskTitle: "Deep Work",
            phaseLabel: "专注中",
            modeLabel: "秒表",
            modeSystemImage: "stopwatch",
            isPaused: false,
            isStopwatch: true
        )
    }
}

#Preview("锁屏 – 倒计时", as: .content, using: TimerActivityAttributes.previewFocus) {
    ChronaWidgetLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.previewCountdown
    TimerActivityAttributes.ContentState.previewPaused
}

#Preview("锁屏 – 秒表", as: .content, using: TimerActivityAttributes.previewFocus) {
    ChronaWidgetLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.previewStopwatch
}
