import SwiftUI

struct TaskListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appModel: AppViewModel
    @State private var editMode: EditMode = .inactive

    @State private var editorRoute: TaskEditorRoute?
    @State private var pendingDeletion: TaskItem?
    @State private var searchText = ""
    @State private var selectedModes = Set(FocusMode.allCases)

    // Controls vertical spacing between task sections.
    private let taskSectionSpacing: CGFloat = 16

    var body: some View {
        NavigationStack {
            List {
                if listTasks.isEmpty {
                    Section {
                        taskEmptyRow
                    }
                } else if editMode == .active {
                    // 编辑模式：显示完整任务列表，保留系统删除/排序和同一套左滑操作。
                    Section {
                        ForEach(listTasks) { task in
                            taskRow(task, isEditing: true)
                        }
                        .onDelete(perform: handleDelete)
                        .onMove(perform: handleMove)
                    }
                } else {
                    // 普通模式：每个任务是独立的 Section 卡片
                    ForEach(listTasks) { task in
                        Section {
                            taskRow(task)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(colorScheme == .light ? .hidden : .automatic)
            .background {
                if colorScheme == .light {
                    PageBackground(seed: "mint")
                }
            }
            .environment(\.editMode, $editMode)
            .listSectionSpacing(taskSectionSpacing)
            .navigationTitle(String(localized: "tab.tasks"))
            .searchable(
                text: $searchText,
                placement: .toolbar,
                prompt: String(localized: "task.search")
            )
            .searchToolbarBehavior(.minimize)
            .toolbar {
                // 编辑模式：右上角只显示「完成」按钮，方便一键退出
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
                        // .buttonBorderShape(.circle)
                        // .tint(.accentColor)
                    }
                } else {
                    // 普通模式：ellipsis 菜单 + 快捷添加按钮
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                // 计时进行时禁止进入编辑模式
                                guard !isTaskMutationLocked else {
                                    appModel.showGlobalNotice(String(localized: "task.lockedWhileRunning"))
                                    return
                                }
                                withAnimation {
                                    editMode = .active
                                }
                            } label: {
                                Label(String(localized: "common.edit"), systemImage: "pencil")
                            }

                            Menu {
                                ForEach(FocusMode.allCases) { mode in
                                    Toggle(isOn: binding(for: mode)) {
                                        Text(modeTitle(mode))
                                    }
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
                    if let originalTask = route.task {
                        var copy = updatedTask
                        copy.id = originalTask.id
                        copy.order = originalTask.order
                        appModel.updateTask(copy)
                    } else {
                        appModel.createTask(
                            title: updatedTask.title,
                            mode: updatedTask.mode,
                            presetID: updatedTask.pomodoroPresetID,
                            countdownDuration: updatedTask.countdownDuration,
                            backgroundName: updatedTask.backgroundName
                        )
                    }
                }
            }
            .alert(item: $pendingDeletion) { task in
                Alert(
                    title: Text(String(localized: "task.delete.confirm.title")),
                    message: Text(String(format: String(localized: "task.delete.confirm.message"), task.title)),
                    primaryButton: .destructive(Text(String(localized: "common.delete"))) {
                        if let index = appModel.sortedTasks.firstIndex(where: { $0.id == task.id }) {
                            appModel.deleteTasks(at: IndexSet(integer: index))
                        }
                    },
                    secondaryButton: .cancel(Text(String(localized: "common.cancel")))
                )
            }
        }
    }

    private var isTaskMutationLocked: Bool {
        appModel.activeSession != nil
    }

    private var taskEmptyRow: some View {
        VStack(alignment: .center, spacing: 12) {
            Spacer()
            
            Text(emptyTitle)
                .font(.title3.bold())
            
            Text(emptyMessage)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal)
    }

    private func taskRow(_ task: TaskItem, isEditing: Bool = false) -> some View {
        TaskRow(task: task, isEditing: isEditing) {
            _ = appModel.startTask(task)
        }
        .contextMenu {
            Button(String(localized: "common.edit")) {
                guardTaskMutation {
                    editorRoute = .edit(task)
                }
            }
            if !isEditing {
                Button(String(localized: "task.start")) {
                    _ = appModel.startTask(task)
                }
            }
            Button(String(localized: "common.delete"), role: .destructive) {
                guardTaskMutation {
                    pendingDeletion = task
                }
            }
        }
        .swipeActions(edge: .trailing) {
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

    private var emptyTitle: String {
        appModel.sortedTasks.isEmpty
            ? String(localized: "task.empty.title")
            : String(localized: "task.noMatches.title")
    }

    private var emptyMessage: String {
        appModel.sortedTasks.isEmpty
            ? String(localized: "task.empty.message")
            : String(localized: "task.noMatches.message")
    }

    // 编辑模式下显示完整任务列表，避免过滤导致索引错位崩溃
    private var listTasks: [TaskItem] {
        editMode == .active ? appModel.sortedTasks : displayTasks
    }

    private var displayTasks: [TaskItem] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return appModel.sortedTasks.filter { task in
            let modeMatched = selectedModes.contains(task.mode)
            guard modeMatched else { return false }
            guard !keyword.isEmpty else { return true }
            return task.title.lowercased().contains(keyword)
        }
    }

    // 拖拽排序：始终操作完整列表，确保 index 正确映射
    private func handleMove(from source: IndexSet, to destination: Int) {
        appModel.moveTasks(from: source, to: destination)
    }

    private func handleDelete(_ offsets: IndexSet) {
        guardTaskMutation {
            appModel.deleteTasks(at: offsets)
        }
    }

    private func binding(for mode: FocusMode) -> Binding<Bool> {
        Binding {
            selectedModes.contains(mode)
        } set: { enabled in
            if enabled {
                selectedModes.insert(mode)
            } else if selectedModes.count > 1 {
                selectedModes.remove(mode)
            }
        }
    }

    private func modeTitle(_ mode: FocusMode) -> String {
        switch mode {
        case .pomodoro:
            return String(localized: "mode.pomodoro")
        case .stopwatch:
            return String(localized: "mode.stopwatch")
        case .countdown:
            return String(localized: "mode.countdown")
        }
    }

    private func guardTaskMutation(_ action: () -> Void) {
        guard !isTaskMutationLocked else {
            appModel.showGlobalNotice(String(localized: "task.lockedWhileRunning"))
            return
        }
        action()
    }
}

private struct TaskEditorRoute: Identifiable {
    enum Mode {
        case add
        case edit(TaskItem)
    }

    let id = UUID()
    let mode: Mode

    static func add() -> TaskEditorRoute {
        TaskEditorRoute(mode: .add)
    }

    static func edit(_ task: TaskItem) -> TaskEditorRoute {
        TaskEditorRoute(mode: .edit(task))
    }

    var task: TaskItem? {
        switch mode {
        case .add:
            return nil
        case .edit(let task):
            return task
        }
    }
}

private struct TaskRow: View {
    @EnvironmentObject private var appModel: AppViewModel
    let task: TaskItem
    let isEditing: Bool
    let onStart: () -> Void

    init(task: TaskItem, isEditing: Bool = false, onStart: @escaping () -> Void) {
        self.task = task
        self.isEditing = isEditing
        self.onStart = onStart
    }

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(LinearGradient(colors: previewColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(isCompletedToday && appModel.settings.strikethroughCompletedTask ? .secondary : .primary)
                    .strikethrough(isCompletedToday && appModel.settings.strikethroughCompletedTask)
                HStack(spacing: 4) {
                    Text(modeLabel)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let detail = subtitleDetail {
                        Text(detail)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if !isEditing {
                ZStack(alignment: .bottomTrailing) {
                    Button(action: onStart) {
                        Text(controlTitle)
                            .font(.headline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.glass(.regular.tint(controlTint)))
                    if completedCount > 0 {
                        Text(verbatim: "\(completedCount)")
                            .font(.caption2.bold())
                            .padding(6)
                            .background(.thinMaterial, in: Circle())
                            .offset(x: 10, y: 10)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .opacity(isCompletedToday && appModel.settings.strikethroughCompletedTask ? 0.6 : 1)
    }

    private var completedCount: Int {
        appModel.completedCountToday(for: task)
    }

    private var isCompletedToday: Bool {
        completedCount > 0
    }

    private var symbol: String {
        switch task.mode {
        case .pomodoro: return "timer"
        case .stopwatch: return "stopwatch"
        case .countdown: return "hourglass"
        }
    }

    private var modeLabel: String {
        switch task.mode {
        case .pomodoro:
            return String(localized: "mode.pomodoro")
        case .stopwatch:
            return String(localized: "mode.stopwatch")
        case .countdown:
            return String(localized: "mode.countdown")
        }
    }

    private var subtitleDetail: String? {
        switch task.mode {
        case .pomodoro:
            let preset = task.pomodoroPreset
            return "\(Int(preset.workDuration / 60))/\(Int(preset.breakDuration / 60))"
        case .stopwatch:
            return nil
        case .countdown:
            return Duration.seconds(task.countdownDuration).formatted(.time(pattern: .hourMinuteSecond))
        }
    }

    private var controlTitle: String {
        appModel.activeTask?.id == task.id ? String(localized: "task.running") : String(localized: "task.start")
    }

    private var controlTint: Color {
        appModel.activeTask?.id == task.id ? .red : .accentColor
    }

    private var previewColors: [Color] {
        ThemePalette.previewColors(for: task.backgroundName)
    }
}

#Preview {
    TaskListView()
        // 必须加上这一行，预览才能跑起来
        .environmentObject(AppViewModel())
}
