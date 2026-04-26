import Charts
import SwiftUI

struct StatisticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appModel: AppViewModel
    @State private var distributionRange: TimeRange = .week
    @State private var hasAppeared = false
    @State private var heatmapMonth: Date = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: .now)
    ) ?? .now
    @State private var isOverviewExpanded = true
    @State private var isTodayExpanded = true
    @State private var isHeatmapExpanded = false
    @State private var isDistributionExpanded = true
    @State private var isMonthlyTrendExpanded = true
    @State private var showCustomizeSheet = false
    private let rangeControlWidth: CGFloat = 192

    /// 全部卡片 ID，与 AppSettings 中的定义保持一致
    private let allCardIDs = ["overview", "todayFocus", "heatmap", "distribution", "monthlyTrend"]

    /// 当前可见且按序排列的卡片
    private var visibleCards: [String] {
        let order = appModel.settings.statisticsCardOrder
        let hidden = Set(appModel.settings.statisticsHiddenCards)
        return order.filter { allCardIDs.contains($0) && !hidden.contains($0) }
    }

    private var isAtCurrentStatisticsMonth: Bool {
        Calendar.current.isDate(appModel.selectedStatisticsMonth, equalTo: .now, toGranularity: .month)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleCards, id: \.self) { cardID in
                    cardView(for: cardID)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCustomizeSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .accessibilityLabel(String(localized: "stats.customize.title"))
                }
            }
            .sheet(isPresented: $showCustomizeSheet) {
                customizeSheet
            }
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                appModel.resetStatisticsTrendToToday()
            }
        }
    }

    private var cardSurfaceColor: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    @ViewBuilder
    private func cardView(for cardID: String) -> some View {
        switch cardID {
        case "overview":
            overviewCard
        case "todayFocus":
            todayFocusCard
        case "heatmap":
            heatmapCard
        case "distribution":
            distributionCard
        case "monthlyTrend":
            monthlyTrendCard
        default:
            EmptyView()
        }
    }
}

// MARK: - Customize Sheet
private extension StatisticsView {
    var customizeSheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(appModel.settings.statisticsCardOrder, id: \.self) { cardID in
                        HStack {
                            Text(cardLabel(for: cardID))
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { !appModel.settings.statisticsHiddenCards.contains(cardID) },
                                set: { newValue in
                                    var hidden = appModel.settings.statisticsHiddenCards
                                    if newValue {
                                        hidden.removeAll { $0 == cardID }
                                    } else {
                                        hidden.append(cardID)
                                    }
                                    appModel.settings.statisticsHiddenCards = hidden
                                }
                            ))
                            .labelsHidden()
                        }
                    }
                    .onMove { source, destination in
                        var order = appModel.settings.statisticsCardOrder
                        order.move(fromOffsets: source, toOffset: destination)
                        appModel.settings.statisticsCardOrder = order
                    }
                } footer: {
                    Text(String(localized: "stats.customize.footer"))
                }
            }
            .navigationTitle(String(localized: "stats.customize.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showCustomizeSheet = false
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .tint(.accentColor)
                }
            }
            .environment(\.editMode, .constant(.active))
        }
    }

    func cardLabel(for cardID: String) -> String {
        switch cardID {
        case "overview":     return String(localized: "stats.overview")
        case "todayFocus":   return String(localized: "stats.todayFocus")
        case "heatmap":      return String(localized: "stats.focusHeatmap")
        case "distribution": return String(localized: "stats.distribution")
        case "monthlyTrend": return String(localized: "stats.monthlyTrend")
        default:             return cardID
        }
    }
}

// MARK: - Overview Card
private extension StatisticsView {
    var overviewCard: some View {
        Section {
            Group {
                if isOverviewExpanded {
                    statsValueRow(
                        title: String(localized: "stats.totalCount"),
                        count: appModel.sessions.count
                    )
                    statsDurationRow(
                        title: String(localized: "stats.totalDuration"),
                        duration: appModel.totalFocusedDurationAllTime
                    )
                    statsDurationRow(
                        title: String(localized: "stats.dailyAverage"),
                        duration: appModel.averageDailyDuration()
                    )
                }
            }
        } header: {
            collapsibleHeader(
                title: String(localized: "stats.overview"),
                isExpanded: $isOverviewExpanded
            )
        }
    }
}

// MARK: - Today Focus Card
private extension StatisticsView {
    var todayFocusCard: some View {
        Section {
            Group {
                if isTodayExpanded {
                    statsValueRow(
                        title: String(localized: "stats.totalCount"),
                        count: appModel.totalFocusedCount(for: .day)
                    )
                    statsDurationRow(
                        title: String(localized: "stats.totalDuration"),
                        duration: appModel.totalFocusedDuration(for: .day)
                    )
                }
            }
        } header: {
            collapsibleHeader(
                title: String(localized: "stats.todayFocus"),
                isExpanded: $isTodayExpanded
            )
        }
    }
}

// MARK: - Focus Heatmap Card
private extension StatisticsView {
    var heatmapCard: some View {
        Section {
            Group {
                if isHeatmapExpanded {
                    FocusHeatmapView(
                        month: $heatmapMonth,
                        durations: appModel.dailyFocusDurations(for: heatmapMonth),
                        checkInDates: appModel.checkInDates,
                        showCheckInMarks: false,
                        monthSummary: String(
                            format: String(localized: "stats.focusHeatmap.monthTotal"),
                            appModel.formattedDuration(totalHeatmapDuration)
                        )
                    )
                }
            }
        } header: {
            collapsibleHeader(
                title: String(localized: "stats.focusHeatmap"),
                isExpanded: $isHeatmapExpanded
            )
        }
    }

    var totalHeatmapDuration: TimeInterval {
        appModel.dailyFocusDurations(for: heatmapMonth).values.reduce(0, +)
    }
}

// MARK: - Distribution Card
private extension StatisticsView {
    var distributionCard: some View {
        Section {
            Group {
                if isDistributionExpanded {
                    distributionContent
                }
            }
        } header: {
            collapsibleHeader(
                title: String(localized: "stats.distribution"),
                isExpanded: $isDistributionExpanded
            )
        }
    }

    var distributionContent: some View {
        let entries = appModel.taskDistribution(range: distributionRange)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Picker(String(localized: "Range"), selection: $distributionRange) {
                    Text(String(localized: "range.day")).tag(TimeRange.day)
                    Text(String(localized: "range.week")).tag(TimeRange.week)
                    Text(String(localized: "range.month")).tag(TimeRange.month)
                }
                .font(.headline.weight(.semibold))
                .pickerStyle(.segmented)
                .frame(width: rangeControlWidth)
            }

            if entries.isEmpty {
                statisticsEmptyState()
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .background(cardSurfaceColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                Chart(entries) { entry in
                    SectorMark(
                        angle: .value(String(localized: "stats.totalDuration"), entry.duration),
                        innerRadius: .ratio(0.55),
                        outerRadius: .inset(24)
                    )
                    .foregroundStyle(color(for: entry.colorSeed))
                }
                .frame(height: 220)
                .background(cardSurfaceColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }

            ForEach(entries) { entry in
                distributionLegendRow(for: entry)
            }
        }
        .listRowBackground(cardSurfaceColor)
    }

    func distributionLegendRow(for entry: TaskDistributionEntry) -> some View {
        HStack {
            Circle().fill(color(for: entry.colorSeed)).frame(width: 10, height: 10)
            Text(entry.taskTitle)
            Spacer()
            Text(appModel.formattedDuration(entry.duration))
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    func color(for seed: String) -> Color {
        let colors: [Color] = [.pink, .orange, .blue, .mint, .indigo, .teal]
        let index = stableColorIndex(for: seed, count: colors.count)
        return colors[index]
    }

    func stableColorIndex(for seed: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let hash = seed.utf8.reduce(UInt64(1_469_598_103_934_665_603)) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }
}

// MARK: - Monthly Trend Card
private extension StatisticsView {
    var monthlyTrendCard: some View {
        Section {
            Group {
                if isMonthlyTrendExpanded {
                    monthlyTrendContent
                }
            }
        } header: {
            collapsibleHeader(
                title: String(localized: "stats.monthlyTrend"),
                isExpanded: $isMonthlyTrendExpanded
            )
        }
    }

    var monthlyTrendContent: some View {
        let points = appModel.monthlyTrendPoints()
        let trendDomain = appModel.statisticsTrendDomain()
        let hasTrendData = points.contains { $0.duration > 0 }
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

            if hasTrendData {
                let dayLabel = String(localized: "stats.monthlyTrend.day")
                let durationLabel = String(localized: "stats.monthlyTrend.duration")
                Chart(points) { point in
                    LineMark(
                        x: .value(dayLabel, point.date, unit: .day),
                        y: .value(durationLabel, point.duration / 60)
                    )
                    .interpolationMethod(.catmullRom)
                    AreaMark(
                        x: .value(dayLabel, point.date, unit: .day),
                        y: .value(durationLabel, point.duration / 60)
                    )
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
                .padding(.vertical, 12)
                .padding(.horizontal, 4)
                .background(cardSurfaceColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                statisticsEmptyState()
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .padding()
                    .background(cardSurfaceColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
        .listRowBackground(cardSurfaceColor)
    }
}

// MARK: - Shared Components
private extension StatisticsView {
    func collapsibleHeader(title: String, isExpanded: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.wrappedValue.toggle()
            }
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 0 : -90))
            }
        }
        .buttonStyle(.plain)
        .textCase(nil)
    }

    func statsValueRow(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            countValueView(count)
                .fixedSize(horizontal: true, vertical: false)
        }
        .listRowBackground(cardSurfaceColor)
    }

    func statsDurationRow(title: String, duration: TimeInterval) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            durationValueView(duration)
                .fixedSize(horizontal: true, vertical: false)
        }
        .listRowBackground(cardSurfaceColor)
    }

    func countValueView(_ count: Int) -> some View {
        localizedNumberTemplate(
            String(localized: "stats.count.value"),
            number: count,
            numberFont: .system(size: 24, weight: .bold, design: .rounded),
            textFont: .caption
        )
    }

    func durationValueView(_ value: TimeInterval) -> some View {
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

    func durationPart(value: Int, unitText: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(verbatim: "\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(unitText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    func localizedNumberTemplate(
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

    func localizedTemplateParts(_ template: String) -> (prefix: String, suffix: String) {
        let parts = template.components(separatedBy: "{count}")
        guard parts.count == 2 else {
            return ("", template)
        }
        return (
            parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
            parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func statisticsEmptyState() -> some View {
        Text(String(localized: "stats.empty.records"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}

#Preview {
    StatisticsView()
        .environmentObject(AppViewModel())
}
