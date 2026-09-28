import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var mode: FocusMode
    @State private var presetID: String
    @State private var countdownDuration: TimeInterval
    @State private var backgroundName: String
    @State private var showAdvancedCountdownEditor = false
    @State private var customCountdownMinutesText = ""

    let task: TaskItem?
    let onSave: (TaskItem) -> Void

    private let backgrounds = ["sunset", "forest", "ocean", "lavender", "midnight", "mint"]

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
                Section {
                    TextField(String(localized: "task.name"), text: $title)
                    Picker(String(localized: "task.mode"), selection: $mode) {
                        Text(String(localized: "mode.pomodoro")).tag(FocusMode.pomodoro)
                        Text(String(localized: "mode.stopwatch")).tag(FocusMode.stopwatch)
                        Text(String(localized: "mode.countdown")).tag(FocusMode.countdown)
                    }
                    Picker(String(localized: "task.background"), selection: $backgroundName) {
                        ForEach(backgrounds, id: \.self) { name in
                            Text(backgroundTitle(for: name)).tag(name)
                        }
                    }
                }

                if mode == .pomodoro {
                    Section(String(localized: "task.form.timer")) {
                        Picker(String(localized: "task.preset"), selection: $presetID) {
                            ForEach(PomodoroPreset.all) { preset in
                                Text(String(format: "%@ %d/%d", String(localized: "mode.pomodoro"), Int(preset.workDuration / 60), Int(preset.breakDuration / 60))).tag(preset.id)
                            }
                        }
                    }
                }

                if mode == .countdown {
                    Section(String(localized: "task.form.timer")) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                Slider(value: countdownSliderMinutesBinding, in: 5...300, step: 5)
                                Button {
                                    customCountdownMinutesText = "\(countdownMinutes)"
                                    showAdvancedCountdownEditor = true
                                } label: {
                                    Image(systemName: "square.and.pencil")
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel(String(localized: "common.edit"))
                            }

                            Text(String(format: String(localized: "task.countdown.minutes.preview"), countdownMinutes))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(task == nil ? String(localized: "task.add") : String(localized: "task.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(PageBackground(seed: backgroundName))
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
            .alert(String(localized: "task.countdown.advanced.title"), isPresented: $showAdvancedCountdownEditor) {
                TextField(String(localized: "task.countdown.advanced.placeholder"), text: $customCountdownMinutesText)
                Button(String(localized: "common.cancel"), role: .cancel) {}
                Button(String(localized: "common.done")) {
                    applyCustomCountdownMinutes()
                }
            } message: {
                Text(String(localized: "task.countdown.advanced.message"))
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

    private func backgroundTitle(for name: String) -> String {
        switch name {
        case "forest":
            return String(localized: "background.forest")
        case "ocean":
            return String(localized: "background.ocean")
        case "lavender":
            return String(localized: "background.lavender")
        case "midnight":
            return String(localized: "background.midnight")
        case "mint":
            return String(localized: "background.mint")
        default:
            return String(localized: "background.sunset")
        }
    }

    private var countdownMinutes: Int {
        min(max(Int((countdownDuration / 60).rounded()), 1), 300)
    }

    private var countdownSliderMinutesBinding: Binding<Double> {
        Binding(
            get: {
                let snapped = Int((Double(countdownMinutes) / 5).rounded()) * 5
                return Double(min(max(snapped, 5), 300))
            },
            set: { newValue in
                let stepped = Int(newValue.rounded() / 5) * 5
                countdownDuration = TimeInterval(min(max(stepped, 5), 300) * 60)
            }
        )
    }

    private func applyCustomCountdownMinutes() {
        guard let minutes = Int(customCountdownMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }
        countdownDuration = TimeInterval(min(max(minutes, 1), 300) * 60)
    }
}

#Preview("Add Task") {
    TaskEditorView(task: nil) { _ in }
}

#Preview("Edit Task") {
    TaskEditorView(
        task: TaskItem(
            title: "Deep Work",
            mode: .pomodoro,
            pomodoroPresetID: PomodoroPreset.preset25.id,
            countdownDuration: 25 * 60,
            backgroundName: "sunset",
            order: 0
        )
    ) { _ in }
}
