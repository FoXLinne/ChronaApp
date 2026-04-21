import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var mode: FocusMode
    @State private var presetID: String
    @State private var countdownDuration: TimeInterval
    @State private var backgroundName: String

    let task: TaskItem?
    let onSave: (TaskItem) -> Void

    private let backgrounds = ["sunset", "forest", "ocean"]

    init(task: TaskItem?, onSave: @escaping (TaskItem) -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task?.title ?? "")
        _mode = State(initialValue: task?.mode ?? .pomodoro)
        _presetID = State(initialValue: task?.pomodoroPresetID ?? PomodoroPreset.default.id)
        _countdownDuration = State(initialValue: task?.countdownDuration ?? 5 * 60)
        _backgroundName = State(initialValue: task?.backgroundName ?? "sunset")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "task.form.basic")) {
                    TextField(String(localized: "task.name"), text: $title)
                    Picker(String(localized: "task.mode"), selection: $mode) {
                        Text(String(localized: "mode.pomodoro")).tag(FocusMode.pomodoro)
                        Text(String(localized: "mode.stopwatch")).tag(FocusMode.stopwatch)
                        Text(String(localized: "mode.countdown")).tag(FocusMode.countdown)
                    }
                    Picker(String(localized: "task.background"), selection: $backgroundName) {
                        ForEach(backgrounds, id: \.self) { name in
                            Text(String(localized: "background.\(name)")).tag(name)
                        }
                    }
                }

                if mode == .pomodoro {
                    Section(String(localized: "task.form.timer")) {
                        Picker(String(localized: "task.preset"), selection: $presetID) {
                            ForEach(PomodoroPreset.all) { preset in
                                Text("\(Int(preset.workDuration / 60))/\(Int(preset.breakDuration / 60))").tag(preset.id)
                            }
                        }
                    }
                }

                if mode == .countdown {
                    Section(String(localized: "task.form.timer")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Slider(value: $countdownDuration, in: 5...18_000, step: 5)
                            Text(Duration.seconds(countdownDuration), format: .time(pattern: .hourMinuteSecond))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(task == nil ? String(localized: "task.add") : String(localized: "task.edit"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        var output = task ?? TaskItem(title: title, mode: mode, order: 0)
        output.title = title
        output.mode = mode
        output.pomodoroPresetID = presetID
        output.countdownDuration = countdownDuration
        output.backgroundName = backgroundName
        onSave(output)
        dismiss()
    }
}
