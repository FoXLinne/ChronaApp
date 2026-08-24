import Charts
import SwiftUI

struct StatisticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appModel: AppViewModel
    @State private var distributionRange: TimeRange = .day
    @State private var selectedDistributionEntryID: String?
    @State private var customFilterDate: Date?
    @State private var isDatePickerPresented = false
    @State private var hasAppeared = false
    @State private var heatmapMonth: Date = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: .now)
    ) ?? .now
    @State private var showCustomizeSheet = false
    private let allCardIDs = ["overview", "todayFocus", "heatmap", "distribution", "monthlyTrend"]
    private let distributionControlWidth: CGFloat = 156
    private let distributionControlHeight: CGFloat = 32

    /// 当前可见且按序排列的卡片
    private var visibleCards: [String] {
        let order = appModel.settings.statisticsCardOrder
        let hidden = Set(appModel.settings.statisticsHiddenCards)
        return order.filter { allCardIDs.contains($0) && !hidden.contains($0) }
    }

    private var isAtCurrentStatisticsMonth: Bool {
        Calendar.current.isDate(appModel.selectedStatisticsMonth, equalTo: .now, toGranularity: .month)
    }

    private func isCardExpanded(_ cardID: String) -> Bool {
        appModel.settings.statisticsExpandedCards.contains(cardID)
    }

    private func bindingForCard(_ cardID: String) -> Binding<Bool> {
        Binding(
            get: { appModel.settings.statisticsExpandedCards.contains(cardID) },
            set: { newValue in
                var expanded = appModel.settings.statisticsExpandedCards
                if newValue {
                    if !expanded.contains(cardID) { expanded.append(cardID) }
                } else {
                    expanded.removeAll { $0 == cardID }
                }
                appModel.settings.statisticsExpandedCards = expanded
            }
        )
    }

    private var dateFilterBinding: Binding<Date> {
        Binding(
            get: { customFilterDate ?? Date() },
            set: { customFilterDate = $0 }
        )
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
            .chronaSoftScrollEdgeEffect()
            .background {
                if colorScheme == .light {
                    PageBackground(seed: "ocean")
                }
            }
            .navigationTitle(String(localized: "tab.statistics"))
            .toolbarTitleDisplayMode(.inlineLarge)
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
            .sheet(isPresented: $isDatePickerPresented) {
                DateFilterPickerSheet(selection: dateFilterBinding)
            }
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                appModel.resetStatisticsTrendToToday()
                if let range = TimeRange(rawValue: appModel.settings.statisticsDistributionRange) {
                    distributionRange = range
                }
            }
            .onChange(of: distributionRange) { _, newValue in
                appModel.settings.statisticsDistributionRange = newValue.rawValue
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
            .chronaSoftScrollEdgeEffect()
            .navigationTitle(String(localized: "stats.customize.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        showCustomizeSheet = false
                    }
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
                if isCardExpanded("overview") {
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
                isExpanded: bindingForCard("overview")
            )
        }
    }
}

// MARK: - Today Focus Card
private extension StatisticsView {
    var todayFocusCard: some View {
        Section {
            Group {
                if isCardExpanded("todayFocus") {
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
                isExpanded: bindingForCard("todayFocus")
            )
        }
    }
}

// MARK: - Focus Heatmap Card
private extension StatisticsView {
    var heatmapCard: some View {
        Section {
            Group {
                if isCardExpanded("heatmap") {
                    FocusHeatmapView(
                        month: $heatmapMonth,
                        durations: appModel.dailyFocusDurations(for: heatmapMonth),
                        checkInDates: appModel.checkInDates,
                        showCheckInMarks: false,
                        headerTotalDuration: totalHeatmapDuration
                    )
                }
            }
        } header: {
            collapsibleHeader(
                title: String(localized: "stats.focusHeatmap"),
                isExpanded: bindingForCard("heatmap")
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
                if isCardExpanded("distribution") {
                    distributionContent
                }
            }
        } header: {
            collapsibleHeader(
                title: String(localized: "stats.distribution"),
                isExpanded: bindingForCard("distribution")
            )
        }
    }

    var distributionContent: some View {
        let entries: [TaskDistributionEntry]
        if let date = customFilterDate {
            entries = appModel.taskDistribution(on: date)
        } else {
            entries = appModel.taskDistribution(range: distributionRange)
        }
        let totalDuration = entries.reduce(0) { $0 + $1.duration }
        let threshold = totalDuration * 0.06
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 4) {
                distributionTotalView(duration: totalDuration)
                Spacer()
                if customFilterDate != nil {
                    dateFilterControl

                    Button {
                        customFilterDate = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .frame(width: 24, height: distributionControlHeight)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                } else {
                    Picker(String(localized: "Range"), selection: $distributionRange) {
                        Text(String(localized: "range.day")).tag(TimeRange.day)
                        Text(String(localized: "range.week")).tag(TimeRange.week)
                        Text(String(localized: "range.month")).tag(TimeRange.month)
                    }
                    .font(.headline.weight(.semibold))
                    .pickerStyle(.segmented)
                    .frame(width: distributionControlWidth)
                    .frame(height: distributionControlHeight)
                    Button {
                        customFilterDate = Date()
                        isDatePickerPresented = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.headline.weight(.semibold))
                            .frame(width: 24, height: distributionControlHeight)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
            }

            if entries.isEmpty {
                statisticsEmptyState()
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .background(cardSurfaceColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                Chart(entries) { entry in
                    SectorMark(
                        angle: .value(String(localized: "stats.totalDuration"), entry.duration),
                        innerRadius: .ratio(0),
                        outerRadius: .inset(selectedDistributionEntryID == entry.id ? 10 : 24)
                    )
                    .foregroundStyle(pastelColor(for: entry.colorSeed))
                    .opacity(entryOpacity(entry.id))
                    .annotation(position: .overlay) {
                        if entry.duration >= threshold {
                            Text(entry.taskTitle)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.black.opacity(0.72))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .padding(.horizontal, 4)
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let frame = geometry[plotFrame]
                                let center = CGPoint(x: frame.midX, y: frame.midY)
                                let dx = location.x - center.x
                                let dy = location.y - center.y
                                let radius = min(frame.width, frame.height) / 2
                                guard sqrt(dx * dx + dy * dy) <= radius else { return }
                                var angle = atan2(dy, dx) + .pi / 2
                                if angle < 0 { angle += 2 * .pi }
                                let total = entries.reduce(0) { $0 + $1.duration }
                                guard total > 0 else { return }
                                var accumulated: Double = 0
                                for entry in entries {
                                    accumulated += entry.duration
                                    if accumulated >= angle / (2 * .pi) * total {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if selectedDistributionEntryID == entry.id {
                                                selectedDistributionEntryID = nil
                                            } else {
                                                selectedDistributionEntryID = entry.id
                                            }
                                        }
                                        break
                                    }
                                }
                            }
                    }
                }
                .frame(height: 240)
                .background(cardSurfaceColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }

            ForEach(entries) { entry in
                distributionLegendRow(for: entry, totalDuration: totalDuration)
            }
        }
        .listRowBackground(cardSurfaceColor)
    }

    var dateFilterControl: some View {
        Button {
            isDatePickerPresented = true
        } label: {
            HStack(spacing: 6) {
                Text((customFilterDate ?? Date()).formatted(.dateTime.year().month().day()))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .font(.headline.weight(.semibold))
            .frame(width: distributionControlWidth, height: distributionControlHeight)
            .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
        .frame(width: distributionControlWidth, height: distributionControlHeight)
    }

    func distributionTotalView(duration: TimeInterval) -> some View {
        let total = max(0, Int(duration.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60

        return VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: "stats.totalDuration"))
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: "\(hours)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(String(localized: "time.hours"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: "\(minutes)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(String(localized: "time.minutes"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    func distributionLegendRow(for entry: TaskDistributionEntry, totalDuration: TimeInterval) -> some View {
        let percentage = totalDuration > 0 ? Int((entry.duration / totalDuration * 100).rounded()) : 0
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if selectedDistributionEntryID == entry.id {
                    selectedDistributionEntryID = nil
                } else {
                    selectedDistributionEntryID = entry.id
                }
            }
        } label: {
            HStack {
                Circle()
                    .fill(pastelColor(for: entry.colorSeed))
                    .frame(width: 10, height: 10)
                Text(entry.taskTitle)
                    .font(.subheadline)
                Spacer()
                Text("\(percentage)%  ·  \(appModel.formattedDuration(entry.duration))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .opacity(entryOpacity(entry.id))
    }

    func entryOpacity(_ id: String) -> Double {
        if let selected = selectedDistributionEntryID {
            return selected == id ? 1.0 : 0.35
        }
        return 1.0
    }

    func pastelColor(for seed: String) -> Color {
        let hues: [Double] = [0.92, 0.55, 0.08, 0.38, 0.67, 0.78, 0.2, 0.48]
        let index = stableColorIndex(for: seed, count: hues.count)
        return Color(hue: hues[index], saturation: 0.35, brightness: 0.92)
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
                if isCardExpanded("monthlyTrend") {
                    monthlyTrendContent
                }
            }
        } header: {
            collapsibleHeader(
                title: String(localized: "stats.monthlyTrend"),
                isExpanded: bindingForCard("monthlyTrend")
            )
        }
    }

    var monthlyTrendContent: some View {
        let points = appModel.monthlyTrendPoints()
        let trendDomain = appModel.statisticsTrendDomain()
        let hasTrendData = points.contains { $0.duration > 0 }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: { appModel.cycleStatisticsMonth(forward: false) }) {
                    Image(systemName: "chevron.left")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(appModel.selectedStatisticsMonth.formatted(.dateTime.year().month()))
                    .font(.title3.weight(.semibold))

                Spacer()

                Button(action: { appModel.cycleStatisticsMonth(forward: true) }) {
                    Image(systemName: "chevron.right")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(isAtCurrentStatisticsMonth)
                .opacity(isAtCurrentStatisticsMonth ? 0.35 : 1)
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
        let parts = template.localizedTemplateParts()

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

    func statisticsEmptyState() -> some View {
        Text(String(localized: "stats.empty.records"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}

private struct DateFilterPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: Date

    var body: some View {
        NavigationStack {
            DatePicker(
                "",
                selection: $selection,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(430)])
    }
}

#Preview {
    StatisticsView()
        .environmentObject(AppViewModel())
}
