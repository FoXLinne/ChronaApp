import AppIntents
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Shared Formatting

private enum WidgetFormatters {
    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct WidgetBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .containerBackground(.ultraThinMaterial, for: .widget)
    }
}

private extension View {
    func chronaWidgetBackground() -> some View {
        modifier(WidgetBackground())
    }
}

private struct WidgetNumberUnit: View {
    let value: Int
    let unitKey: String
    let numberSize: CGFloat
    var unitFont: Font = .footnote.weight(.semibold)
    var unitColor: Color?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text("\(value)")
                .font(.system(size: numberSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            unitText
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    @ViewBuilder
    private var unitText: some View {
        let text = Text(LocalizedStringKey(unitKey))
            .font(unitFont)
        if let unitColor {
            text.foregroundStyle(unitColor)
        } else {
            text
        }
    }
}

// MARK: - Today Focus Widget

struct TodayFocusProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayFocusEntry {
        TodayFocusEntry(date: .now, duration: 2 * 3600 + 15 * 60)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayFocusEntry) -> Void) {
        completion(TodayFocusEntry(date: .now, duration: SharedStore.todayFocusDuration))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayFocusEntry>) -> Void) {
        let entry = TodayFocusEntry(date: .now, duration: SharedStore.todayFocusDuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct TodayFocusEntry: TimelineEntry {
    let date: Date
    let duration: TimeInterval
}

struct TodayFocusWidgetEntryView: View {
    var entry: TodayFocusProvider.Entry
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    private var durationColor: Color {
        widgetRenderingMode == .fullColor ? Color("AccentColor") : .primary
    }

    var body: some View {
        Link(destination: URL(string: "chrona://statistics")!) {
            VStack(alignment: .leading, spacing: 0) {
                Text(WidgetFormatters.date.string(from: entry.date))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)

                Color.clear.frame(height: 14)

                WidgetDurationValue(duration: entry.duration)
                    .foregroundStyle(durationColor)
                    .widgetAccentable()

                Spacer(minLength: 8)

                Text(String(localized: "widget.todayFocus.completed"))
                    .font(.body.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

private struct WidgetDurationValue: View {
    let duration: TimeInterval

    private var parts: (hours: Int, minutes: Int) {
        let totalMinutes = max(0, Int(duration / 60))
        return (totalMinutes / 60, totalMinutes % 60)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if parts.hours > 0 {
                WidgetNumberUnit(value: parts.hours, unitKey: "time.hours", numberSize: 32, unitColor: .secondary)
            }
            WidgetNumberUnit(value: parts.minutes, unitKey: "time.minutes", numberSize: 32, unitColor: .secondary)
        }
    }
}

struct TodayFocusWidget: Widget {
    let kind: String = ChronaWidgetKind.todayFocus

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayFocusProvider()) { entry in
            TodayFocusWidgetEntryView(entry: entry)
                .chronaWidgetBackground()
        }
        .configurationDisplayName(String(localized: "widget.todayFocus"))
        .description(String(localized: "widget.todayFocus.description"))
        .supportedFamilies([.systemSmall])
        .containerBackgroundRemovable(true)
    }
}

// MARK: - Countdown Widget Intent

struct CountdownEventEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "widget.countdown.event.type")
    static let defaultQuery = CountdownEventQuery()

    let id: UUID
    let title: String
    let date: Date
    let includesTime: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(WidgetFormatters.date.string(from: date))"
        )
    }

    init(event: SharedCountdownEvent) {
        id = event.id
        title = event.title
        date = event.date
        includesTime = event.includesTime
    }
}

struct CountdownEventQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [CountdownEventEntity] {
        SharedStore.countdownEvents
            .filter { identifiers.contains($0.id) }
            .map(CountdownEventEntity.init(event:))
    }

    func suggestedEntities() async throws -> [CountdownEventEntity] {
        SharedStore.countdownEvents
            .sorted(by: { $0.date < $1.date })
            .map(CountdownEventEntity.init(event:))
    }

    func defaultResult() async -> CountdownEventEntity? {
        CountdownEventProvider.fallbackEvent(from: SharedStore.countdownEvents).map(CountdownEventEntity.init(event:))
    }
}

struct CountdownEventWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widget.countdown.configuration.title"
    static let description = IntentDescription("widget.countdown.description")

    @Parameter(title: "widget.countdown.configuration.event")
    var event: CountdownEventEntity?
}

// MARK: - Countdown Widget

struct CountdownEventProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CountdownEventEntry {
        CountdownEventEntry(
            date: .now,
            event: SharedCountdownEvent(
                id: UUID(),
                title: String(localized: "widget.countdown.placeholder.title"),
                date: Calendar.current.date(byAdding: .day, value: 227, to: .now) ?? .now,
                includesTime: false
            )
        )
    }

    func snapshot(for configuration: CountdownEventWidgetIntent, in context: Context) async -> CountdownEventEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: CountdownEventWidgetIntent, in context: Context) async -> Timeline<CountdownEventEntry> {
        let entry = entry(for: configuration)
        let nextUpdate = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? .now.addingTimeInterval(3600)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func entry(for configuration: CountdownEventWidgetIntent) -> CountdownEventEntry {
        let events = SharedStore.countdownEvents
        let selected = configuration.event.flatMap { entity in
            events.first(where: { $0.id == entity.id })
        }
        return CountdownEventEntry(date: .now, event: selected ?? Self.fallbackEvent(from: events))
    }

    static func fallbackEvent(from events: [SharedCountdownEvent], now: Date = .now) -> SharedCountdownEvent? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let futureOrToday = events
            .filter { calendar.startOfDay(for: $0.date) >= today }
            .sorted(by: { $0.date < $1.date })
        if let event = futureOrToday.first {
            return event
        }
        return events.sorted(by: { $0.date > $1.date }).first
    }
}

struct CountdownEventEntry: TimelineEntry {
    let date: Date
    let event: SharedCountdownEvent?
}

struct CountdownEventWidgetEntryView: View {
    var entry: CountdownEventProvider.Entry

    var body: some View {
        Link(destination: URL(string: "chrona://countdown")!) {
            if let event = entry.event {
                CountdownEventContent(event: event, now: entry.date)
            } else {
                CountdownEventEmptyContent(date: entry.date)
            }
        }
    }
}

private struct CountdownEventContent: View {
    let event: SharedCountdownEvent
    let now: Date
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    private var state: CountdownWidgetState {
        CountdownWidgetState(eventDate: event.date, now: now)
    }

    private var valueColor: Color {
        widgetRenderingMode == .fullColor ? state.valueColor : .primary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(WidgetFormatters.date.string(from: event.date))
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)

            Color.clear.frame(height: 14)

            if case .today = state {
                Text(String(localized: "widget.countdown.today.label"))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(valueColor)
                    .widgetAccentable()
            } else {
                WidgetNumberUnit(value: state.displayDays, unitKey: "time.days", numberSize: 32)
                    .foregroundStyle(valueColor)
                    .widgetAccentable()
            }

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.body.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(state.statusText)
                    .font(.footnote.weight(.regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct CountdownEventEmptyContent: View {
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(WidgetFormatters.date.string(from: date))
                .font(.caption.weight(.bold))

            Color.clear.frame(height: 14)

            WidgetNumberUnit(value: 0, unitKey: "time.days", numberSize: 32)
                .foregroundStyle(.secondary)
                .widgetAccentable()

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(String(localized: "widget.countdown.empty.title"))
                    .font(.body.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(String(localized: "widget.countdown.empty.message"))
                    .font(.footnote.weight(.regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private enum CountdownWidgetState {
    case future(Int)
    case past(Int)
    case today

    init(eventDate: Date, now: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let eventDay = calendar.startOfDay(for: eventDate)
        let delta = calendar.dateComponents([.day], from: today, to: eventDay).day ?? 0
        if delta > 0 {
            self = .future(delta)
        } else if delta < 0 {
            self = .past(abs(delta))
        } else {
            self = .today
        }
    }

    var displayDays: Int {
        switch self {
        case .future(let days), .past(let days):
            return days
        case .today:
            return 0
        }
    }

    var valueColor: Color {
        switch self {
        case .future:
            return .blue
        case .past:
            return .secondary
        case .today:
            return Color("AccentColor")
        }
    }

    var statusText: String {
        switch self {
        case .future:
            return String(localized: "widget.countdown.status.future")
        case .past:
            return String(localized: "widget.countdown.status.past")
        case .today:
            return String(localized: "widget.countdown.status.today")
        }
    }
}

struct CountdownEventWidget: Widget {
    let kind: String = ChronaWidgetKind.countdownEvent

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: CountdownEventWidgetIntent.self, provider: CountdownEventProvider()) { entry in
            CountdownEventWidgetEntryView(entry: entry)
                .chronaWidgetBackground()
        }
        .configurationDisplayName(String(localized: "widget.countdown"))
        .description(String(localized: "widget.countdown.description"))
        .supportedFamilies([.systemSmall])
        .containerBackgroundRemovable(true)
    }
}

// MARK: - Month Heatmap Widget

struct MonthHeatmapProvider: TimelineProvider {
    func placeholder(in context: Context) -> MonthHeatmapEntry {
        MonthHeatmapEntry(date: .now, durations: sampleDurations())
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthHeatmapEntry) -> Void) {
        completion(MonthHeatmapEntry(date: .now, durations: SharedStore.monthlyFocusDurations))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthHeatmapEntry>) -> Void) {
        let entry = MonthHeatmapEntry(date: .now, durations: SharedStore.monthlyFocusDurations)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func sampleDurations() -> [SharedDailyFocusDuration] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<12).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return SharedDailyFocusDuration(day: day, duration: TimeInterval((offset % 4 + 1) * 20 * 60))
        }
    }
}

struct MonthHeatmapEntry: TimelineEntry {
    let date: Date
    let durations: [SharedDailyFocusDuration]
}

struct MonthHeatmapWidgetEntryView: View {
    var entry: MonthHeatmapProvider.Entry
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    private var totalDuration: TimeInterval {
        entry.durations.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        Link(destination: URL(string: "chrona://statistics")!) {
            VStack(alignment: .leading, spacing: 1) {
                Text(String(localized: "widget.monthHeatmap.title"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.leading, 2)

                VStack(alignment: .leading, spacing: 3) {
                    heatmapTotalView
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .widgetAccentable()

                    weekdayHeadersRow

                    heatmapGrid
                        .widgetAccentable()
                }

            }
            .padding(.horizontal, 12)

            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var totalMinutes: Int {
        max(0, Int(totalDuration / 60))
    }

    private var totalTimeParts: (hours: Int, minutes: Int) {
        (totalMinutes / 60, totalMinutes % 60)
    }

    private var heatmapTotalView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            if totalTimeParts.hours > 0 {
                heatmapNumberUnit(value: totalTimeParts.hours, unitKey: "time.hours")
            }
            heatmapNumberUnit(value: totalTimeParts.minutes, unitKey: "time.minutes")
        }
        .lineLimit(1)
        .minimumScaleFactor(0.65)
    }

    private func heatmapNumberUnit(value: Int, unitKey: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text("\(value)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(String(localized: String.LocalizationValue(unitKey)))
                .font(.system(size: 8.5, weight: .light))
                .foregroundStyle(secondaryInk)
        }
    }

    private var weekdayHeadersRow: some View {
        LazyVGrid(columns: gridColumns, spacing: 0) {
            ForEach(weekdayHeaders, id: \.self) { header in
                Text(header)
                    .font(.system(size: 8.5, weight: .light))
                    .foregroundStyle(secondaryInk)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var heatmapGrid: some View {
        let durations = durationsByDay
        return LazyVGrid(columns: gridColumns, spacing: 3) {
            ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    heatmapCell(day: day, durations: durations)
                } else {
                    Color.clear
                        .frame(width: 14, height: 14)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func heatmapCell(day: Date, durations: [Date: TimeInterval]) -> some View {
        let duration = durations[Calendar.current.startOfDay(for: day)] ?? 0
        let isToday = Calendar.current.isDateInToday(day)

        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(heatmapColor(for: duration))
            .frame(width: 14, height: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(isToday ? Color("AccentColor") : .clear, lineWidth: 1.4)
            )
            .frame(maxWidth: .infinity)
    }

    private var durationsByDay: [Date: TimeInterval] {
        Dictionary(uniqueKeysWithValues: entry.durations.map {
            (Calendar.current.startOfDay(for: $0.day), $0.duration)
        })
    }

    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: entry.date)) ?? entry.date
        let range = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<2
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingPadding = (firstWeekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingPadding)
        for day in 1...range.count {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: monthStart))
        }
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    private var weekdayHeaders: [String] {
        ["一", "二", "三", "四", "五", "六", "日"]
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    }

    private var secondaryInk: Color {
        if widgetRenderingMode != .fullColor {
            return .secondary
        }
        return Color.secondary.opacity(colorScheme == .dark ? 0.56 : 0.42)
    }

    private func heatmapColor(for duration: TimeInterval) -> Color {
        if widgetRenderingMode != .fullColor {
            return duration > 0 ? .primary.opacity(0.82) : .secondary.opacity(0.18)
        }
        guard duration > 0 else {
            return colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.05)
        }
        let hours = duration / 3600
        switch hours {
        case 0..<1:  return Color("AccentColor").opacity(0.18)
        case 1..<2:  return Color("AccentColor").opacity(0.33)
        case 2..<3:  return Color("AccentColor").opacity(0.50)
        case 3..<5:  return Color("AccentColor").opacity(0.70)
        default:      return Color("AccentColor") // 全饱和强调色
        }
    }
}

struct MonthHeatmapWidget: Widget {
    let kind: String = ChronaWidgetKind.monthHeatmap

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonthHeatmapProvider()) { entry in
            MonthHeatmapWidgetEntryView(entry: entry)
                .chronaWidgetBackground()
        }
        .configurationDisplayName(String(localized: "widget.monthHeatmap"))
        .description(String(localized: "widget.monthHeatmap.description"))
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
    }
}
