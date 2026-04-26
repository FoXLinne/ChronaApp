import SwiftUI

struct DailyCheckInView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appModel: AppViewModel

    @State private var heatmapMonth: Date = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: .now)
    ) ?? .now

    var body: some View {
        List {
            // MARK: - 签到概览
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: appModel.hasCheckedInToday ? "checkmark.circle.fill" : "calendar.badge.plus")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(appModel.hasCheckedInToday ? .green : .accent)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "checkin.title"))
                                .font(.headline)
                            Text(
                                appModel.hasCheckedInToday
                                    ? String(localized: "checkin.today.done")
                                    : String(localized: "checkin.today.pending")
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        statChip(
                            title: String(localized: "checkin.streak"),
                            value: String(format: String(localized: "checkin.streak.days"), appModel.checkInStreak)
                        )

                        statChip(
                            title: String(localized: "checkin.total"),
                            value: String(format: String(localized: "checkin.total.days"), appModel.totalCheckInCount)
                        )

                        statChip(
                            title: String(localized: "checkin.streak.longest"),
                            value: String(format: String(localized: "checkin.streak.days"), appModel.longestCheckInStreak)
                        )
                    }

                    Button {
                        if appModel.checkInToday() {
                            appModel.showGlobalNotice(String(localized: "checkin.success"))
                        }
                    } label: {
                        if appModel.hasCheckedInToday {
                            HStack(spacing: 8) {
                                Text(String(localized: "checkin.action.done"))
                            }
                            .frame(width: 108, height: 32)
                        } else {
                            HStack(spacing: 8) {
                                Text(String(localized: "checkin.action"))
                            }
                            .frame(width: 108, height: 32)
                            .foregroundStyle(Color.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .buttonStyle(.glass(.regular.tint(.accentColor)))
                    .disabled(appModel.hasCheckedInToday)
                }
                .padding(.vertical, 4)
            }

            // MARK: - 专注热力图
            Section(String(localized: "checkin.heatmap.title")) {
                VStack(spacing: 10) {
                    monthNavigation

                    weekdayHeadersRow

                    calendarGrid

                    heatmapLegend
                }
            }

            // MARK: - 签到历史
            Section(String(localized: "checkin.history")) {
                if appModel.checkInDates.isEmpty {
                    Text(String(localized: "checkin.history.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(appModel.checkInDates.prefix(30)), id: \.self) { date in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text(relativeLabel(for: date))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "checkin.title"))
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(colorScheme == .light ? .hidden : .automatic)
        .background {
            if colorScheme == .light {
                PageBackground(seed: "sunset")
            }
        }
    }
}

// MARK: - 热力图子视图
private extension DailyCheckInView {
    var monthNavigation: some View {
        HStack {
            Button {
                guard let prev = Calendar.current.date(byAdding: .month, value: -1, to: heatmapMonth) else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    heatmapMonth = prev
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.medium))
            }
            .disabled(isAtEarliestMonth)

            Spacer()

            Text(heatmapMonth.formatted(.dateTime.year().month(.wide)))
                .font(.subheadline.weight(.medium))

            Spacer()

            Button {
                guard let next = Calendar.current.date(byAdding: .month, value: 1, to: heatmapMonth) else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    heatmapMonth = next
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.medium))
            }
            .disabled(isCurrentMonth)
        }
        .padding(.horizontal, 2)
    }

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

    var calendarGrid: some View {
        let durations = appModel.dailyFocusDurations(for: heatmapMonth)

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
            spacing: 2
        ) {
            ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, date in
                if let date = date {
                    let duration = durations[date] ?? 0
                    let isToday = Calendar.current.isDateInToday(date)
                    let hasCheckIn = appModel.checkInDates.contains {
                        Calendar.current.isDate($0, inSameDayAs: date)
                    }

                    dayCell(
                        date: date,
                        duration: duration,
                        isToday: isToday,
                        hasCheckIn: hasCheckIn
                    )
                } else {
                    Color.clear
                        .aspectRatio(1, contentMode: .fill)
                }
            }
        }
    }

    func dayCell(date: Date, duration: TimeInterval, isToday: Bool, hasCheckIn: Bool) -> some View {
        ZStack(alignment: .bottomTrailing) {
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

    // MARK: - 计算属性

    var weekdayHeaders: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    var calendarDays: [Date?] {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: heatmapMonth)) ?? heatmapMonth
        let range = calendar.range(of: .day, in: .month, for: heatmapMonth) ?? 1..<2

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

    var isCurrentMonth: Bool {
        let calendar = Calendar.current
        return calendar.isDate(heatmapMonth, equalTo: .now, toGranularity: .month)
    }

    var isAtEarliestMonth: Bool {
        guard let earliest = appModel.sessions.map(\.startedAt).min() else { return false }
        let calendar = Calendar.current
        let earliestMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: earliest)) ?? earliest
        return heatmapMonth <= earliestMonth
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

// MARK: - 签到通用组件
private extension DailyCheckInView {
    func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func relativeLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return String(localized: "checkin.history.today")
        }
        if let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: .now)).day {
            return String(format: String(localized: "checkin.history.daysAgo"), max(days, 0))
        }
        return ""
    }
}

#Preview {
    NavigationStack {
        DailyCheckInView()
            .environmentObject(AppViewModel.previewModel())
    }
}
