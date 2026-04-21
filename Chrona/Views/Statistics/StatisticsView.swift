import Charts
import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var distributionRange: TimeRange = .week

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    summarySection
                    routineSection
                    distributionSection
                    monthlyTrendSection
                    routineTrendSection
                }
                .padding()
            }
            .navigationTitle(String(localized: "tab.statistics"))
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "stats.summary"))
                .font(.headline)

            HStack {
                MetricCard(title: "stats.totalCount", value: "\(appModel.sessions.count)", subtitle: nil)
                MetricCard(title: "stats.totalDuration", value: appModel.formattedDuration(appModel.sessions.reduce(0) { $0 + $1.focusedDuration }), subtitle: nil)
            }
            HStack {
                MetricCard(title: "stats.dailyAverage", value: appModel.formattedDuration(appModel.averageDailyDuration()), subtitle: nil)
                MetricCard(title: "stats.todayCount", value: "\(appModel.totalFocusedCount(for: .day))", subtitle: appModel.formattedDuration(appModel.totalFocusedDuration(for: .day)))
            }
        }
    }

    private var routineSection: some View {
        let routine = appModel.previousSleepAndTodayWake()
        return VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "stats.routine"))
                .font(.headline)
            HStack {
                MetricCard(
                    title: "stats.yesterdaySleep",
                    value: routine.sleep.map { $0.formatted(date: .omitted, time: .shortened) } ?? "--",
                    subtitle: nil
                )
                MetricCard(
                    title: "stats.todayWake",
                    value: routine.wake.map { $0.formatted(date: .omitted, time: .shortened) } ?? "--",
                    subtitle: String(localized: "stats.wakeOnce")
                )
            }
        }
    }

    private var distributionSection: some View {
        let entries = appModel.taskDistribution(range: distributionRange)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "stats.distribution"))
                    .font(.headline)
                Spacer()
                Picker("Range", selection: $distributionRange) {
                    Text(String(localized: "range.day")).tag(TimeRange.day)
                    Text(String(localized: "range.week")).tag(TimeRange.week)
                    Text(String(localized: "range.month")).tag(TimeRange.month)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }

            Chart(entries) { entry in
                SectorMark(angle: .value("Duration", entry.duration), innerRadius: .ratio(0.55))
                    .foregroundStyle(color(for: entry.colorSeed))
            }
            .frame(height: 220)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            ForEach(entries) { entry in
                HStack {
                    Circle().fill(color(for: entry.colorSeed)).frame(width: 10, height: 10)
                    Text(entry.taskTitle)
                    Spacer()
                    Text(appModel.formattedDuration(entry.duration))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
    }

    private var monthlyTrendSection: some View {
        let points = appModel.monthlyTrend(weekOffset: appModel.selectedStatisticsWeekOffset)
        return VStack(alignment: .leading, spacing: 12) {
            header(
                title: String(localized: "stats.monthlyTrend"),
                month: appModel.selectedStatisticsMonth,
                previous: { appModel.cycleStatisticsMonth(forward: false) },
                next: { appModel.cycleStatisticsMonth(forward: true) }
            )

            Chart(points) { point in
                LineMark(x: .value("Day", point.date, unit: .day), y: .value("Duration", point.duration / 60))
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("Day", point.date, unit: .day), y: .value("Duration", point.duration / 60))
                    .foregroundStyle(.blue.opacity(0.12))
            }
            .frame(height: 220)
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            weekSwitcher(
                offset: appModel.selectedStatisticsWeekOffset,
                decrement: { appModel.selectedStatisticsWeekOffset -= 1 },
                increment: { appModel.selectedStatisticsWeekOffset += 1 }
            )
        }
    }

    private var routineTrendSection: some View {
        let wakePoints = appModel.routineTrend(isWake: true, weekOffset: appModel.selectedRoutineWeekOffset)
        let sleepPoints = appModel.routineTrend(isWake: false, weekOffset: appModel.selectedRoutineWeekOffset)
        return VStack(alignment: .leading, spacing: 12) {
            header(
                title: String(localized: "stats.routineTrend"),
                month: appModel.selectedRoutineMonth,
                previous: { appModel.cycleRoutineMonth(forward: false) },
                next: { appModel.cycleRoutineMonth(forward: true) }
            )

            Chart {
                ForEach(wakePoints.filter { !$0.value.isNaN }) { point in
                    LineMark(x: .value("Day", point.date, unit: .day), y: .value("Wake", point.value))
                        .foregroundStyle(.orange)
                }
                ForEach(sleepPoints.filter { !$0.value.isNaN }) { point in
                    LineMark(x: .value("Day", point.date, unit: .day), y: .value("Sleep", point.value))
                        .foregroundStyle(.indigo)
                }
            }
            .frame(height: 220)
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            weekSwitcher(
                offset: appModel.selectedRoutineWeekOffset,
                decrement: { appModel.selectedRoutineWeekOffset -= 1 },
                increment: { appModel.selectedRoutineWeekOffset += 1 }
            )
        }
    }

    private func header(title: String, month: Date, previous: @escaping () -> Void, next: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Button(action: previous) { Image(systemName: "chevron.left") }
            Text(month.formatted(.dateTime.year().month()))
                .font(.subheadline.weight(.medium))
            Button(action: next) { Image(systemName: "chevron.right") }
        }
    }

    private func weekSwitcher(offset: Int, decrement: @escaping () -> Void, increment: @escaping () -> Void) -> some View {
        HStack {
            Button(String(localized: "common.previousWeek"), action: decrement)
            Spacer()
            Text(String(format: String(localized: "stats.weekOffset"), offset + 1))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button(String(localized: "common.nextWeek"), action: increment)
        }
        .buttonStyle(.bordered)
    }

    private func color(for seed: String) -> Color {
        let colors: [Color] = [.pink, .orange, .blue, .mint, .indigo, .teal]
        let index = abs(seed.hashValue) % colors.count
        return colors[index]
    }
}
