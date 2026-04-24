import Charts
import SwiftUI

struct StatisticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appModel: AppViewModel
    @State private var distributionRange: TimeRange = .week
    private let rangeControlWidth: CGFloat = 192

    private var isAtCurrentStatisticsMonth: Bool {
        Calendar.current.isDate(appModel.selectedStatisticsMonth, equalTo: .now, toGranularity: .month)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    statsValueRow(
                        title: String(localized: "stats.totalCount"),
                        count: appModel.sessions.count
                    )
                    statsDurationRow(
                        title: String(localized: "stats.totalDuration"),
                        duration: totalDurationAll
                    )
                    statsDurationRow(
                        title: String(localized: "stats.dailyAverage"),
                        duration: appModel.averageDailyDuration()
                    )
                }

                Section {
                    statsValueRow(
                        title: String(localized: "stats.totalCount"),
                        count: appModel.totalFocusedCount(for: .day)
                    )
                    statsDurationRow(
                        title: String(localized: "stats.totalDuration"),
                        duration: appModel.totalFocusedDuration(for: .day)
                    )
                } header: {
                    Text(String(localized: "stats.todayFocus"))
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }

                Section(String(localized: "stats.distribution")) {
                    distributionSection
                }

                Section(String(localized: "stats.monthlyTrend")) {
                    monthlyTrendSection
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(colorScheme == .light ? .hidden : .automatic)
            .background {
                if colorScheme == .light {
                    PageBackground(seed: "ocean")
                }
            }
            .navigationTitle(String(localized: "tab.statistics"))
            .onAppear {
                appModel.resetStatisticsTrendToToday()
            }
        }
    }

    private var totalDurationAll: TimeInterval {
        appModel.sessions.reduce(0) { $0 + $1.focusedDuration }
    }

    private var cardSurfaceColor: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    private func statsValueRow(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            countValueView(count)
        }
        .listRowBackground(cardSurfaceColor)
    }

    private func countValueView(_ count: Int) -> some View {
        localizedNumberTemplate(
            String(localized: "stats.count.value"),
            number: count,
            numberFont: .system(size: 24, weight: .bold, design: .rounded),
            textFont: .caption
        )
    }

    private func statsDurationRow(title: String, duration: TimeInterval) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            durationValueView(duration)
        }
        .listRowBackground(cardSurfaceColor)
    }

    private func durationValueView(_ value: TimeInterval) -> some View {
        let duration = max(0, Int(value.rounded()))
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60

        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            durationPart(value: hours, unitText: String(localized: "time.hours"))
            durationPart(value: minutes, unitText: String(localized: "time.minutes"))
            durationPart(value: seconds, unitText: String(localized: "time.seconds"))
        }
    }

    private func durationPart(value: Int, unitText: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(verbatim: "\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(unitText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // Keeps compact numeric values localizable without losing the large-number styling.
    private func localizedNumberTemplate(
        _ template: String,
        number: Int,
        numberFont: Font,
        textFont: Font
    ) -> some View {
        let parts = localizedTemplateParts(template)

        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            if !parts.prefix.isEmpty {
                Text(parts.prefix)
                    .font(textFont)
                    .foregroundStyle(.secondary)
            }
            Text(verbatim: "\(number)")
                .font(numberFont)
                .monospacedDigit()
            if !parts.suffix.isEmpty {
                Text(parts.suffix)
                    .font(textFont)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func localizedTemplateParts(_ template: String) -> (prefix: String, suffix: String) {
        let parts = template.components(separatedBy: "{count}")
        guard parts.count == 2 else {
            return ("", template)
        }
        return (
            parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
            parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private var distributionSection: some View {
        let entries = appModel.taskDistribution(range: distributionRange)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Picker("Range", selection: $distributionRange) {
                    Text(String(localized: "range.day")).tag(TimeRange.day)
                    Text(String(localized: "range.week")).tag(TimeRange.week)
                    Text(String(localized: "range.month")).tag(TimeRange.month)
                }
                .font(.headline.weight(.semibold))
                .pickerStyle(.segmented)
                .frame(width: rangeControlWidth)
            }

            Chart(entries) { entry in
                SectorMark(
                    angle: .value("Duration", entry.duration),
                    innerRadius: .ratio(0.55),
                    outerRadius: .inset(24)
                )
                    .foregroundStyle(color(for: entry.colorSeed))
            }
            .frame(height: 220)
            .background(cardSurfaceColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

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
        .listRowBackground(cardSurfaceColor)
    }

    private var monthlyTrendSection: some View {
        let points = appModel.monthlyTrendPoints()
        let trendDomain = appModel.statisticsTrendDomain()
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    Button(action: { appModel.cycleStatisticsMonth(forward: false) }) {
                        Image(systemName: "chevron.left")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    Text(appModel.selectedStatisticsMonth.formatted(.dateTime.year().month()))
                        .font(.headline.weight(.semibold))
                    Button(action: { appModel.cycleStatisticsMonth(forward: true) }) {
                        Image(systemName: "chevron.right")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .disabled(isAtCurrentStatisticsMonth)
                    .opacity(isAtCurrentStatisticsMonth ? 0.35 : 1)
                }
            }

            Chart(points) { point in
                LineMark(x: .value("Day", point.date, unit: .day), y: .value("Duration", point.duration / 60))
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("Day", point.date, unit: .day), y: .value("Duration", point.duration / 60))
                    .foregroundStyle(.blue.opacity(0.12))
            }
            .chartScrollableAxes(.horizontal)
            .chartXScale(domain: trendDomain)
            .chartXVisibleDomain(length: appModel.statisticsTrendVisibleLength)
            .chartScrollPosition(
                x: Binding(
                    get: { appModel.statisticsTrendScrollDate },
                    set: { appModel.updateStatisticsTrendScrollDate($0) }
                )
            )
            .frame(height: 220)
            .padding()
            .background(cardSurfaceColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .listRowBackground(cardSurfaceColor)
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
