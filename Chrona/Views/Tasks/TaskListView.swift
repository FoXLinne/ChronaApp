import SwiftUI

private struct TaskEditorRoute: Identifiable {
    enum Mode { case add; case edit(TaskItem) }
    let id = UUID()
    let mode: Mode
    static func add() -> TaskEditorRoute { TaskEditorRoute(mode: .add) }
    static func edit(_ task: TaskItem) -> TaskEditorRoute { TaskEditorRoute(mode: .edit(task)) }
    var task: TaskItem? { switch mode { case .add: return nil; case .edit(let t): return t } }
}

struct TaskListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appModel: AppViewModel
    @Namespace private var cardNamespace

    @State private var editMode: EditMode = .inactive
    @State private var detailTask: TaskItem?
    @State private var editorRoute: TaskEditorRoute?
    @State private var pendingDeletion: TaskItem?
    @State private var searchText = ""
    @State private var selectedModes = Set(FocusMode.allCases)

    var body: some View {
        NavigationStack {
            ZStack {
                if colorScheme == .light {
                    PageBackground(seed: "mint").ignoresSafeArea()
                }

                taskList
            }
            .navigationTitle(String(localized: "tab.tasks"))
            .searchable(text: $searchText, placement: .toolbar, prompt: String(localized: "task.search"))
            .toolbar {
                if editMode == .active {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation {
                                editMode = .inactive
                            }
                        } label: {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                guardTaskMutation {
                                    withAnimation {
                                        editMode = .active
                                    }
                                }
                            } label: {
                                Label(String(localized: "common.edit"), systemImage: "pencil")
                            }

                            Menu {
                                ForEach(FocusMode.allCases) { mode in
                                    Toggle(isOn: binding(for: mode)) { Text(mode.label) }
                                }
                            } label: {
                                Label(String(localized: "task.filter"), systemImage: "line.3.horizontal.decrease.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }

                        Button {
                            guardTaskMutation {
                                editorRoute = .add()
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(String(localized: "task.new"))
                    }
                }
            }
            .sheet(item: $editorRoute) { route in
                TaskEditorView(task: route.task) { updatedTask in
                    guardTaskMutation {
                        if let originalTask = route.task {
                            var copy = updatedTask; copy.id = originalTask.id; copy.order = originalTask.order
                            appModel.updateTask(copy)
                        } else {
                            appModel.createTask(title: updatedTask.title, mode: updatedTask.mode,
                                presetID: updatedTask.pomodoroPresetID, countdownDuration: updatedTask.countdownDuration,
                                backgroundName: updatedTask.backgroundName)
                        }
                    }
                }
            }
            .alert(item: $pendingDeletion) { task in
                Alert(
                    title: Text(String(localized: "task.delete.confirm.title")),
                    message: Text(String(format: String(localized: "task.delete.confirm.message"), task.title)),
                    primaryButton: .destructive(Text(String(localized: "common.delete"))) {
                        guardTaskMutation {
                            appModel.deleteTask(id: task.id)
                        }
                    },
                    secondaryButton: .cancel(Text(String(localized: "common.cancel")))
                )
            }
            .navigationDestination(item: $detailTask) { task in
                TaskCardDetailView(task: task)
                    .navigationTransition(.zoom(sourceID: task.id, in: cardNamespace))
            }
        }
    }

    private var taskList: some View {
        List {
            if listTasks.isEmpty {
                Section {
                    emptyView
                        .listRowInsets(EdgeInsets(top: 80, leading: 16, bottom: 80, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            } else if editMode == .active {
                Section {
                    ForEach(appModel.sortedTasks) { task in
                        taskRow(task, isEditing: true)
                    }
                    .onDelete(perform: handleDelete)
                    .onMove(perform: handleMove)
                }
            } else {
                Section {
                    ForEach(displayTasks) { task in
                        taskRow(task)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
    }

    private var listTasks: [TaskItem] {
        editMode == .active ? appModel.sortedTasks : displayTasks
    }

    private var displayTasks: [TaskItem] {
        let kw = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return appModel.sortedTasks.filter { task in
            guard selectedModes.contains(task.mode) else { return false }
            guard !kw.isEmpty else { return true }
            return task.title.lowercased().contains(kw)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Text(emptyTitle).font(.title3.bold())
            Text(emptyMessage).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if appModel.sortedTasks.isEmpty {
                Button {
                    guardTaskMutation {
                        editorRoute = .add()
                    }
                } label: {
                    Label(String(localized: "task.new"), systemImage: "plus")
                }.buttonStyle(.glass(.regular.tint(.accentColor))).padding(.top, 4)
            }
        }.frame(maxWidth: .infinity).padding(.horizontal)
    }

    private func taskRow(_ task: TaskItem, isEditing: Bool = false) -> some View {
        TaskGlassCard(
            task: task,
            namespace: cardNamespace,
            isEditing: isEditing,
            onOpen: {
                detailTask = task
            },
            onEdit: {
                guardTaskMutation {
                    editorRoute = .edit(task)
                }
            },
            onDelete: {
                guardTaskMutation {
                    pendingDeletion = task
                }
            }
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isTaskMutationLocked {
                Button(role: .destructive) {
                    pendingDeletion = task
                } label: {
                    Label(String(localized: "common.delete"), systemImage: "trash")
                }

                Button {
                    editorRoute = .edit(task)
                } label: {
                    Label(String(localized: "common.edit"), systemImage: "square.and.pencil")
                }
                .tint(.accentColor)
            }
        }
    }

    private var emptyTitle: String { appModel.sortedTasks.isEmpty ? String(localized: "task.empty.title") : String(localized: "task.noMatches.title") }
    private var emptyMessage: String { appModel.sortedTasks.isEmpty ? String(localized: "task.empty.message") : String(localized: "task.noMatches.message") }

    private func binding(for mode: FocusMode) -> Binding<Bool> {
        Binding { selectedModes.contains(mode) } set: { v in
            if v { selectedModes.insert(mode) } else if selectedModes.count > 1 { selectedModes.remove(mode) }
        }
    }

    private func handleMove(from source: IndexSet, to destination: Int) {
        guardTaskMutation {
            appModel.moveTasks(from: source, to: destination)
        }
    }

    private func handleDelete(_ offsets: IndexSet) {
        guardTaskMutation {
            appModel.deleteTasks(at: offsets)
        }
    }

    private var isTaskMutationLocked: Bool {
        appModel.activeSession != nil
    }

    private func guardTaskMutation(_ action: () -> Void) {
        guard !isTaskMutationLocked else {
            appModel.showGlobalNotice(String(localized: "task.lockedWhileRunning"))
            return
        }
        action()
    }
}

// MARK: - Glass Card

private struct TaskGlassCard: View {
    @EnvironmentObject private var appModel: AppViewModel
    let task: TaskItem
    let namespace: Namespace.ID
    let isEditing: Bool
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Group {
            if isEditing {
                cardBody
            } else {
                cardBody
                    .matchedTransitionSource(id: task.id, in: namespace)
            }
        }
        .contextMenu {
            if !isEditing {
                Button(String(localized: "task.start")) {
                    withAnimation(.smooth) {
                        _ = appModel.startTask(task)
                    }
                }
            }
            Button(String(localized: "common.edit")) { onEdit() }
            Divider()
            Button(String(localized: "common.delete"), role: .destructive) { onDelete() }
        }
    }

    private var cardBody: some View {
        HStack(spacing: 14) {
            leadingContent

            if !isEditing {
                ZStack(alignment: .bottomTrailing) {
                    Button {
                        withAnimation(.smooth) {
                            _ = appModel.startTask(task)
                        }
                    } label: {
                        Text(controlLabel).font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(controlTint)
                    .padding(.horizontal, 12).padding(.vertical, 6)

                    if completedCount > 0 {
                        Text(verbatim: "\(completedCount)").font(.caption2.bold())
                            .padding(6).background(.thinMaterial, in: Circle()).offset(x: 10, y: 10)
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var leadingContent: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(LinearGradient(colors: ThemePalette.previewColors(for: task.backgroundName), startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 48, height: 48)
                .overlay { Image(systemName: task.mode.symbol).font(.system(size: 24, weight: .bold)).foregroundStyle(.white) }

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(.headline, design: .rounded))
                    .strikethrough(isCompleted && appModel.settings.strikethroughCompletedTask)

                HStack(spacing: 4) {
                    Text(task.mode.label)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)

                    if let detail = subtitleDetail {
                        Text(detail)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing {
                onOpen()
            }
        }
    }


    private var completedCount: Int { appModel.completedCountToday(for: task) }
    private var isCompleted: Bool { completedCount > 0 }
    private var subtitleDetail: String? {
        switch task.mode {
        case .pomodoro: let p = task.pomodoroPreset; return "\(Int(p.workDuration/60))/\(Int(p.breakDuration/60))"
        case .stopwatch: return nil
        case .countdown: return Duration.seconds(task.countdownDuration).formatted(.time(pattern: .hourMinuteSecond))
        }
    }
    private var controlLabel: String {
        appModel.activeTask?.id == task.id ? String(localized: "task.running") : String(localized: "task.start")
    }
    private var controlTint: Color { appModel.activeTask?.id == task.id ? .red : .accentColor }
}

struct TaskCardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appModel: AppViewModel
    let task: TaskItem

    @State private var showEditor = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    expandedCard
                    actionRow
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditor) {
            TaskEditorView(task: task) { updatedTask in
                guardTaskMutation {
                    var copy = updatedTask; copy.id = task.id; copy.order = task.order; appModel.updateTask(copy)
                }
            }
        }
        .alert(String(localized: "task.delete.confirm.title"), isPresented: $showDeleteConfirm) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "common.delete"), role: .destructive) {
                guardTaskMutation {
                    appModel.deleteTask(id: task.id); dismiss()
                }
            }
        } message: {
            Text(String(format: String(localized: "task.delete.confirm.message"), task.title))
        }
    }

    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 16) {
                Circle()
                    .fill(LinearGradient(colors: ThemePalette.previewColors(for: task.backgroundName), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: task.mode.symbol)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)

                    Text(task.mode.label)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)

                    if let detail = taskConfigurationText {
                        Text(detail)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: 0)
            }

            Divider()
                .opacity(0.45)

            statsBlock
            heatmapBlock
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
    }

    private var statsBlock: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "task.detail.sessionCount"))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("\(totalCount)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .frame(height: 48)
                .padding(.horizontal, 14)

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "task.detail.totalDuration"))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)

                durationText(totalDuration, numberSize: 30, unitSize: 13)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var heatmapBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "task.detail.heatmapSection"))
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)

            HStack(spacing: 6) {
                ForEach(weekDays, id: \.self) { day in
                    let duration = dailyDurations[day] ?? 0
                    let today = Calendar.current.isDateInToday(day)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(heatmapColor(for: duration))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(today ? Color.accentColor : Color.secondary.opacity(0.12), lineWidth: today ? 2 : 1)
                        }
                        .frame(height: 42)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                guardTaskMutation {
                    showEditor = true
                }
            } label: {
                Label(String(localized: "common.edit"), systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass(.regular.tint(.accentColor)))

            Button(role: .destructive) {
                guardTaskMutation {
                    showDeleteConfirm = true
                }
            } label: {
                Label(String(localized: "common.delete"), systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass(.regular.tint(.red)))
        }
    }

    @ViewBuilder
    private func durationText(_ value: TimeInterval, numberSize: CGFloat, unitSize: CGFloat) -> some View {
        let parts = durationParts(value)
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            ForEach(parts, id: \.unit) { part in
                Text("\(part.value)")
                    .font(.system(size: numberSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(String(localized: String.LocalizationValue(part.unit)))
                    .font(.system(size: unitSize, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var taskConfigurationText: String? {
        switch task.mode {
        case .pomodoro:
            let preset = task.pomodoroPreset
            return "\(Int(preset.workDuration / 60)) \(String(localized: "time.minutes")) / \(Int(preset.breakDuration / 60)) \(String(localized: "time.minutes"))"
        case .stopwatch:
            return nil
        case .countdown:
            return durationParts(task.countdownDuration)
                .map { "\($0.value) \(String(localized: String.LocalizationValue($0.unit)))" }
                .joined(separator: " ")
        }
    }

    private func durationParts(_ value: TimeInterval) -> [(value: Int, unit: String)] {
        let seconds = max(0, Int(value.rounded()))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return [(hours, "time.hours"), (minutes, "time.minutes")]
        }
        if minutes > 0 {
            return [(minutes, "time.minutes")]
        }
        return [(remainingSeconds, "time.seconds")]
    }

    private var weekDays: [Date] {
        let cal = Calendar.current; let today = cal.startOfDay(for: .now)
        var c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today); c.weekday = 2
        let mon = cal.date(from: c) ?? today
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: mon) }
    }
    private var dailyDurations: [Date: TimeInterval] {
        let sessions = appModel.sessions.filter { $0.taskID == task.id }
        var result: [Date: TimeInterval] = [:]; let cal = Calendar.current
        for s in sessions { let d = cal.startOfDay(for: s.endedAt); result[d, default: 0] += s.focusedDuration }
        return result
    }
    private var totalCount: Int { appModel.sessions.filter { $0.taskID == task.id }.count }
    private var totalDuration: TimeInterval { appModel.sessions.filter { $0.taskID == task.id }.reduce(0) { $0 + $1.focusedDuration } }
    private var isTaskMutationLocked: Bool { appModel.activeSession != nil }
    private func guardTaskMutation(_ action: () -> Void) {
        guard !isTaskMutationLocked else {
            appModel.showGlobalNotice(String(localized: "task.lockedWhileRunning"))
            return
        }
        action()
    }
    private func heatmapColor(for duration: TimeInterval) -> Color {
        guard duration > 0 else { return Color(uiColor: .secondarySystemGroupedBackground) }
        let hours = duration / 3600
        switch hours {
        case 0..<1:  return Color.accentColor.opacity(0.15)
        case 1..<2:  return Color.accentColor.opacity(0.30)
        case 2..<3:  return Color.accentColor.opacity(0.50)
        case 3..<5:  return Color.accentColor.opacity(0.72)
        default:      return Color.accentColor
        }
    }
}

#Preview { TaskListView().environmentObject(AppViewModel()) }
