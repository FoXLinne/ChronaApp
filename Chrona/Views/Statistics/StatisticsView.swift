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
                    distributionSection
                    monthlyTrendSection
                }
                .padding()
            }
            .navigationTitle(String(localized: "tab.statistics"))
        }
    }

    private var summarySection: some View {
        VStack(spacing: 12) {
            statsPanel(
                title: String(localized: "stats.summary"),
                rows: [
                    (String(localized: "stats.totalCount"), "\(appModel.sessions.count)"),
                    (String(localized: "stats.totalDuration"), appModel.formattedDuration(totalDurationAll)),
                    (String(localized: "stats.dailyAverage"), appModel.formattedDuration(appModel.averageDailyDuration()))
                ]
            )

            statsPanel(
                title: String(localized: "stats.todayFocus"),
                rows: [
                    (String(localized: "stats.totalCount"), "\(appModel.totalFocusedCount(for: .day))"),
                    (String(localized: "stats.totalDuration"), appModel.formattedDuration(appModel.totalFocusedDuration(for: .day)))
                ]
            )
        }
    }

    private var totalDurationAll: TimeInterval {
        appModel.sessions.reduce(0) { $0 + $1.focusedDuration }
    }

    private func statsPanel(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 12) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    compactMetric(title: row.0, value: row.1)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func compactMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

#Preview {
    StatisticsView()
        // 必须加上这一行，预览才能跑起来
        .environmentObject(AppViewModel())
}
