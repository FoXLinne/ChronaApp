import SwiftUI

/// 专注热力图组件，供签到页和统计页共用。
/// - showCheckInMarks: 是否在格子右下角显示签到绿点（统计页关掉即可）
struct FocusHeatmapView: View {
    @Binding var month: Date
    let durations: [Date: TimeInterval]
    let checkInDates: [Date]
    let showCheckInMarks: Bool
    let monthSummary: String?

    var body: some View {
        VStack(spacing: 10) {
            monthNavigation

            weekdayHeadersRow

            calendarGrid

            heatmapLegend
        }
    }

    init(
        month: Binding<Date>,
        durations: [Date: TimeInterval],
        checkInDates: [Date],
        showCheckInMarks: Bool,
        monthSummary: String? = nil
    ) {
        _month = month
        self.durations = durations
        self.checkInDates = checkInDates
        self.showCheckInMarks = showCheckInMarks
        self.monthSummary = monthSummary
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
        withAnimation(.easeInOut(duration: 0.2)) {
            month = target
        }
    }

    private func startOfMonth(for date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }
}

// MARK: - Month Navigation
private extension FocusHeatmapView {
    var monthNavigation: some View {
        VStack(spacing: 4) {
            HStack {
                Spacer()

                HStack(spacing: 8) {
                    Button { moveMonth(by: -1) } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)

                    Text(month.formatted(.dateTime.year().month(.wide)))
                        .font(.headline.weight(.semibold))

                    Button { moveMonth(by: 1) } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .disabled(isCurrentMonth)
                    .opacity(isCurrentMonth ? 0.35 : 1)
                }
            }

            if let monthSummary {
                Text(monthSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Weekday Headers
private extension FocusHeatmapView {
    var weekdayHeadersRow: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
            ForEach(weekdayHeaders, id: \.self) { header in
                Text(header)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    var weekdayHeaders: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }
}

// MARK: - Calendar Grid
private extension FocusHeatmapView {
    var calendarGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
            spacing: 2
        ) {
            ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, date in
                if let date = date {
                    let duration = durations[date] ?? 0
                    let isToday = Calendar.current.isDateInToday(date)

                    dayCell(date: date, duration: duration, isToday: isToday)
                } else {
                    Color.clear
                        .aspectRatio(1, contentMode: .fill)
                }
            }
        }
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

        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    func dayCell(date: Date, duration: TimeInterval, isToday: Bool) -> some View {
        let hasCheckIn = showCheckInMarks && checkInDates.contains {
            Calendar.current.isDate($0, inSameDayAs: date)
        }

        return ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(heatmapColor(for: duration))
                .aspectRatio(1, contentMode: .fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isToday ? Color.accentColor : .clear, lineWidth: 2)
                )

            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 12, weight: isToday ? .semibold : .regular))
                .foregroundStyle(duration > 0 ? .primary : .secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(3)

            if hasCheckIn {
                Circle()
                    .fill(.green)
                    .frame(width: 5, height: 5)
                    .padding(3)
            }
        }
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
            legendSwatch(color: heatmapColor(for: 15 * 60))
            legendSwatch(color: heatmapColor(for: 45 * 60))
            legendSwatch(color: heatmapColor(for: 90 * 60))

            Text(String(localized: "checkin.heatmap.legend.long"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    func legendSwatch(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .frame(width: 16, height: 12)
    }

    func heatmapColor(for duration: TimeInterval) -> Color {
        guard duration > 0 else {
            return Color(uiColor: .secondarySystemGroupedBackground)
        }
        let hours = duration / 3600
        let ratio = min(max(hours / 2.0, 0.05), 1.0)
        return Color.accentColor.opacity(0.15 + ratio * 0.7)
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
