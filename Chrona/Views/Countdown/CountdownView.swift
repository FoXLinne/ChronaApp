import SwiftUI

struct CountdownView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appModel: AppViewModel
    @State private var editorRoute: CountdownEditorRoute?
    @State private var pendingDeletion: CountdownEvent?
    @State private var searchText = ""
    @State private var selectedScopes = Set(CountdownScope.allCases)

    var body: some View {
        NavigationStack {
            List {
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

                if filteredFutureEvents.isEmpty && filteredPastEvents.isEmpty {
                    Section {
                        Text(String(localized: "countdown.empty"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(String(localized: "tab.countdown"))
            .scrollContentBackground(colorScheme == .light ? .hidden : .automatic)
            .background {
                if colorScheme == .light {
                    PageBackground(seed: "lavender")
                }
            }
            .searchable(
                text: $searchText,
                placement: .toolbar,
                prompt: String(localized: "countdown.search")
            )
            .searchToolbarBehavior(.minimize)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        ForEach(CountdownScope.allCases) { scope in
                            Toggle(isOn: binding(for: scope)) {
                                Text(scopeTitle(scope))
                            }
                        }
                    } label: {
                        Label(String(localized: "countdown.filter"), systemImage: "line.3.horizontal.decrease.circle")
                    }

                    Button {
                        editorRoute = .add()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "countdown.add"))
                }
            }
            .sheet(item: $editorRoute) { route in
                CountdownEditorView(event: route.event) { updated in
                    if route.event == nil {
                        appModel.addCountdownEvent(title: updated.title, date: updated.date)
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
                } label: {
                    Label(String(localized: "common.delete"), systemImage: "trash")
                }

                Button {
                    editorRoute = .edit(event)
                } label: {
                    Label(String(localized: "common.edit"), systemImage: "square.and.pencil")
                }
                .tint(.accentColor)
            }
    }

    private var filteredFutureEvents: [CountdownEvent] {
        filteredEvents(for: .future)
    }

    private var filteredPastEvents: [CountdownEvent] {
        filteredEvents(for: .past)
    }

    private func filteredEvents(for scope: CountdownScope) -> [CountdownEvent] {
        let base = scope == .future ? appModel.futureEvents : appModel.pastEvents
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { return base }
        return base.filter { $0.title.lowercased().contains(keyword) }
    }

    private func handleDeleteFuture(_ offsets: IndexSet) {
        let ids = offsets.compactMap { index in
            filteredFutureEvents.indices.contains(index) ? filteredFutureEvents[index].id : nil
        }
        ids.forEach(appModel.deleteCountdownEvent(id:))
    }

    private func handleDeletePast(_ offsets: IndexSet) {
        let ids = offsets.compactMap { index in
            filteredPastEvents.indices.contains(index) ? filteredPastEvents[index].id : nil
        }
        ids.forEach(appModel.deleteCountdownEvent(id:))
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
        case .future:
            return String(localized: "countdown.future")
        case .past:
            return String(localized: "countdown.past")
        }
    }
}

private enum CountdownScope: String, CaseIterable, Identifiable {
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

    let event: CountdownEvent?
    let onSave: (CountdownEvent) -> Void

    init(event: CountdownEvent?, onSave: @escaping (CountdownEvent) -> Void) {
        self.event = event
        self.onSave = onSave
        _title = State(initialValue: event?.title ?? "")
        _date = State(initialValue: event?.date ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(String(localized: "countdown.name"), text: $title)
                DatePicker(String(localized: "countdown.date"), selection: $date, displayedComponents: [.date])
            }
            .navigationTitle(event == nil ? String(localized: "countdown.add") : String(localized: "countdown.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .tint(.accentColor)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        var output = event ?? CountdownEvent(title: title, date: date)
        output.title = title
        output.date = date
        onSave(output)
        dismiss()
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
                Text(event.date.formatted(date: .abbreviated, time: .omitted))
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
        if future {
            return max(days, 0)
        }
        return abs(days)
    }

    private var prefixText: String {
        future
            ? String(localized: "countdown.inDays.prefix")
            : String(localized: "countdown.pastDays.prefix")
    }

    private var suffixText: String {
        String(localized: "countdown.days.suffix")
    }

    private var dayLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(prefixText)
                .font(.footnote.weight(.semibold))

            Text("\(dayDelta)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(suffixText)
                .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(future ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
    }
}

#Preview {
    CountdownView()
        .environmentObject(AppViewModel())
}
