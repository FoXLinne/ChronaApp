import SwiftUI

/// 专注热力图组件，供签到页和统计页共用。
/// - showCheckInMarks: 是否在格子右下角显示签到绿点（统计页关掉即可）
/// - headerTotalDuration: 统计页传入，在左上角显示"本月共专注"大字样式；签到页传 nil 不显示
struct FocusHeatmapView: View {
    @Binding var month: Date
    let durations: [Date: TimeInterval]
    let checkInDates: [Date]
    let showCheckInMarks: Bool
    let headerTotalDuration: TimeInterval?
    @Environment(\.colorScheme) private var colorScheme
    @State private var displayedGridHeight: CGFloat?

    var body: some View {
        VStack(spacing: 10) {
            monthNavigation

            calendarGrid
                .padding(.top, 6)
                .fixedSize(horizontal: false, vertical: true)
                .transaction { $0.animation = nil }
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: HeatmapGridHeightKey.self, value: geometry.size.height)
                    }
                }
                .frame(height: displayedGridHeight, alignment: .top)
                .clipped()
                .onPreferenceChange(HeatmapGridHeightKey.self) { height in
                    guard height > 0, displayedGridHeight != height else { return }
                    if displayedGridHeight == nil {
                        displayedGridHeight = height
                    } else {
                        // 网格顶部固定，卡片下沿跟随实际行数伸缩。
                        withAnimation(.easeInOut(duration: 0.24)) {
                            displayedGridHeight = height
                        }
                    }
                }

            heatmapLegend
        }
    }

    init(
        month: Binding<Date>,
        durations: [Date: TimeInterval],
        checkInDates: [Date],
        showCheckInMarks: Bool,
        headerTotalDuration: TimeInterval? = nil
    ) {
        _month = month
        self.durations = durations
        self.checkInDates = checkInDates
        self.showCheckInMarks = showCheckInMarks
        self.headerTotalDuration = headerTotalDuration
    }

    private var isCurrentMonth: Bool {
        startOfMonth(for: month) >= startOfMonth(for: .now)
    }

    private func moveMonth(by offset: Int) {
        let calendar = Calendar.current
        let currentMonth = startOfMonth(for: .now)
        guard let candidate = calendar.date(byAdding: .month, value: offset, to: startOfMonth(for: month)) else {
            return
        }
        let target = min(candidate, currentMonth)
        month = target
    }

    private func startOfMonth(for date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }

    private func weekRowCount(for date: Date) -> Int {
        let calendar = Calendar.current
        let start = startOfMonth(for: date)
        let days = calendar.range(of: .day, in: .month, for: start)?.count ?? 1
        let leading = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        return (leading + days + 6) / 7
    }
}

private struct HeatmapGridHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Month Navigation
private extension FocusHeatmapView {
    var monthNavigation: some View {
        Group {
            if headerTotalDuration != nil {
                statisticsNavigation
            } else {
                checkInNavigation
            }
        }
        .padding(.horizontal, 2)
    }

    /// 统计页：左侧大字概要，右侧月份导航
    var statisticsNavigation: some View {
        HStack(alignment: .center, spacing: 4) {
            heatmapSummaryView(duration: headerTotalDuration!)

            Spacer(minLength: 4)

            Button { moveMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            monthTitle

            Button { moveMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .disabled(isCurrentMonth)
            .opacity(isCurrentMonth ? 0.35 : 1)
        }
    }

    /// 签到页：居中撑开的导航，没有左侧概要
    var checkInNavigation: some View {
        HStack {
            Button { moveMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Spacer()

            monthTitle

            Spacer()

            Button { moveMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .disabled(isCurrentMonth)
            .opacity(isCurrentMonth ? 0.35 : 1)
        }
    }

    var monthTitle: some View {
        Text(month.formatted(.dateTime.year().month(.wide)))
            .font(.title3.weight(.semibold))
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.easeInOut(duration: 0.24), value: month)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: 112)
    }

    func heatmapSummaryView(duration: TimeInterval) -> some View {
        let total = max(0, Int(duration.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60

        return VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: "stats.focusHeatmap.monthTotal"))
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: "\(hours)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(hours)))
                    .animation(.easeInOut(duration: 0.24), value: hours)
                Text(String(localized: "time.hours"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: "\(minutes)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(minutes)))
                    .animation(.easeInOut(duration: 0.24), value: minutes)
                Text(String(localized: "time.minutes"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Calendar Grid
private extension FocusHeatmapView {
    var weekdayHeaders: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    var calendarGrid: some View {
        let calendar = Calendar.current
        let checkInDays = showCheckInMarks ? Set(checkInDates.map(calendar.startOfDay(for:))) : []
        let headers = weekdayHeaders
        let days = calendarDays
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
            spacing: 2
        ) {
            // 标题和日期共用七列，数字与星期落在同一列中心。
            ForEach(headers.indices, id: \.self) { index in
                Text(headers[index])
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
            }

            ForEach(days.indices, id: \.self) { index in
                if let date = days[index] {
                    let duration = durations[date] ?? 0
                    let isToday = calendar.isDateInToday(date)

                    dayCell(date: date, duration: duration, isToday: isToday, hasCheckIn: checkInDays.contains(date))
                } else {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
        .padding(.horizontal, 6)
    }

    var calendarDays: [Date?] {
        let calendar = Calendar.current
        let monthStart = startOfMonth(for: month)
        let range = calendar.range(of: .day, in: .month, for: month) ?? 1..<2

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingPadding = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingPadding)

        for day in 1...range.count {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: monthStart))
        }

        // 按月份实际周数补齐末行，网格高度随四、五或六周变化。
        days += Array(repeating: nil, count: weekRowCount(for: month) * 7 - days.count)

        return days
    }

    func dayCell(date: Date, duration: TimeInterval, isToday: Bool, hasCheckIn: Bool) -> some View {
        let day = Calendar.current.component(.day, from: date)
        return ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(heatmapColor(for: duration))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isToday ? Color.secondary : Color.clear, lineWidth: 2)
                )

            Text("\(day)")
                .font(.system(size: 12, weight: isToday ? .semibold : .regular))
                .foregroundStyle(duration > 0 ? .primary : .secondary)
                .contentTransition(.numericText(value: Double(day)))
                .animation(.easeInOut(duration: 0.24), value: day)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if hasCheckIn {
                Circle()
                    .fill(.white)
                    .frame(width: 7, height: 7)
                    .overlay(
                        Circle()
                            .fill(.green)
                            .frame(width: 5, height: 5)
                    )
                    .padding(3)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Heatmap Legend
private extension FocusHeatmapView {
    var heatmapLegend: some View {
        HStack(spacing: 6) {
            Text(String(localized: "checkin.heatmap.legend.none"))
                .font(.caption2)
                .foregroundStyle(.secondary)

            legendSwatch(color: heatmapColor(for: 0))
            legendSwatch(color: heatmapColor(for: 30 * 60))
            legendSwatch(color: heatmapColor(for: TimeInterval(1.5 * 3600)))
            legendSwatch(color: heatmapColor(for: TimeInterval(2.5 * 3600)))
            legendSwatch(color: heatmapColor(for: 4 * 3600))
            legendSwatch(color: heatmapColor(for: 6 * 3600))

            Text(String(localized: "checkin.heatmap.legend.long"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    func legendSwatch(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(.secondary.opacity(0.2), lineWidth: 0.5)
            )
            .frame(width: 16, height: 12)
    }

    func heatmapColor(for duration: TimeInterval) -> Color {
        guard duration > 0 else {
            return Color(uiColor: .secondarySystemGroupedBackground)
        }
        let hours = duration / 3600
        switch hours {
        case 0..<1:  return Color.accentColor.opacity(0.15)
        case 1..<2:  return Color.accentColor.opacity(0.30)
        case 2..<3:  return Color.accentColor.opacity(0.50)
        case 3..<5:  return Color.accentColor.opacity(0.72)
        default:      return Color.accentColor
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    var durations: [Date: TimeInterval] = [:]
    for i in 0..<7 {
        guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
        durations[date] = TimeInterval((7 - i) * 15 * 60)
    }

    return List {
        Section {
            FocusHeatmapView(
                month: .constant(today),
                durations: durations,
                checkInDates: [today],
                showCheckInMarks: true
            )
        }
    }
}
