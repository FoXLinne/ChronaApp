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
                Image(systemName: context.state.compactSystemImage)
                    .font(.caption)
                    .foregroundStyle(context.state.statusColor)
            } compactTrailing: {
                CompactTrailingView(state: context.state)
            } minimal: {
                Image(systemName: context.state.compactSystemImage)
                    .foregroundStyle(context.state.statusColor)
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
            Image(systemName: state.compactSystemImage)
                .font(.title)
                .foregroundStyle(state.statusColor)
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
                    .foregroundStyle(state.statusColor)
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
        Image(systemName: state.compactSystemImage)
            .font(.title2)
            .foregroundStyle(state.statusColor)
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
            .foregroundStyle(state.statusColor)
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
        TimerDisplayView(state: state, font: .system(.caption, design: .rounded).monospacedDigit().weight(.semibold))
            .frame(maxWidth: 46, alignment: .trailing)
            .minimumScaleFactor(0.72)
    }
}

// MARK: - 计时器显示核心组件
//
// 根据 isPaused / isStopwatch 自动选择正确的显示方式：
// - 有时限暂停：按 pauseEndTime 自动倒计时；无时限暂停：显示本地化静态文案
// - 秒表运行中：Text(elapsedReferenceDate, style: .timer) 从过去时间点正向自动计数
// - 倒计时/番茄钟/休息运行中：按 endTime 自动倒计时，到点停在 00:00

private struct TimerDisplayView: View {
    let state: TimerActivityAttributes.ContentState
    let font: Font

    var body: some View {
        Group {
            if state.isPaused {
                if let pauseEndTime = state.pauseEndTime {
                    countdownText(to: pauseEndTime)
                } else {
                    Text(state.pausedTimerText)
                        .font(font)
                }
            } else if state.isStopwatch {
                Text(state.elapsedReferenceDate, style: .timer)
                    .font(font)
            } else if let endTime = state.endTime {
                countdownText(to: endTime)
            } else {
                Text("--:--")
                    .font(font)
            }
        }
        .multilineTextAlignment(.trailing)
        .foregroundStyle(state.statusColor)
        .lineLimit(1)
    }

    @ViewBuilder
    private func countdownText(to endTime: Date) -> some View {
        if endTime <= Date.now {
            Text("00:00")
                .font(font)
        } else {
            Text(timerInterval: Date.now...endTime, countsDown: true)
                .font(font)
        }
    }
}

private extension TimerActivityAttributes.ContentState {
    var compactSystemImage: String {
        if isPaused {
            return "pause.fill"
        }

        if isRest {
            return "cup.and.saucer.fill"
        }

        return modeSystemImage
    }

    var statusColor: Color {
        if isPaused {
            return .secondary
        }

        if isRest {
            return .blue
        }

        return Color("AccentColor")
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
            phaseLabel: String(localized: "la.phase.focus"),
            modeLabel: String(localized: "mode.countdown"),
            modeSystemImage: "clock",
            isPaused: false,
            isRest: false,
            isStopwatch: false
        )
    }

    fileprivate static var previewPaused: TimerActivityAttributes.ContentState {
        .init(
            endTime: Date.now.addingTimeInterval(14 * 60 + 51),
            elapsedReferenceDate: Date.now.addingTimeInterval(-609),
            pausedTimerText: String(localized: "session.pause.indefinite"),
            taskTitle: "Workout",
            phaseLabel: String(localized: "la.paused"),
            modeLabel: String(localized: "mode.countdown"),
            modeSystemImage: "clock",
            isPaused: true,
            isRest: false,
            isStopwatch: false
        )
    }

    fileprivate static var previewStopwatch: TimerActivityAttributes.ContentState {
        .init(
            endTime: nil,
            elapsedReferenceDate: Date.now.addingTimeInterval(-305),
            pausedTimerText: "",
            taskTitle: "Deep Work",
            phaseLabel: String(localized: "la.phase.focus"),
            modeLabel: String(localized: "mode.stopwatch"),
            modeSystemImage: "stopwatch",
            isPaused: false,
            isRest: false,
            isStopwatch: true
        )
    }
}

#Preview("Lock Screen - Countdown", as: .content, using: TimerActivityAttributes.previewFocus) {
    ChronaWidgetLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.previewCountdown
    TimerActivityAttributes.ContentState.previewPaused
}

#Preview("Lock Screen - Stopwatch", as: .content, using: TimerActivityAttributes.previewFocus) {
    ChronaWidgetLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.previewStopwatch
}
