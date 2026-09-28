import SwiftUI

struct TaskListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appModel: AppViewModel
    @State private var editorRoute: TaskEditorRoute?
    @State private var pendingDeletion: TaskItem?
    @State private var searchText = ""
    @State private var selectedModes = Set(FocusMode.allCases)

    // Controls vertical spacing between task sections.
    private let taskSectionSpacing: CGFloat = 16

    var body: some View {
        NavigationStack {
            List {
                ForEach(displayTasks) { task in
                    Section {
                        TaskRow(task: task) {
                            _ = appModel.startTask(task)
                        }
                        .contextMenu {
                            Button(String(localized: "common.edit")) {
                                guardTaskMutation {
                                    editorRoute = .edit(task)
                                }
                            }
                            Button(String(localized: "task.start")) {
                                _ = appModel.startTask(task)
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
                }
                .onDelete(perform: handleDelete)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(colorScheme == .light ? .hidden : .automatic)
            .background {
                if colorScheme == .light {
                    PageBackground(seed: "mint")
                }
            }
            .listSectionSpacing(taskSectionSpacing)
            .navigationTitle(String(localized: "tab.tasks"))
            .searchable(
                text: $searchText,
                placement: .toolbar,
                prompt: String(localized: "task.search")
            )
            .searchToolbarBehavior(.minimize)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        ForEach(FocusMode.allCases) { mode in
                            Toggle(isOn: binding(for: mode)) {
                                Text(modeTitle(mode))
                            }
                        }
                    } label: {
                        Label(String(localized: "task.filter"), systemImage: "line.3.horizontal.decrease.circle")
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

    private var displayTasks: [TaskItem] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return appModel.sortedTasks.filter { task in
            let modeMatched = selectedModes.contains(task.mode)
            guard modeMatched else { return false }
            guard !keyword.isEmpty else { return true }
            return task.title.lowercased().contains(keyword)
        }
    }

    private func handleDelete(_ offsets: IndexSet) {
        guardTaskMutation {
            for index in offsets {
                guard displayTasks.indices.contains(index) else { continue }
                appModel.deleteTask(id: displayTasks[index].id)
            }
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
    let onStart: () -> Void

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
                    Text("\(completedCount)")
                        .font(.caption2.bold())
                        .padding(6)
                        .background(.thinMaterial, in: Circle())
                        .offset(x: 10, y: 10)
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
