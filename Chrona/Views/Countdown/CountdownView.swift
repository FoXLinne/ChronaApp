import SwiftUI

struct CountdownView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appModel: AppViewModel
    @State private var editMode: EditMode = .inactive
    @State private var editorRoute: CountdownEditorRoute?
    @State private var pendingDeletion: CountdownEvent?
    @State private var searchText = ""
    @State private var selectedScopes = Set(CountdownScope.allCases)

    var body: some View {
        NavigationStack {
            List {
                if selectedScopes.contains(.today), !filteredTodayEvents.isEmpty {
                    Section {
                        ForEach(filteredTodayEvents) { event in
                            eventRow(event, future: true)
                        }
                        .onDelete(perform: handleDeleteToday)
                    }
                }

                if selectedScopes.contains(.future), !filteredFutureEvents.isEmpty {
                    Section(String(localized: "countdown.future")) {
                        ForEach(filteredFutureEvents) { event in
                            eventRow(event, future: true)
                        }
                        .onDelete(perform: handleDeleteFuture)
                    }
                }

                if selectedScopes.contains(.past), !filteredPastEvents.isEmpty {
                    Section(String(localized: "countdown.past")) {
                        ForEach(filteredPastEvents) { event in
                            eventRow(event, future: false)
                        }
                        .onDelete(perform: handleDeletePast)
                    }
                }

                if filteredTodayEvents.isEmpty && filteredFutureEvents.isEmpty && filteredPastEvents.isEmpty {
                    Section {
                        countdownEmptyRow
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, $editMode)
            .chronaSoftScrollEdgeEffect()
            .navigationTitle(String(localized: "tab.countdown"))
            .toolbarTitleDisplayMode(.inlineLarge)
            .scrollContentBackground(colorScheme == .light ? .hidden : .automatic)
            .background {
                if colorScheme == .light {
                    PageBackground(seed: "lavender")
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: String(localized: "countdown.search")
            )
            .toolbar {
                if editMode == .active {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .confirm) {
                            withAnimation {
                                editMode = .inactive
                            }
                        }
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                withAnimation {
                                    editMode = .active
                                }
                            } label: {
                                Label(String(localized: "common.edit"), systemImage: "pencil")
                            }

                            Menu {
                                ForEach(CountdownScope.allCases) { scope in
                                    Toggle(isOn: binding(for: scope)) {
                                        Text(scopeTitle(scope))
                                    }
                                }
                            } label: {
                                Label(String(localized: "countdown.filter"), systemImage: "line.3.horizontal.decrease.circle")
                            }
                            .menuActionDismissBehavior(.disabled)
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }

                    ToolbarSpacer(.fixed, placement: .topBarTrailing)

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            editorRoute = .add()
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                        .accessibilityLabel(String(localized: "countdown.add"))
                    }
                }
            }
            .sheet(item: $editorRoute) { route in
                CountdownEditorView(event: route.event) { updated in
                    if route.event == nil {
                        appModel.addCountdownEvent(
                            title: updated.title,
                            date: updated.date,
                            includesTime: updated.includesTime,
                            notificationEnabled: updated.notificationEnabled
                        )
                    } else {
                        appModel.updateCountdownEvent(updated)
                    }
                }
            }
            .alert(item: $pendingDeletion) { event in
                Alert(
                    title: Text(String(localized: "countdown.delete.confirm.title")),
                    message: Text(String(format: String(localized: "countdown.delete.confirm.message"), event.title)),
                    primaryButton: .destructive(Text(String(localized: "common.delete"))) {
                        appModel.deleteCountdownEvent(id: event.id)
                    },
                    secondaryButton: .cancel(Text(String(localized: "common.cancel")))
                )
            }
        }
    }

    private func eventRow(_ event: CountdownEvent, future: Bool) -> some View {
        CountdownRow(event: event, future: future)
            .contextMenu {
                Button(String(localized: "common.edit")) {
                    editorRoute = .edit(event)
                }
                Button(String(localized: "common.delete"), role: .destructive) {
                    pendingDeletion = event
                }
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    pendingDeletion = event
                }
                .labelStyle(.iconOnly)

                Button(String(localized: "common.edit"), systemImage: "square.and.pencil") {
                    editorRoute = .edit(event)
                }
                .labelStyle(.iconOnly)
                .tint(.accentColor)
            }
    }

    @ViewBuilder
    private var countdownEmptyRow: some View {
        if appModel.countdownEvents.isEmpty {
            ListEmptyStateView(
                searchText: searchKeyword,
                title: emptyTitle,
                message: emptyMessage,
                action: {
                    editorRoute = .add()
                }
            ) {
                Label(String(localized: "countdown.add"), systemImage: "plus")
            }
        } else {
            ListEmptyStateView(
                searchText: searchKeyword,
                title: emptyTitle,
                message: emptyMessage
            )
        }
    }

    private var emptyTitle: String {
        appModel.countdownEvents.isEmpty
            ? String(localized: "countdown.empty.title")
            : String(localized: "countdown.noMatches.title")
    }

    private var emptyMessage: String {
        appModel.countdownEvents.isEmpty
            ? String(localized: "countdown.empty.message")
            : String(localized: "countdown.noMatches.message")
    }

    private var searchKeyword: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredTodayEvents: [CountdownEvent] {
        filteredEvents(for: .today)
    }

    private var filteredFutureEvents: [CountdownEvent] {
        filteredEvents(for: .future)
    }

    private var filteredPastEvents: [CountdownEvent] {
        filteredEvents(for: .past)
    }

    private func filteredEvents(for scope: CountdownScope) -> [CountdownEvent] {
        let base: [CountdownEvent]
        switch scope {
        case .today: base = appModel.todayEvents
        case .future: base = appModel.futureEvents
        case .past: base = appModel.pastEvents
        }
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { return base }
        return base.filter { $0.title.lowercased().contains(keyword) }
    }

    private func handleDeleteToday(_ offsets: IndexSet) {
        deleteEvents(at: offsets, from: filteredTodayEvents)
    }

    private func handleDeleteFuture(_ offsets: IndexSet) {
        deleteEvents(at: offsets, from: filteredFutureEvents)
    }

    private func handleDeletePast(_ offsets: IndexSet) {
        deleteEvents(at: offsets, from: filteredPastEvents)
    }

    private func deleteEvents(at offsets: IndexSet, from events: [CountdownEvent]) {
        for index in offsets {
            appModel.deleteCountdownEvent(id: events[index].id)
        }
    }

    private func binding(for scope: CountdownScope) -> Binding<Bool> {
        Binding {
            selectedScopes.contains(scope)
        } set: { enabled in
            if enabled {
                selectedScopes.insert(scope)
            } else if selectedScopes.count > 1 {
                selectedScopes.remove(scope)
            }
        }
    }

    private func scopeTitle(_ scope: CountdownScope) -> String {
        switch scope {
        case .today:
            return String(localized: "countdown.today")
        case .future:
            return String(localized: "countdown.future")
        case .past:
            return String(localized: "countdown.past")
        }
    }
}

private enum CountdownScope: String, CaseIterable, Identifiable {
    case today
    case future
    case past

    var id: String { rawValue }
}

private struct CountdownEditorRoute: Identifiable {
    enum Mode {
        case add
        case edit(CountdownEvent)
    }

    let id = UUID()
    let mode: Mode

    static func add() -> CountdownEditorRoute {
        CountdownEditorRoute(mode: .add)
    }

    static func edit(_ event: CountdownEvent) -> CountdownEditorRoute {
        CountdownEditorRoute(mode: .edit(event))
    }

    var event: CountdownEvent? {
        switch mode {
        case .add:
            return nil
        case .edit(let event):
            return event
        }
    }
}

private struct CountdownEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var date: Date
    @State private var includesTime: Bool
    @State private var notificationEnabled: Bool
    @State private var showDiscardChangesConfirm = false

    let event: CountdownEvent?
    let onSave: (CountdownEvent) -> Void

    private let initialTitle: String
    private let initialDate: Date
    private let initialIncludesTime: Bool
    private let initialNotificationEnabled: Bool

    init(event: CountdownEvent?, onSave: @escaping (CountdownEvent) -> Void) {
        self.event = event
        self.onSave = onSave

        let title = event?.title ?? ""
        let date = event?.date ?? .now
        let includesTime = event?.includesTime ?? false
        let notificationEnabled = event?.notificationEnabled ?? false

        initialTitle = title
        initialDate = date
        initialIncludesTime = includesTime
        initialNotificationEnabled = notificationEnabled

        _title = State(initialValue: title)
        _date = State(initialValue: date)
        _includesTime = State(initialValue: includesTime)
        _notificationEnabled = State(initialValue: notificationEnabled)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(String(localized: "countdown.name"), text: $title)

                DatePicker(
                    String(localized: includesTime ? "countdown.dateTime" : "countdown.date"),
                    selection: $date,
                    displayedComponents: includesTime ? [.date, .hourAndMinute] : [.date]
                )

                Toggle(String(localized: "countdown.showTime"), isOn: $includesTime)

                Toggle(String(localized: "countdown.notification"), isOn: $notificationEnabled)
            }
            .chronaSoftScrollEdgeEffect()
            .navigationTitle(event == nil ? String(localized: "countdown.add") : String(localized: "countdown.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        requestDismiss()
                    }
                    .confirmationDialog(
                        String(localized: "editor.discardChanges.title"),
                        isPresented: $showDiscardChangesConfirm,
                        titleVisibility: .visible
                    ) {
                        Button(String(localized: "editor.discardChanges.action"), role: .destructive) {
                            dismiss()
                        }
                        Button(String(localized: "common.cancel"), role: .cancel) {}
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
        }
    }

    private func requestDismiss() {
        guard hasUnsavedChanges else {
            dismiss()
            return
        }
        showDiscardChangesConfirm = true
    }

    private func save() {
        var output = event ?? CountdownEvent(title: title, date: date)
        output.title = title
        output.date = date
        output.includesTime = includesTime
        output.notificationEnabled = notificationEnabled
        onSave(output)
        dismiss()
    }

    private var hasUnsavedChanges: Bool {
        title != initialTitle
            || date != initialDate
            || includesTime != initialIncludesTime
            || notificationEnabled != initialNotificationEnabled
    }
}

private struct CountdownRow: View {
    let event: CountdownEvent
    let future: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                Text(dateText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            dayLabel
        }
        .padding(.vertical, 4)
    }

    private var dayDelta: Int {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: event.date)).day ?? 0
        if dayState == .future {
            return max(days, 0)
        }
        return abs(days)
    }

    private var dayState: CountdownDayState {
        let calendar = Calendar.current
        if calendar.isDateInToday(event.date) {
            return .today
        }
        return future ? .future : .past
    }

    private var dateText: String {
        event.date.formatted(
            date: .abbreviated,
            time: event.includesTime ? .shortened : .omitted
        )
    }

    private var dayTemplate: String {
        switch dayState {
        case .future:
            String(localized: "countdown.days.future.value")
        case .past:
            String(localized: "countdown.days.past.value")
        case .today:
            "" // 不使用模板
        }
    }

    private var dayLabel: some View {
        if dayState == .today {
            return AnyView(
                Text(String(localized: "countdown.days.today.value"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(.tint)
            )
        }

        let parts = dayTemplate.localizedTemplateParts()

        return AnyView(
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if !parts.prefix.isEmpty {
                    Text(parts.prefix)
                        .font(.footnote.weight(.semibold))
                }

                Text(verbatim: "\(dayDelta)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if !parts.suffix.isEmpty {
                    Text(parts.suffix)
                        .font(.footnote.weight(.semibold))
                }
            }
            .foregroundStyle(dayState == .future ? AnyShapeStyle(.blue) : AnyShapeStyle(.secondary))
        )
    }

}

private enum CountdownDayState {
    case future
    case today
    case past
}

#Preview {
    CountdownView()
        .environmentObject(AppViewModel())
}
