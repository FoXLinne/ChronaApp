import SwiftUI

struct TaskListView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var editingTask: TaskItem?
    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(appModel.sortedTasks) { task in
                    Button {
                        appModel.startTask(task)
                        if appModel.activeSession != nil {
                            showingEditor = false
                        }
                    } label: {
                        TaskRow(task: task)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(String(localized: "common.edit")) {
                            editingTask = task
                            showingEditor = true
                        }
                        Button(String(localized: "task.start")) {
                            appModel.startTask(task)
                        }
                        Button(String(localized: "common.delete"), role: .destructive) {
                            if let index = appModel.sortedTasks.firstIndex(where: { $0.id == task.id }) {
                                appModel.deleteTasks(at: IndexSet(integer: index))
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(String(localized: "common.edit")) {
                            editingTask = task
                            showingEditor = true
                        }
                        .tint(.blue)
                    }
                }
                .onDelete(perform: appModel.deleteTasks)
                .onMove(perform: appModel.moveTasks)
            }
            .navigationTitle(String(localized: "tab.tasks"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingTask = nil
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                TaskEditorView(task: editingTask) { updatedTask in
                    if appModel.tasks.contains(where: { $0.id == updatedTask.id }) {
                        appModel.updateTask(updatedTask)
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
        }
    }
}

private struct TaskRow: View {
    @EnvironmentObject private var appModel: AppViewModel
    let task: TaskItem

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: previewColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.headline)
                    .foregroundStyle(isCompletedToday && appModel.settings.strikethroughCompletedTask ? .secondary : .primary)
                    .strikethrough(isCompletedToday && appModel.settings.strikethroughCompletedTask)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                if completedCount > 0 {
                    Text("\(completedCount)")
                        .font(.caption2.bold())
                        .padding(6)
                        .background(.thinMaterial, in: Circle())
                        .offset(x: 10, y: 10)
                }
            }
        }
        .padding(.vertical, 6)
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

    private var subtitle: String {
        switch task.mode {
        case .pomodoro:
            let preset = task.pomodoroPreset
            return "Pomodoro \(Int(preset.workDuration / 60))/\(Int(preset.breakDuration / 60))"
        case .stopwatch:
            return String(localized: "mode.stopwatch")
        case .countdown:
            return Duration.seconds(task.countdownDuration).formatted(.time(pattern: .hourMinuteSecond))
        }
    }

    private var previewColors: [Color] {
        switch task.backgroundName {
        case "forest":
            return [Color.green, Color.mint]
        case "ocean":
            return [Color.blue, Color.cyan]
        default:
            return [Color.orange, Color.pink]
        }
    }
}
